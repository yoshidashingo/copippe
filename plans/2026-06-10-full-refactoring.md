# copippe 完全リファクタリング実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** コードベースに蓄積した無駄(デッドコード・重複・未完成機能・テストの本番データ破壊・リポジトリ衛生問題)を、外部から見た動作を保ったまま段階的に解消する。

**Architecture:** メニューバー常駐の SwiftUI アプリ。`AppDelegate` が各マネージャ(`HistoryManager` / `SnippetManager` / `HotkeyManager` / `ClipboardMonitor`)を配線する構成は維持し、永続化・クリップボード書き込み・設定読み書きを共通ユーティリティに集約する。並行性は「全マネージャ `@MainActor`」に統一する。

**Tech Stack:** Swift 6(言語モード 6.0)/ macOS 14+ / SwiftUI + AppKit / Swift Testing(`import Testing`)/ Xcode(project.pbxproj は objectVersion 56 = 手動ファイル管理)

---

## 0. 現状分析(全問題リストと根拠)

2026-06-10 時点の全ソース(本体 11 ファイル約 1,400 行、テスト 5 ファイル約 600 行)を読了して特定した問題。**ID はプラン全体で参照する。**

### バグ(B)

| ID | 問題 | 根拠 |
|----|------|------|
| B1 | 起動毎に `SMAppService.mainApp.register()` を無条件実行。設定画面で「Launch at login」をオフにしても次回起動で再登録される | `CopippeApp.swift:61-65`(無条件 register)と `PreferencesWindow.swift:57-71`(unregister UI) |
| B2 | `SnippetManager.updateSnippet(id:title:content:hotkey:)` は `hotkey` 省略時に既存値を nil で上書き。スニペット編集を保存するとホットキーが消える | `SnippetManager.swift:70-85`、呼び出し `PreferencesWindow.swift:254`(hotkey 引数なし) |
| B3 | `HistoryManagerTests.makeManager()` が本番イニシャライザ + `clearAll()` を使い、**テスト実行が実ユーザーの `~/Library/Application Support/copippe/history.json` を破壊する**。テスト用 `init(appState:fileURL:)` は存在するが未使用 | `HistoryManagerTests.swift:8-13`、`HistoryManager.swift:24-28` |
| B4 | `AppStateTests` / `HotkeyManagerTests` が `UserDefaults.standard` を直接読み書きし、実アプリ設定を汚染・テスト間干渉 | `AppStateTests.swift:10-11` ほか、`HotkeyManagerTests.swift:11` |
| B5 | `PopupWindowController.show(tab:)` はパネル表示中だと `tab` 引数を無視(履歴表示中に Snippets ホットキーを押してもタブが切り替わらない) | `PopupWindow.swift:17-23` |
| B6 | `MenuView` の `ForEach` が `id: \.offset`。エントリ削除・並べ替え時に SwiftUI の差分計算が崩れる(`HistoryEntry` は `Identifiable`) | `MenuView.swift:32` |

### デッドコード・未完成機能(D)

| ID | 問題 | 根拠 |
|----|------|------|
| D1 | `AppState.defaultPlainTextMode` は UI(設定トグル)・永続化・テストまで揃っているが、**動作にいっさい影響しない**(`ClipboardMonitor` が参照していない) | grep で参照箇所は AppState 定義 / PreferencesWindow の Binding / テストのみ |
| D2 | `KeyRecorderButton` にキーイベント捕捉ロジックが存在せず、`onRecord` は永遠に呼ばれない。**ホットキー変更 UI は飾り**(ボタンを押すと "Press keys..." になるだけ) | `PreferencesWindow.swift:127-145`(`isRecording.toggle()` のみ) |
| D3 | `HotkeyAction.snippet(UUID)` の実行系(発火時にスニペットをコピー)はあるが、ホットキーを割り当てる UI が存在せず到達不能 | `CopippeApp.swift:50-55`、割当 UI なし |
| D4 | `SnippetManager.setSnippetHotkey` / `allSnippetsWithHotkeys` は本体から未使用 | grep で呼び出し元ゼロ |
| D5 | `SnippetManager.moveSnippet` / `reorderSnippet` は本体から未使用(テストのみが使用) | grep で本体呼び出しゼロ |
| D6 | `HistoryManager.removeEntry(at:)` は本体から未使用(履歴の個別削除 UI がない) | grep で本体呼び出しゼロ |
| D7 | `PopupTab: Int, CaseIterable` の rawValue / CaseIterable は未使用 | `Models.swift:96-99` |
| D8 | `HotkeyManager.registerHotkey` と `updateHotkey` が完全に同一実装 | `HotkeyManager.swift:53-56, 63-66` |
| D9 | HotkeyTab の競合検出結果が `_ = conflict` で握りつぶされ、ユーザーに警告が出ない | `PreferencesWindow.swift:99-102` |
| D10 | `ClipboardMonitor.isUpdatingClipboard` は同期コード内で set/reset され、ガードとして機能していない(`lastChangeCount` 更新だけで自己ループは防げている) | `ClipboardMonitor.swift:9, 40, 63-68` |

### 重複・構造(A)

| ID | 問題 | 根拠 |
|----|------|------|
| A1 | Application Support パス解決 + ディレクトリ作成が 3 クラスに重複。しかも `first!`(force unwrap)と `first ?? temporaryDirectory` が混在 | `HistoryManager.swift:11-16`、`SnippetManager.swift:13-22`、`ImageStore.swift:13-21` |
| A2 | JSON encode → atomic write / read → decode の永続化パターンが `HistoryManager` と `SnippetManager` に重複 | 各 `save()` / `load()` |
| A3 | テスト用ストレージ注入の方式が不統一(`_testFileURL` + `resolvedFileURL` の二重構造 vs `storageFileURL`)。`fileURL` computed property がアクセス毎に `createDirectory` する副作用も持つ | `HistoryManager.swift:11-33` vs `SnippetManager.swift:11-27` |
| A4 | `clearContents()` + `setString()` のクリップボード書き込みが 4 箇所に重複 | `CopippeApp.swift:52-54`、`MenuView.swift:59-61`、`PopupWindow.swift:262-267`、`HistoryManager.swift:87-101` |
| A5 | `previewText`(改行除去 + 切り詰め)が 2 箇所に重複(50 字版と 80 字版) | `MenuView.swift:118-124`、`PopupWindow.swift:271-277` |
| A6 | `AppState` の「キー定義 / didSet 書込 / init での存在チェック + デフォルト値書込」ボイラープレートが 3 プロパティ分繰り返し(プロパティ追加毎に 3 箇所修正) | `AppState.swift` 全体 |
| A7 | アクター分離が不統一: `AppDelegate` / `HotkeyManager` / `PopupWindowController` のみ `@MainActor`。UI から直接触られる `@Observable` クラス群(`AppState` / `HistoryManager` / `SnippetManager` / `ClipboardMonitor` / `ImageStore`)が非分離 | 各ファイル冒頭 |
| A8 | `PreferencesWindow.swift`(376 行)に `PreferencesView` / `GeneralTab` / `HotkeyTab` / `KeyRecorderButton` / `SnippetTab` の 5 型が同居。ファイル名と型名も不一致 | `PreferencesWindow.swift` |
| A9 | 履歴 API がインデックスベース(`search → [Int]`、`copyToClipboard(at:)`)。entries 変更とインデックスがずれると誤コピーの温床 | `HistoryManager.swift:87-112` |

### エラーハンドリング(E)

| ID | 問題 | 根拠 |
|----|------|------|
| E1 | 永続化失敗が空 catch で黙殺(ログすらない)。「保存されない」障害が起きても診断不能 | `HistoryManager.swift:118-120`、`SnippetManager.swift:172-174` |

### リポジトリ衛生(R)

| ID | 問題 | 根拠 |
|----|------|------|
| R1 | `xcuserdata`(`UserInterfaceState.xcuserstate` / `xcschememanagement.plist`)が git 追跡されている | `git ls-files` |
| R2 | `.gitignore` が他プロジェクト由来のコピペ(`.gws` / `pptx` / `aidlc-docs` 等の無関係エントリ多数)で、肝心の Xcode エントリ(`xcuserdata/` 等)がない。`.omc/` も未登録 | `.gitignore` |
| R3 | README / README-ja のダウンロードリンクが `releases/latest/download/copippe-v0.2-macOS.zip` 形式で **v0.2 固定**。現行は v0.3 のため latest 配下にこのファイルは存在せずリンク切れ | `README.md:56-57`、`README-ja.md:56-57` |
| R4 | `AGENTS.md` 冒頭が「Codex (Codex.ai/code) がこのリポジトリで作業する際のガイダンス」— 実態(汎用 AI エージェント向け、CLAUDE.md からの symlink)と不一致 | `AGENTS.md:3` |

### テストギャップ(T)

| ID | 問題 | 根拠 |
|----|------|------|
| T1 | コア機能 `ClipboardMonitor`(プレーンテキスト変換・画像抽出)のテストがゼロ | copippeTests/ に該当ファイルなし |
| T2 | `HistoryManager.imageStore` が `let imageStore = ImageStore()` でハードコードされ、テストから隔離できない | `HistoryManager.swift:8` |

---

## 1. 方針と判断ポイント

リファクタリングの大原則: **各フェーズ完了時点で必ずビルド green + 全テスト green + アプリが動作する。** フェーズ間に依存があるため順番に実行する(フェーズ内タスクは原則順序どおり)。

ユーザー(リポジトリオーナー)の判断が必要な点が 3 つある。**いずれも推奨をデフォルトとしてプランに織り込み済み**。実行前に異議があればプランを修正すること。

| # | 判断ポイント | 推奨(本プラン採用) | 代替案 |
|---|--------------|---------------------|--------|
| 1 | `defaultPlainTextMode`(動作しない設定)の扱い | **設定ごと削除**(Task 3.1)。機能仕様が不明なまま配線するのは危険。`isActive` と役割が重複している疑いも強い | ClipboardMonitor に配線して機能させる(その場合は仕様定義から始める別プランにする) |
| 2 | `KeyRecorderButton`(動かないホットキー変更 UI)の扱い | **修復して完成させる**(Task 3.6)。UI として既にユーザーへ露出しており、「押しても何も起きない」は実質バグ。修復は約 40 行 | UI ごと削除しデフォルトホットキー固定にする(変更量は最少だが機能後退) |
| 3 | スニペットホットキーの残骸(D3/D4)の扱い | **モデル(`Snippet.hotkey`)と実行系・表示は保持、未使用の操作 API のみ削除**(Task 3.2)。保存済みデータとの互換を守りつつ YAGNI を適用 | 実行系・モデルごと全削除(保存データの hotkey が読み捨てになる。将来復活させたい場合の工数大) |

その他の方針:

- **テストフレームワーク:** 既存どおり Swift Testing(`@Test` / `#expect`)を使う。
- **コミット規約:** 既存履歴に合わせ Conventional Commits(`fix:` / `refactor:` / `test:` / `chore:` / `docs:`)。1 タスク = 1 コミット。
- **v1 履歴マイグレーション**(`HistoryManager.load()` の `[String]` フォールバック)**は保持する。** リリース済みアプリであり、維持コストが小さい。
- **`docs/` ディレクトリは GitHub Pages 公開対象(`docs/CNAME` ファイルが存在することを確認済み)のためコードプラン類は置かない。** 本プランは `plans/` 配下に置く。
- **テストが作る OS リソースは残さない。** 隔離用の `UserDefaults(suiteName:)` と `NSPasteboard(name:)` は、後始末まで含めたヘルパー(`TestDefaults` / `TestPasteboard`、Task 0.3 / 4.2 で導入)経由でのみ使う。
- **project.pbxproj(objectVersion 56)への新規ファイル追加・削除は、必ず付録 A の手順に従う。** 特に**アプリターゲットとテストターゲットを取り違えない**こと。

### フェーズ概要

| フェーズ | 内容 | 解消する問題 | リスク |
|---------|------|--------------|--------|
| Phase 0 | 安全網の確立(テスト隔離・ベースライン) | B3, B4, T2 | 低 |
| Phase 1 | リポジトリ衛生 | R1, R2, R3, R4 | 低 |
| Phase 2 | バグ修正 | B1, B2, B5, B6 | 中 |
| Phase 3 | デッドコード削除・未完成機能の修復 | D1〜D10, D9 経由の UX 改善 | 中 |
| Phase 4 | 重複排除・共通化 | A1〜A6, A9 | 中 |
| Phase 5 | 並行性モデル統一(@MainActor) | A7 | 中〜高 |
| Phase 6 | ファイル構造整理 | A8 | 中(pbxproj 手編集) |
| Phase 7 | エラーハンドリング(ログ導入) | E1 | 低 |
| Phase 8 | 最終検証・締め | T1 + 全体検証 | — |

---

## Phase 0: 安全網の確立(テスト隔離・ベースライン)

**目的:** 以降の全フェーズで「テストを安心して回せる」状態を作る。**現状はテストを実行するだけで本番データが消える(B3)ため、これを最優先で止める。**

### Task 0.1: ベースライン確認

**Files:** 変更なし

- [ ] **Step 1: スキーム名の確認**

Run: `xcodebuild -list -project copippe.xcodeproj`
Expected: Schemes に `copippe` が表示される(以降のコマンドはこのスキーム名を使う。異なる場合は読み替え)

- [ ] **Step 2: ビルドが通ることを確認**

Run: `xcodebuild -project copippe.xcodeproj -scheme copippe -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 現状のテストが通ることを確認(注意: この実行は本番 history.json を消す。実行前にバックアップを取る)**

Run: `cp -r ~/Library/Application\ Support/copippe ~/copippe-backup-$(date +%Y%m%d) 2>/dev/null; xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`(全テスト pass。これが以降のベースライン)

### Task 0.2: HistoryManager のストレージ注入を整理し、テストを隔離する

**Files:**
- Modify: `copippe/HistoryManager.swift`(init 統合・imageStore 注入)
- Modify: `copippeTests/HistoryManagerTests.swift`(隔離ストレージ使用)

- [ ] **Step 1: HistoryManager の二重 init と `_testFileURL` の歪みを解消する**

`copippe/HistoryManager.swift` の冒頭部(`entries` 宣言から `resolvedFileURL` まで)を以下に置き換える。`SnippetManager` と同じ「stored `storageFileURL` + computed `fileURL`」パターンに統一し(A3 の半分を解消)、`imageStore` を注入可能にする(T2 解消):

```swift
@Observable
final class HistoryManager {
    private(set) var entries: [HistoryEntry] = []
    let imageStore: ImageStore
    private let appState: AppState
    private let storageFileURL: URL?

    private var fileURL: URL {
        if let storageFileURL {
            return storageFileURL
        }
        let container = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let appDir = container.appendingPathComponent("copippe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("history.json")
    }

    init(appState: AppState, fileURL: URL? = nil, imageStore: ImageStore = ImageStore()) {
        self.appState = appState
        self.storageFileURL = fileURL
        self.imageStore = imageStore
        load()
    }
```

あわせて、ファイル内の `resolvedFileURL` への参照(`save()` 内・`load()` 内の計 2 箇所)をすべて `fileURL` に置換する。

- [ ] **Step 2: ビルドして既存呼び出しが壊れていないことを確認**

Run: `xcodebuild -project copippe.xcodeproj -scheme copippe build`
Expected: `** BUILD SUCCEEDED **`(`AppDelegate` の `HistoryManager(appState: appState)` はデフォルト引数で互換)

- [ ] **Step 3: HistoryManagerTests を隔離ストレージに移行する**

`copippeTests/HistoryManagerTests.swift` の `makeManager()` を以下に置き換える(`clearAll()` による本番データ破壊を廃止):

```swift
    private func makeManager(maxHistoryCount: Int = 30) -> HistoryManager {
        let appState = AppState()
        appState.maxHistoryCount = maxHistoryCount
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return HistoryManager(
            appState: appState,
            fileURL: tempDir.appendingPathComponent("history.json"),
            imageStore: ImageStore(directory: tempDir.appendingPathComponent("images", isDirectory: true))
        )
    }
```

あわせて `maxEntries` テスト(`HistoryManagerTests.swift:50-66`)を、`makeManager(maxHistoryCount: 20)` を使う形に書き換え、`manager.clearAll()` と末尾の「Cleanup」行を削除する:

```swift
    @Test("Max entries enforced at configured limit")
    func maxEntries() {
        let manager = makeManager(maxHistoryCount: 20)

        for i in 0..<25 {
            manager.addEntry(.text(value: "entry \(i)"))
        }

        #expect(manager.entries.count == 20)
        #expect(manager.entries[0] == .text(value: "entry 24"))
    }
```

注意: この時点では `AppState()` がまだ `UserDefaults.standard` を読むため、`maxHistoryCount` を明示設定して環境非依存にしている。完全隔離は Task 0.3 で行う。

- [ ] **Step 4: テスト実行**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add copippe/HistoryManager.swift copippeTests/HistoryManagerTests.swift
git commit -m "test: isolate HistoryManager tests from production storage"
```

### Task 0.3: AppState に UserDefaults を注入し、テストを隔離する

**Files:**
- Modify: `copippe/AppState.swift`
- Create: `copippeTests/TestSupport.swift`(後始末付きの隔離 UserDefaults ヘルパー)
- Modify: `copippe.xcodeproj/project.pbxproj`(TestSupport.swift を**テストターゲット**に登録 — 付録 A 参照)
- Modify: `copippeTests/AppStateTests.swift`
- Modify: `copippeTests/HistoryManagerTests.swift`(AppState 生成箇所)

- [ ] **Step 1: AppState に UserDefaults 注入を追加する**

`copippe/AppState.swift` を以下のとおり変更する(didSet と init の `UserDefaults.standard` を注入された `defaults` に差し替え。**ボイラープレート構造自体は Phase 4 で解消するので、ここでは注入のみ**):

```swift
import Foundation
import Observation

@Observable
final class AppState {
    private static let isActiveKey = "copippe_isActive"
    private static let maxHistoryCountKey = "copippe_maxHistoryCount"
    private static let defaultPlainTextModeKey = "copippe_defaultPlainTextMode"

    @ObservationIgnored private let defaults: UserDefaults

    var isActive: Bool {
        didSet {
            defaults.set(isActive, forKey: Self.isActiveKey)
        }
    }

    var maxHistoryCount: Int {
        didSet {
            defaults.set(maxHistoryCount, forKey: Self.maxHistoryCountKey)
        }
    }

    var defaultPlainTextMode: Bool {
        didSet {
            defaults.set(defaultPlainTextMode, forKey: Self.defaultPlainTextModeKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Default to active on first launch
        if defaults.object(forKey: Self.isActiveKey) == nil {
            self.isActive = true
            defaults.set(true, forKey: Self.isActiveKey)
        } else {
            self.isActive = defaults.bool(forKey: Self.isActiveKey)
        }

        // Default max history count: 30
        if defaults.object(forKey: Self.maxHistoryCountKey) == nil {
            self.maxHistoryCount = 30
            defaults.set(30, forKey: Self.maxHistoryCountKey)
        } else {
            self.maxHistoryCount = defaults.integer(forKey: Self.maxHistoryCountKey)
        }

        // Default plain text mode: true
        if defaults.object(forKey: Self.defaultPlainTextModeKey) == nil {
            self.defaultPlainTextMode = true
            defaults.set(true, forKey: Self.defaultPlainTextModeKey)
        } else {
            self.defaultPlainTextMode = defaults.bool(forKey: Self.defaultPlainTextModeKey)
        }
    }

    func toggleActivation() {
        isActive.toggle()
    }
}
```

- [ ] **Step 2: 後始末付きヘルパー `copippeTests/TestSupport.swift` を新規作成する**

`UserDefaults(suiteName:)` は `~/Library/Preferences/<suiteName>.plist` を生成するため、使い捨てるとテスト実行のたびに plist が蓄積する。解放時に永続ドメインごと削除するヘルパーを介して使う:

```swift
import Foundation

/// テスト用に隔離された UserDefaults。
/// インスタンス解放時に永続ドメインを削除し、~/Library/Preferences に plist を残さない。
/// 注意: テスト関数より先に解放されると掃除が走った後に書き込みが復活するため、
/// 必ず @Suite struct のストアドプロパティとして保持すること(makeXxx() 内のローカル変数にしない)。
final class TestDefaults {
    private let suiteName = "copippe-tests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        // removePersistentDomain は内容を消すが、cfprefsd が空の plist ファイルを残すため直接削除する
        let plistURL = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: plistURL)
    }
}
```

実装時の知見(2026-06-11 実測): `removePersistentDomain` 単独ではドメイン内容はクリアされるものの、cfprefsd が空の plist ファイル(42 バイトの `{}`)を `~/Library/Preferences/` に残す。上記のとおりファイル削除まで行うことで残留ゼロになることを確認済み。

- [ ] **Step 3: TestSupport.swift を pbxproj の**テストターゲット**に登録する(付録 A の「追加」手順。グループは `G10003 /* copippeTests */`、Sources はテストターゲット側)**

Run: `xcodebuild build-for-testing -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST BUILD SUCCEEDED **`(両ターゲットがコンパイルできること)

- [ ] **Step 4: AppStateTests を TestDefaults ベースに移行する**

`copippeTests/AppStateTests.swift` 全体を以下に置き換える(`UserDefaults.standard` への直接アクセスを廃止。Swift Testing は `@Test` ごとに `@Suite` struct を新規生成するため、ストアドプロパティの `testDefaults` はテスト間で共有されず、各テスト終了時に deinit で掃除される):

```swift
import Foundation
import Testing
@testable import copippe

@Suite("AppState Tests")
struct AppStateTests {

    private let testDefaults = TestDefaults()

    private func makeState() -> AppState {
        AppState(defaults: testDefaults.defaults)
    }

    @Test("Initial state defaults to active")
    func initialState() {
        let state = makeState()
        #expect(state.isActive == true)
    }

    @Test("Toggle changes state")
    func toggleActivation() {
        let state = makeState()
        let initial = state.isActive

        state.toggleActivation()
        #expect(state.isActive == !initial)

        state.toggleActivation()
        #expect(state.isActive == initial)
    }

    @Test("State persists to UserDefaults")
    func statePersistence() {
        let state = makeState()

        state.isActive = false
        #expect(testDefaults.defaults.bool(forKey: "copippe_isActive") == false)

        state.isActive = true
        #expect(testDefaults.defaults.bool(forKey: "copippe_isActive") == true)
    }

    @Test("Max history count defaults to 30")
    func maxHistoryCountDefault() {
        let state = makeState()
        #expect(state.maxHistoryCount == 30)
    }

    @Test("Max history count persists to UserDefaults")
    func maxHistoryCountPersistence() {
        let state = makeState()

        state.maxHistoryCount = 50
        #expect(testDefaults.defaults.integer(forKey: "copippe_maxHistoryCount") == 50)
    }

    @Test("Default plain text mode defaults to true")
    func defaultPlainTextModeDefault() {
        let state = makeState()
        #expect(state.defaultPlainTextMode == true)
    }

    @Test("Default plain text mode persists to UserDefaults")
    func defaultPlainTextModePersistence() {
        let state = makeState()

        state.defaultPlainTextMode = false
        #expect(testDefaults.defaults.bool(forKey: "copippe_defaultPlainTextMode") == false)
    }
}
```

- [ ] **Step 5: HistoryManagerTests も TestDefaults をストアドプロパティで持つよう変更する**

`HistoryManagerTests` 冒頭にプロパティを追加し、`makeManager()` 内の `AppState()` を差し替える:

```swift
@Suite("HistoryManager Tests")
struct HistoryManagerTests {

    private let testDefaults = TestDefaults()

    private func makeManager(maxHistoryCount: Int = 30) -> HistoryManager {
        let appState = AppState(defaults: testDefaults.defaults)
        appState.maxHistoryCount = maxHistoryCount
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return HistoryManager(
            appState: appState,
            fileURL: tempDir.appendingPathComponent("history.json"),
            imageStore: ImageStore(directory: tempDir.appendingPathComponent("images", isDirectory: true))
        )
    }
```

- [ ] **Step 6: テスト実行**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

確認: `ls ~/Library/Preferences/ | grep copippe-tests | wc -l` が 0 のままであること(plist 残留なし)

- [ ] **Step 7: コミット**

```bash
git add copippe/AppState.swift copippeTests/TestSupport.swift copippeTests/AppStateTests.swift copippeTests/HistoryManagerTests.swift copippe.xcodeproj/project.pbxproj
git commit -m "test: inject UserDefaults into AppState and isolate tests with cleanup"
```

### Task 0.4: HotkeyManager に UserDefaults を注入し、テストを隔離する

**Files:**
- Modify: `copippe/HotkeyManager.swift`
- Modify: `copippeTests/HotkeyManagerTests.swift`

- [ ] **Step 1: HotkeyManager に UserDefaults 注入を追加する**

`copippe/HotkeyManager.swift` の init を以下に変更する:

```swift
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadHotkeys()
    }
```

`saveHotkeys()` / `loadHotkeys()` 内の `UserDefaults.standard` を `defaults` に置換する(各 1 箇所)。

- [ ] **Step 2: HotkeyManagerTests を TestDefaults に移行する**

`copippeTests/HotkeyManagerTests.swift` の冒頭プロパティと `makeManager()` を以下に置き換える(`UserDefaults.standard.removeObject` による事前掃除も不要になる):

```swift
@Suite("HotkeyManager Tests")
@MainActor
struct HotkeyManagerTests {

    private let testDefaults = TestDefaults()

    private func makeManager() -> HotkeyManager {
        HotkeyManager(defaults: testDefaults.defaults)
    }
```

- [ ] **Step 3: テスト実行**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: コミット**

```bash
git add copippe/HotkeyManager.swift copippeTests/HotkeyManagerTests.swift
git commit -m "test: inject UserDefaults into HotkeyManager and isolate tests"
```

---

## Phase 1: リポジトリ衛生

**目的:** コードに触らない独立した掃除を先に終わらせる(R1〜R4)。

### Task 1.1: .gitignore を本プロジェクト用に書き直す

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: `.gitignore` 全体を以下に置き換える**

このリポジトリに実在しない他プロジェクト由来エントリ(`output/`、`logs/`、`.gws/`、`~$*.pptx`、`.steering/`、`aidlc-docs/` 等)を削除し、Xcode プロジェクトに必要なエントリを追加する:

```gitignore
# macOS
.DS_Store

# Xcode
build/
DerivedData/
xcuserdata/
*.xcuserstate
*.xcscmblueprint
*.moved-aside

# Swift Package Manager
.build/
.swiftpm/

# Editor
*.swp
*.swo
*~
.vscode/
.idea/

# AI tooling
.claude/
.omc/
```

注意: 削除するエントリが本当に不要か、コミット前に `git status` で新たな untracked ファイルが現れないことを確認する。

- [ ] **Step 2: 追跡済み xcuserdata を index から外す(ワーキングコピーには残す)**

```bash
git rm -r --cached copippe.xcodeproj/xcuserdata copippe.xcodeproj/project.xcworkspace/xcuserdata
```

Expected: 2 ファイルが `rm 'copippe.xcodeproj/...'` と表示される

- [ ] **Step 3: 状態確認**

Run: `git status --short`
Expected: `.gitignore` の変更と xcuserdata 2 ファイルの削除のみがステージされ、新規 untracked が増えていない(`.omc/` が表示されなくなる)

- [ ] **Step 4: コミット**

```bash
git add .gitignore
git commit -m "chore: rewrite .gitignore for Xcode project and untrack xcuserdata"
```

### Task 1.2: README のリリースリンクをバージョン非依存にする

**Files:**
- Modify: `README.md:56-57`(55 行は Releases ページ見出しで変更不要)
- Modify: `README-ja.md:56-57`

- [ ] **Step 1: README.md のバージョン固定リンクを置き換える**

`README.md` の Releases 案内部分(56-57 行のバージョン固定直リンク)を以下に置き換える(`copippe-v0.2-macOS.zip` への直リンクは v0.3 リリース後はリンク切れのため、リリースページへの誘導に変更し、今後のリリースで README 更新を不要にする):

```markdown
1. Download the latest version from the **[Releases page](https://github.com/yoshidashingo/copippe/releases/latest)**:
   - `copippe-vX.Y-macOS.zip` — Zip archive
   - `copippe-vX.Y-macOS.dmg` — Disk image
```

- [ ] **Step 2: README-ja.md も同様に置き換える**

```markdown
1. **[リリースページ](https://github.com/yoshidashingo/copippe/releases/latest)** から最新版をダウンロード:
   - `copippe-vX.Y-macOS.zip` — Zipアーカイブ
   - `copippe-vX.Y-macOS.dmg` — ディスクイメージ
```

注意: 置き換え前に実際の行内容を確認し、前後の手順番号や文体と整合させること。

- [ ] **Step 3: コミット**

```bash
git add README.md README-ja.md
git commit -m "docs: make release download links version-agnostic"
```

### Task 1.3: AGENTS.md の対象記述を実態に合わせる

**Files:**
- Modify: `AGENTS.md:3`

- [ ] **Step 1: 冒頭の説明文を修正する**

変更前:
```markdown
このファイルは、Codex (Codex.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。
```

変更後:
```markdown
このファイルは、AI コーディングエージェント(Claude Code、Codex など)がこのリポジトリで作業する際のガイダンスを提供します。
```

- [ ] **Step 2: コミット**

```bash
git add AGENTS.md
git commit -m "docs: clarify AGENTS.md applies to all coding agents"
```

---

## Phase 2: バグ修正

**目的:** 動作が間違っている箇所を、構造変更前に小さく直す(B1, B2, B5, B6)。動作変更を伴うため、リファクタリング(Phase 4 以降)とコミットを分離する。

### Task 2.1: Launch at login の自動再登録をやめる(B1)

**Files:**
- Modify: `copippe/CopippeApp.swift:60-65`

- [ ] **Step 1: 初回起動時のみ register するよう変更する**

`AppDelegate.applicationDidFinishLaunching` 内の login item 登録部を以下に置き換える:

```swift
        // Register login item only on first launch.
        // Re-registering on every launch would override the user's choice
        // to disable "Launch at login" in Preferences (General tab).
        let didRegisterKey = "copippe_didRegisterLoginItem"
        if !UserDefaults.standard.bool(forKey: didRegisterKey) {
            do {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: didRegisterKey)
            } catch {
                // Not critical; retry on next launch
            }
        }
```

- [ ] **Step 2: ビルド確認**

Run: `xcodebuild -project copippe.xcodeproj -scheme copippe build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 手動検証(SMAppService はユニットテスト不能のため)**

1. アプリを起動 → Preferences > General で「Launch at login」をオフ
2. アプリを終了して再起動
3. Preferences > General を開き、「Launch at login」が**オフのまま**であることを確認

既知の移行時挙動(許容する): 既存ユーザーは `copippe_didRegisterLoginItem` キーが未設定のため、**この修正を含むバージョンへの更新後、初回起動で一度だけ register が走る**(過去にオフへ変更していた場合は再びオンになる)。「ユーザーが過去にオフを選んだ」事実を記録した情報が存在しないため完全には防げない。`SMAppService.mainApp.status` でも「未登録」と「ユーザーがオフにした」は区別できない。一度きりで以後は設定が尊重されるため許容し、これ以上の対策はしない。

- [ ] **Step 4: コミット**

```bash
git add copippe/CopippeApp.swift
git commit -m "fix: stop re-registering login item on every launch"
```

### Task 2.2: スニペット編集でホットキーが消えるのを直す(B2)

**Files:**
- Modify: `copippe/SnippetManager.swift:70-85`
- Test: `copippeTests/SnippetManagerTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`copippeTests/SnippetManagerTests.swift` に追加:

```swift
    @Test("Update snippet preserves existing hotkey")
    func updateSnippetPreservesHotkey() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        let snippet = manager.addSnippet(folderID: folder.id, title: "Title", content: "Content")!
        let binding = HotkeyBinding(keyCode: 9, modifiers: 0)
        manager.setSnippetHotkey(id: snippet.id, hotkey: binding)

        manager.updateSnippet(id: snippet.id, title: "New Title", content: "New Content")

        #expect(manager.folders[0].snippets[0].hotkey == binding)
    }
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `updateSnippetPreservesHotkey` が FAIL(hotkey が nil になるため)

- [ ] **Step 3: `updateSnippet` から hotkey パラメータを除去する**

`copippe/SnippetManager.swift` の `updateSnippet` を以下に置き換える(ホットキー変更は `setSnippetHotkey` に一本化):

```swift
    func updateSnippet(id: UUID, title: String? = nil, content: String? = nil) {
        for folderIndex in folders.indices {
            if let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == id }) {
                if let title = title {
                    folders[folderIndex].snippets[snippetIndex].title = title
                }
                if let content = content {
                    folders[folderIndex].snippets[snippetIndex].content = content
                }
                save()
                return
            }
        }
    }
```

呼び出し元は `PreferencesWindow.swift:254`(hotkey 引数なし)と既存テストのみなので、シグネチャ変更による修正は不要。

- [ ] **Step 4: テストが通ることを確認**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add copippe/SnippetManager.swift copippeTests/SnippetManagerTests.swift
git commit -m "fix: preserve snippet hotkey when editing title/content"
```

### Task 2.3: ポップアップ表示中のタブ切り替えを機能させる(B5)

**Files:**
- Modify: `copippe/PopupWindow.swift`

正直な位置づけ: 現状で実際に配線されているグローバルホットキーは `showHistory` のみ(`showSnippets` には既定バインドも設定 UI もない — スコープ外 #2)。そのため**この修正で今すぐ観測できる UX 変化はほぼない**。これは「表示中の `show(tab:)` がタブ引数を黙って無視する」という API レベルの欠陥の修正であり、将来 showSnippets ホットキーやスニペットホットキーを配線した瞬間に正しく動くための土台整備である。`toggle` の新セマンティクス(同じタブなら閉じる/違うタブなら切り替え)は、唯一の配線済み経路(History ホットキー連打)では従来どおり「開く→閉じる」のままで回帰しない。

- [ ] **Step 1: タブ状態を Controller が所有する `PopupState` を導入する**

`copippe/PopupWindow.swift` の `PopupWindowController` を以下に置き換える(`PopupContentView` の `@State selectedTab` を、Controller と共有する `@Observable` モデルに変更):

```swift
// MARK: - PopupState

@MainActor
@Observable
final class PopupState {
    var selectedTab: PopupTab = .history
}

// MARK: - PopupWindowController

@MainActor
final class PopupWindowController {
    private var panel: NSPanel?
    private let historyManager: HistoryManager
    private let snippetManager: SnippetManager
    private let popupState = PopupState()

    init(historyManager: HistoryManager, snippetManager: SnippetManager) {
        self.historyManager = historyManager
        self.snippetManager = snippetManager
    }

    func show(tab: PopupTab) {
        popupState.selectedTab = tab

        if let panel = panel {
            panel.orderFront(nil)
            panel.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PopupContentView(
            historyManager: historyManager,
            snippetManager: snippetManager,
            popupState: popupState,
            onDismiss: { [weak self] in self?.hide() }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func toggle(tab: PopupTab) {
        if panel != nil, popupState.selectedTab == tab {
            // Same tab requested while visible: dismiss
            hide()
        } else {
            show(tab: tab)
        }
    }
}
```

- [ ] **Step 2: `PopupContentView` を `popupState` ベースに変更する**

`PopupContentView` の宣言を以下に変更する(独自 `init` は削除し、memberwise 生成に任せる):

```swift
struct PopupContentView: View {
    let historyManager: HistoryManager
    let snippetManager: SnippetManager
    @Bindable var popupState: PopupState
    @State private var searchText = ""
    let onDismiss: () -> Void
```

body 内の Picker とコンテンツ分岐を次のように変更:

```swift
            Picker("", selection: $popupState.selectedTab) {
                Text("History").tag(PopupTab.history)
                Text("Snippets").tag(PopupTab.snippets)
            }
```

```swift
            switch popupState.selectedTab {
            case .history:
                historyListView
            case .snippets:
                snippetListView
            }
```

- [ ] **Step 3: ビルド確認**

Run: `xcodebuild -project copippe.xcodeproj -scheme copippe build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 手動検証(回帰確認が主目的)**

1. 履歴ホットキー(⌃⌥V)でポップアップ表示 → History タブが選択されている
2. もう一度同じホットキー → ポップアップが閉じる(従来挙動の回帰確認)
3. ポップアップ内の Segmented Control で Snippets ⇄ History を切り替えられる(`@Bindable` 配線の確認)
4. タブ指定 `show(tab:)` の切り替え動作そのものは、配線済みホットキーが showHistory のみのため手動では再現不能。コードレビューで `show(tab:)` 冒頭の `popupState.selectedTab = tab` を確認することで担保し、実地検証はスコープ外 #1/#2 の機能配線時に行う

- [ ] **Step 5: コミット**

```bash
git add copippe/PopupWindow.swift
git commit -m "fix: switch popup tab when shown while already visible"
```

### Task 2.4: MenuView の ForEach id を安定させる(B6)

**Files:**
- Modify: `copippe/MenuView.swift:32`

- [ ] **Step 1: `id: \.offset` を要素 ID に変更する**

変更前:
```swift
                ForEach(Array(historyManager.entries.enumerated()), id: \.offset) { index, entry in
```

変更後:
```swift
                ForEach(Array(historyManager.entries.enumerated()), id: \.element.id) { index, entry in
```

(インデックス API 自体の置き換えは Phase 4 / Task 4.5 で行う。)

- [ ] **Step 2: ビルド・手動確認(メニューを開いて履歴が表示される)後コミット**

```bash
git add copippe/MenuView.swift
git commit -m "fix: use stable entry id in MenuView ForEach"
```

---

## Phase 3: デッドコード削除・未完成機能の修復

**目的:** 「存在するが機能しない/呼ばれない」コードをなくす(D1〜D10)。判断ポイント 1〜3 の推奨に従う。

### Task 3.1: defaultPlainTextMode を削除する(D1)

**Files:**
- Modify: `copippe/AppState.swift`(プロパティ・キー・init 部・didSet 削除)
- Modify: `copippe/PreferencesWindow.swift:48-54`(トグル削除)
- Modify: `copippeTests/AppStateTests.swift`(関連テスト 2 件削除)

- [ ] **Step 1: AppState から `defaultPlainTextMode` 関連をすべて削除する**

削除対象: `defaultPlainTextModeKey` 定義、`defaultPlainTextMode` プロパティ(didSet 含む)、init 内の該当ブロック。

- [ ] **Step 2: GeneralTab から「Plain text mode by default」トグルを削除する**

`PreferencesWindow.swift` の `Section("Clipboard")` 内 `Toggle("Plain text mode by default", ...)` ブロック(48-54 行付近)を削除する。

- [ ] **Step 3: AppStateTests から `defaultPlainTextModeDefault` / `defaultPlainTextModePersistence` を削除する**

- [ ] **Step 4: 参照が残っていないことを確認する**

Run: `grep -rn "defaultPlainTextMode" copippe/ copippeTests/`
Expected: ヒットなし

- [ ] **Step 5: テスト実行・コミット**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

```bash
git add copippe/AppState.swift copippe/PreferencesWindow.swift copippeTests/AppStateTests.swift
git commit -m "refactor: remove non-functional defaultPlainTextMode setting"
```

注: 既存ユーザーの UserDefaults に `copippe_defaultPlainTextMode` キーが残るが無害(掃除コードは追加しない)。

### Task 3.2: 未使用のマネージャ API を削除する(D4 の一部, D5, D6)

**Files:**
- Modify: `copippe/SnippetManager.swift`(`allSnippetsWithHotkeys` / `moveSnippet` / `reorderSnippet` / `moveFolder` 削除)
- Modify: `copippe/HistoryManager.swift`(`removeEntry(at:)` 削除)
- Modify: `copippeTests/SnippetManagerTests.swift`(`moveSnippet` / `moveFolder` テスト削除)
- Modify: `copippeTests/HistoryManagerTests.swift`(`removeEntry` / `removeInvalidIndex` テスト削除)

**残すもの(意図的):** `setSnippetHotkey` は Task 2.2 のテストで使用し、将来のスニペットホットキー UI(スコープ外 #1)の唯一の設定経路として保持。`Snippet.hotkey` モデル・`HotkeyAction.snippet` 実行系・ホットキー表示 UI も保持(判断ポイント 3)。

- [ ] **Step 1: 本体から各メソッドを削除する**

削除対象メソッド(grep で本体からの呼び出しゼロを確認済み):
- `SnippetManager.allSnippetsWithHotkeys()`(155-160 行)
- `SnippetManager.moveSnippet(id:toFolderID:)`(104-118 行)
- `SnippetManager.reorderSnippet(folderID:from:to:)`(120-129 行)
- `SnippetManager.moveFolder(from:to:)`(50-57 行)
- `HistoryManager.removeEntry(at:)`(67-74 行)

- [ ] **Step 2: 対応するテストを削除する**

- `SnippetManagerTests.moveSnippet`(143-158 行)
- `SnippetManagerTests.moveFolder`(173-186 行)
- `HistoryManagerTests.removeEntry`(79-92 行)
- `HistoryManagerTests.removeInvalidIndex`(105-113 行)

- [ ] **Step 3: ビルド・テスト・コミット**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

```bash
git add copippe/SnippetManager.swift copippe/HistoryManager.swift copippeTests/
git commit -m "refactor: remove unused manager APIs (move/reorder/removeEntry/allSnippetsWithHotkeys)"
```

注: 将来ドラッグ&ドロップ並べ替えや履歴の個別削除を実装する際は、この時点の git 履歴から復元するより、その時の設計で書き直すこと(YAGNI)。

### Task 3.3: HotkeyManager の重複 API を統合する(D8)

**Files:**
- Modify: `copippe/HotkeyManager.swift`(`updateHotkey` 削除)
- Modify: `copippe/PreferencesWindow.swift:103`(呼び出しを `registerHotkey` に変更)
- Modify: `copippeTests/HotkeyManagerTests.swift`(`updateHotkey` テストを `registerHotkey` の上書き挙動テストに変更)

- [ ] **Step 1: `updateHotkey` を削除し、呼び出し元を `registerHotkey` に変更する**

`HotkeyManager.swift` から `updateHotkey(action:binding:)`(63-66 行)を削除。
`PreferencesWindow.swift:103` の `hotkeyManager.updateHotkey(action: .showHistory, binding: binding)` を `hotkeyManager.registerHotkey(action: .showHistory, binding: binding)` に変更。

- [ ] **Step 2: テストを更新する**

`HotkeyManagerTests.updateHotkey` テストを以下に置き換える:

```swift
    @Test("Registering again replaces existing binding")
    func reRegisterReplacesBinding() {
        let manager = makeManager()
        let old = HotkeyBinding(keyCode: 9, modifiers: 0)
        let new = HotkeyBinding(keyCode: 12, modifiers: 0)

        manager.registerHotkey(action: .showHistory, binding: old)
        manager.registerHotkey(action: .showHistory, binding: new)

        let retrieved = manager.binding(for: .showHistory)
        #expect(retrieved?.keyCode == 12)
    }
```

- [ ] **Step 3: テスト実行・コミット**

```bash
git add copippe/HotkeyManager.swift copippe/PreferencesWindow.swift copippeTests/HotkeyManagerTests.swift
git commit -m "refactor: merge updateHotkey into registerHotkey"
```

### Task 3.4: PopupTab の不要な適合を外す(D7)

**Files:**
- Modify: `copippe/Models.swift:96-99`

- [ ] **Step 1: rawValue と CaseIterable を外す**

変更前:
```swift
enum PopupTab: Int, CaseIterable {
    case history
    case snippets
}
```

変更後:
```swift
enum PopupTab {
    case history
    case snippets
}
```

注: `Picker` の `tag()` は `Hashable` のみ要求するため(enum は自動適合)、ビルドは通る。

- [ ] **Step 2: ビルド・コミット**

```bash
git add copippe/Models.swift
git commit -m "refactor: drop unused Int rawValue and CaseIterable from PopupTab"
```

### Task 3.5: ClipboardMonitor の無意味なフラグを削除する(D10)

**Files:**
- Modify: `copippe/ClipboardMonitor.swift`

- [ ] **Step 1: 挙動分析を確認する**

`isUpdatingClipboard` は `handleClipboardChange()` 内で同期的に `true → false` され、`checkClipboard()` は同じメインスレッドの Timer からしか呼ばれないため、`guard !isUpdatingClipboard` が `true` の瞬間に評価されることはない。**自己書き込みの再検知防止は、書き戻し直後の `lastChangeCount = pb.changeCount`(`ClipboardMonitor.swift:67`)が主因として担っている**(この行は削除しないこと。将来 `handleClipboardChange` に非同期処理を足す場合は、この前提が崩れないか再評価する)。

- [ ] **Step 2: フラグを削除する**

削除対象: 9 行 `private var isUpdatingClipboard = false`、40 行 `guard !isUpdatingClipboard else { return }`、63 行 `isUpdatingClipboard = true`、68 行 `isUpdatingClipboard = false`。

- [ ] **Step 3: ビルド・手動確認(コピーして履歴に入る/プレーン化される)・コミット**

```bash
git add copippe/ClipboardMonitor.swift
git commit -m "refactor: remove ineffective isUpdatingClipboard flag"
```

### Task 3.6: KeyRecorderButton を修復し、競合警告を表示する(D2, D9)

**Files:**
- Modify: `copippe/PreferencesWindow.swift`(`KeyRecorderButton` 本体と `HotkeyTab`)

- [ ] **Step 1: KeyRecorderButton にキー捕捉を実装する**

`PreferencesWindow.swift` の `KeyRecorderButton`(127-145 行)を以下に置き換える:

```swift
struct KeyRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt16, UInt) -> Void
    @State private var keyMonitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            Text(isRecording ? "Press keys..." : displayString)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Require at least one modifier so plain typing can't become a hotkey
            guard !modifiers.isEmpty else { return event }
            onRecord(event.keyCode, modifiers.rawValue)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
```

- [ ] **Step 2: HotkeyTab で競合をアラート表示する**

`HotkeyTab` を以下に置き換える(`_ = conflict` の握りつぶしを廃止):

```swift
struct HotkeyTab: View {
    let hotkeyManager: HotkeyManager
    @State private var isRecordingHistory = false
    @State private var conflictMessage: String?

    var body: some View {
        Form {
            Section("Global Hotkeys") {
                HStack {
                    Text("Show History Popup")
                    Spacer()
                    KeyRecorderButton(
                        displayString: hotkeyDisplay(for: .showHistory),
                        isRecording: $isRecordingHistory,
                        onRecord: { keyCode, modifiers in
                            let binding = HotkeyBinding(keyCode: keyCode, modifiers: modifiers)
                            if let conflict = hotkeyManager.checkConflict(binding: binding, excluding: .showHistory) {
                                conflictMessage = "\(binding.displayString) is already assigned to \(label(for: conflict))."
                            } else {
                                hotkeyManager.registerHotkey(action: .showHistory, binding: binding)
                            }
                        }
                    )
                }
            }

            Section {
                Text("Press the recorder button, then press your desired key combination.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert(
            "Hotkey Conflict",
            isPresented: Binding(
                get: { conflictMessage != nil },
                set: { if !$0 { conflictMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(conflictMessage ?? "")
        }
    }

    private func hotkeyDisplay(for action: HotkeyAction) -> String {
        hotkeyManager.binding(for: action)?.displayString ?? "Not set"
    }

    private func label(for action: HotkeyAction) -> String {
        switch action {
        case .showHistory: return "Show History Popup"
        case .showSnippets: return "Show Snippets Popup"
        case .snippet: return "a snippet"
        }
    }
}
```

- [ ] **Step 3: ビルド・手動検証**

1. Preferences > Hotkeys でレコーダーをクリック → "Press keys..." 表示
2. ⌘⇧H など修飾キー付きの組み合わせを押す → **表示が新しいホットキーに変わる**(従来は何も起きなかった)
3. Escape で記録キャンセルできる
4. ポップアップが新ホットキーで開く(旧ホットキーでは開かない)

- [ ] **Step 4: コミット**

```bash
git add copippe/PreferencesWindow.swift
git commit -m "fix: implement key capture in KeyRecorderButton and surface hotkey conflicts"
```

---

## Phase 4: 重複排除・共通化

**目的:** コピペされた永続化・クリップボード・プレビュー・設定コードを 1 箇所に集める(A1〜A6, A9)。**このフェーズは動作を変えない。**

### Task 4.1: 永続化を `JSONFileStore` に集約する(A1, A2, A3)

**Files:**
- Create: `copippe/Persistence.swift`
- Create: `copippeTests/PersistenceTests.swift`
- Modify: `copippe/HistoryManager.swift`、`copippe/SnippetManager.swift`、`copippe/ImageStore.swift`
- Modify: `copippe.xcodeproj/project.pbxproj`

注意(pbxproj): 新規ファイルの登録は付録 A の手順に従う。**`Persistence.swift` はアプリターゲット、`PersistenceTests.swift` はテストターゲット**に登録する(取り違えると `@testable import` がアプリ本体にリンクされてビルドエラー、またはテストが実行されない)。

- [ ] **Step 1: 失敗するテストを書く(`copippeTests/PersistenceTests.swift` を新規作成)**

```swift
import Foundation
import Testing
@testable import copippe

@Suite("JSONFileStore Tests")
struct PersistenceTests {

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    @Test("Save and load round-trips a Codable value")
    func saveAndLoad() {
        let store = JSONFileStore<[String]>(fileURL: temporaryFileURL())

        store.save(["a", "b"])

        #expect(store.load() == ["a", "b"])
    }

    @Test("Load returns nil when file does not exist")
    func loadMissingFile() {
        let store = JSONFileStore<[String]>(fileURL: temporaryFileURL())
        #expect(store.load() == nil)
    }

    @Test("Save creates intermediate directories")
    func saveCreatesDirectories() {
        let url = temporaryFileURL() // 親ディレクトリは未作成
        let store = JSONFileStore<Int>(fileURL: url)

        store.save(42)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("loadData returns raw bytes for migration fallbacks")
    func loadDataRaw() throws {
        let url = temporaryFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[\"legacy\"]".utf8).write(to: url)

        let store = JSONFileStore<[String]>(fileURL: url)

        #expect(store.loadData() != nil)
    }

    @Test("appSupportDirectory points into copippe folder")
    func appSupportDirectory() {
        let dir = AppDirectories.appSupport()
        #expect(dir.lastPathComponent == "copippe")
    }
}
```

- [ ] **Step 2: テストをビルドして失敗(コンパイルエラー)を確認**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: FAIL(`JSONFileStore` / `AppDirectories` 未定義)

- [ ] **Step 3: `copippe/Persistence.swift` を実装する**

```swift
import Foundation

/// Application Support 配下の copippe ディレクトリ解決(全ストレージで共通)
enum AppDirectories {
    static func appSupport() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("copippe", isDirectory: true)
    }
}

/// JSON ファイルへの Codable 値の保存・読込(atomic write、親ディレクトリ自動作成)
struct JSONFileStore<Value: Codable> {
    let fileURL: URL

    func load() -> Value? {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// マイグレーション用に生データも読めるようにする(HistoryManager の v1 フォールバックで使用)
    func loadData() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort persistence(Phase 7 でログを追加する)
        }
    }
}
```

- [ ] **Step 4: pbxproj に 2 ファイルを登録し(付録 A: `Persistence.swift` → アプリターゲット、`PersistenceTests.swift` → テストターゲット)、テストが通ることを確認**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: HistoryManager を JSONFileStore 利用に書き換える**

`copippe/HistoryManager.swift` のストレージ部分を以下に置き換える(v1 マイグレーションは保持):

```swift
@Observable
final class HistoryManager {
    private(set) var entries: [HistoryEntry] = []
    let imageStore: ImageStore
    private let appState: AppState
    private let store: JSONFileStore<[HistoryEntry]>

    init(appState: AppState, fileURL: URL? = nil, imageStore: ImageStore = ImageStore()) {
        self.appState = appState
        self.imageStore = imageStore
        self.store = JSONFileStore(
            fileURL: fileURL ?? AppDirectories.appSupport().appendingPathComponent("history.json")
        )
        load()
    }
```

`save()` / `load()` を以下に置き換える:

```swift
    func save() {
        store.save(entries)
    }

    func load() {
        // Try v2 format first
        if let decoded = store.load() {
            entries = decoded
            return
        }

        // Fallback: migrate from v1 format ([String])
        if let data = store.loadData(),
           let legacyEntries = try? JSONDecoder().decode([String].self, from: data) {
            entries = legacyEntries.compactMap { text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : .text(value: trimmed)
            }
            save() // Re-save in v2 format
            return
        }

        entries = []
    }
```

(旧 `fileURL` computed property と `storageFileURL` は削除。)

- [ ] **Step 6: SnippetManager を JSONFileStore 利用に書き換える**

同様に `copippe/SnippetManager.swift` のストレージ部分を置き換える:

```swift
@Observable
final class SnippetManager {
    static let defaultFolderName = "New Folder"
    private static let legacyDefaultFolderName = "New Name"

    private(set) var folders: [SnippetFolder] = []
    private let store: JSONFileStore<[SnippetFolder]>

    init(fileURL: URL? = nil) {
        self.store = JSONFileStore(
            fileURL: fileURL ?? AppDirectories.appSupport().appendingPathComponent("snippets.json")
        )
        load()
    }
```

```swift
    func save() {
        store.save(folders)
    }

    func load() {
        folders = store.load() ?? []
        migrateLegacyDefaultFolderNames()
    }
```

(旧 `storageFileURL` / `fileURL` は削除。)

- [ ] **Step 7: ImageStore のディレクトリ解決を AppDirectories に揃える**

`copippe/ImageStore.swift` の init を以下に置き換える(`first!` の force unwrap を排除):

```swift
    init(directory: URL? = nil) {
        imagesDirectory = directory
            ?? AppDirectories.appSupport().appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }
```

注: 既定パスは従来と同じ `~/Library/Application Support/copippe/images` のまま(挙動不変)。

- [ ] **Step 8: 全テスト・手動確認(既存の履歴・スニペットが読める)・コミット**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

手動: アプリ起動 → 既存の履歴とスニペットがそのまま表示される(パス互換の確認)。

```bash
git add copippe/Persistence.swift copippeTests/PersistenceTests.swift copippe/HistoryManager.swift copippe/SnippetManager.swift copippe/ImageStore.swift copippe.xcodeproj/project.pbxproj
git commit -m "refactor: consolidate JSON persistence into JSONFileStore"
```

### Task 4.2: クリップボード書き込みを `Pasteboard` に集約する(A4)

**Files:**
- Create: `copippe/Pasteboard.swift`
- Create: `copippeTests/PasteboardTests.swift`
- Modify: `copippe/CopippeApp.swift`、`copippe/MenuView.swift`、`copippe/PopupWindow.swift`、`copippe/HistoryManager.swift`、`copippe/ClipboardMonitor.swift`
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: `copippeTests/TestSupport.swift` に後始末付きの隔離ペーストボードヘルパーを追記する**

`NSPasteboard(name:)` もシステムに named pasteboard を作るため、解放時に `releaseGlobally()` で除去する:

```swift
import AppKit

/// テスト用に隔離された NSPasteboard。解放時に releaseGlobally でシステムから除去する。
final class TestPasteboard {
    let pasteboard: NSPasteboard

    init() {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("copippe-tests-\(UUID().uuidString)"))
    }

    deinit {
        pasteboard.releaseGlobally()
    }
}
```

(TestSupport.swift 冒頭の import 群に `import AppKit` を追加する。既存の `import Foundation` は残す。)

- [ ] **Step 2: 失敗するテストを書く(`copippeTests/PasteboardTests.swift`)**

```swift
import AppKit
import Testing
@testable import copippe

@Suite("Pasteboard Tests")
struct PasteboardTests {

    private let testPasteboard = TestPasteboard()

    @Test("Copy string replaces pasteboard contents")
    func copyString() {
        Pasteboard.copy("hello", to: testPasteboard.pasteboard)

        #expect(testPasteboard.pasteboard.string(forType: .string) == "hello")
    }

    @Test("Copy image writes TIFF data")
    func copyImage() {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()

        Pasteboard.copy(image, to: testPasteboard.pasteboard)

        #expect(testPasteboard.pasteboard.data(forType: .tiff) != nil)
    }
}
```

- [ ] **Step 3: `copippe/Pasteboard.swift` を実装する**

```swift
import AppKit

/// クリップボード書き込みの共通入口(clearContents + set のペア漏れを防ぐ)
enum Pasteboard {
    static func copy(_ string: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    static func copy(_ image: NSImage, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
}
```

- [ ] **Step 4: pbxproj 登録(付録 A: `Pasteboard.swift` → アプリターゲット、`PasteboardTests.swift` → テストターゲット)→ テスト green を確認**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 既存 5 箇所を置き換える**

1. `CopippeApp.swift:51-55`(snippet ホットキー発火時):
```swift
            case .snippet(let id):
                if let snippet = self.snippetManager.snippet(for: id) {
                    Pasteboard.copy(snippet.content)
                }
```
2. `MenuView.swift:57-62`(スニペットメニュー):
```swift
                                Button {
                                    Pasteboard.copy(snippet.content)
                                } label: {
```
3. `PopupWindow.swift` の `copySnippet`:
```swift
    private func copySnippet(_ snippet: Snippet) {
        Pasteboard.copy(snippet.content)
        onDismiss()
    }
```
4. `HistoryManager.copyToClipboard(at:)`:
```swift
    func copyToClipboard(at index: Int) {
        guard entries.indices.contains(index) else { return }
        switch entries[index] {
        case .text(_, let string):
            Pasteboard.copy(string)
        case .image(_, let imageID):
            if let image = imageStore.load(id: imageID) {
                Pasteboard.copy(image)
            }
        }
    }
```
5. `ClipboardMonitor.handleClipboardChange()` のプレーンテキスト書き戻し:
```swift
        // Write plain text back to clipboard only when active
        if appState.isActive {
            Pasteboard.copy(plainText)
            lastChangeCount = NSPasteboard.general.changeCount
        }
```

- [ ] **Step 6: 全テスト・手動確認(メニュー/ポップアップ/スニペットからのコピー、プレーン化)・コミット**

```bash
git add copippe/Pasteboard.swift copippeTests/TestSupport.swift copippeTests/PasteboardTests.swift copippe/CopippeApp.swift copippe/MenuView.swift copippe/PopupWindow.swift copippe/HistoryManager.swift copippe/ClipboardMonitor.swift copippe.xcodeproj/project.pbxproj
git commit -m "refactor: consolidate clipboard writes into Pasteboard helper"
```

### Task 4.3: AppState の UserDefaults ボイラープレートを除去する(A6)

**Files:**
- Modify: `copippe/AppState.swift`

- [ ] **Step 1: `register(defaults:)` ベースに書き換える**

init を以下に置き換える(「存在チェック + デフォルト書込」ブロックを廃止。`register` はメモリ上のデフォルト値を与えるため、キー不在時の読み値が従来と同一になる):

```swift
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.isActiveKey: true,
            Self.maxHistoryCountKey: 30,
        ])
        self.isActive = defaults.bool(forKey: Self.isActiveKey)
        self.maxHistoryCount = defaults.integer(forKey: Self.maxHistoryCountKey)
    }
```

(Task 3.1 適用後なので `defaultPlainTextMode` ブロックは既に存在しない。)

挙動差の確認: 従来は初回起動時にデフォルト値をディスクへ書いていたが、`register` はメモリのみ。**外部から観測できる読み値は同一**(didSet 書込も維持)のため動作不変。AppStateTests は読み値のみ検証しているので green のまま。

- [ ] **Step 2: テスト実行・コミット**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

```bash
git add copippe/AppState.swift
git commit -m "refactor: replace UserDefaults boilerplate with register(defaults:)"
```

### Task 4.4: previewText を共通化する(A5)

**Files:**
- Create: `copippe/StringPreview.swift`
- Create: `copippeTests/StringPreviewTests.swift`
- Modify: `copippe/MenuView.swift`、`copippe/PopupWindow.swift`
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: 失敗するテストを書く(`copippeTests/StringPreviewTests.swift`)**

```swift
import Testing
@testable import copippe

@Suite("String singleLinePreview Tests")
struct StringPreviewTests {

    @Test("Newlines are flattened to spaces")
    func flattensNewlines() {
        #expect("a\nb".singleLinePreview(maxLength: 50) == "a b")
    }

    @Test("Short text is returned unchanged")
    func shortText() {
        #expect("hello".singleLinePreview(maxLength: 50) == "hello")
    }

    @Test("Long text is truncated with ellipsis")
    func truncatesLongText() {
        let text = String(repeating: "x", count: 60)
        let preview = text.singleLinePreview(maxLength: 50)
        #expect(preview == String(repeating: "x", count: 50) + "...")
    }
}
```

- [ ] **Step 2: `copippe/StringPreview.swift` を実装する**

```swift
import Foundation

extension String {
    /// メニュー・リスト表示用の 1 行プレビュー(改行をスペース化し maxLength で切り詰め)
    func singleLinePreview(maxLength: Int) -> String {
        let singleLine = replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > maxLength else { return singleLine }
        return String(singleLine.prefix(maxLength)) + "..."
    }
}
```

- [ ] **Step 3: pbxproj 登録(付録 A: `StringPreview.swift` → アプリターゲット、`StringPreviewTests.swift` → テストターゲット)→ テスト green 確認**

- [ ] **Step 4: 重複を置き換える**

- `MenuView.swift`: `previewText(string)` 呼び出しを `string.singleLinePreview(maxLength: 50)` に変更し、`private func previewText` を削除
- `PopupWindow.swift`: `previewText(string)` 呼び出しを `string.singleLinePreview(maxLength: 80)` に変更し、`private func previewText` を削除

- [ ] **Step 5: 全テスト・コミット**

```bash
git add copippe/StringPreview.swift copippeTests/StringPreviewTests.swift copippe/MenuView.swift copippe/PopupWindow.swift copippe.xcodeproj/project.pbxproj
git commit -m "refactor: extract shared singleLinePreview string helper"
```

### Task 4.5: 履歴 API を entry ベースに変える(A9)

**Files:**
- Modify: `copippe/HistoryManager.swift`(`copy(_:)` 追加・`copyToClipboard(at:)` 削除・`search` の戻り値変更)
- Modify: `copippe/MenuView.swift`、`copippe/PopupWindow.swift`(呼び出し側)
- Modify: `copippeTests/HistoryManagerTests.swift`(search テスト)

- [ ] **Step 1: 失敗するテストを書く(search の戻り値変更)**

`HistoryManagerTests` の search 系 2 テストを以下に置き換える:

```swift
    @Test("Search finds matching text entries")
    func searchText() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello World"))
        manager.addEntry(.text(value: "Goodbye"))
        manager.addEntry(.text(value: "Hello Again"))

        let results = manager.search("hello")
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.textValue?.lowercased().contains("hello") == true })
    }

    @Test("Search returns empty for no matches")
    func searchNoMatch() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello"))
        let results = manager.search("xyz")
        #expect(results.isEmpty)
    }
```

- [ ] **Step 2: HistoryManager の API を置き換える**

```swift
    func copy(_ entry: HistoryEntry) {
        switch entry {
        case .text(_, let string):
            Pasteboard.copy(string)
        case .image(_, let imageID):
            if let image = imageStore.load(id: imageID) {
                Pasteboard.copy(image)
            }
        }
    }

    func search(_ query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        let lowercased = query.lowercased()
        return entries.filter { entry in
            entry.textValue?.lowercased().contains(lowercased) == true
        }
    }
```

(`copyToClipboard(at:)` は削除。)

- [ ] **Step 3: 呼び出し側を更新する**

`MenuView.swift` の履歴 ForEach を entry ベースに(Task 2.4 の暫定修正を置き換える):

```swift
                ForEach(historyManager.entries) { entry in
                    Button {
                        historyManager.copy(entry)
                    } label: {
                        historyEntryLabel(entry)
                    }
                }
```

`PopupWindow.swift` の履歴リストを entry ベースに(`filteredHistoryIndices` / `historyRowView(index:)` を置換):

```swift
    private var filteredHistoryEntries: [HistoryEntry] {
        historyManager.search(searchText)
    }

    private var historyListView: some View {
        Group {
            if filteredHistoryEntries.isEmpty {
                emptyView("No history items")
            } else {
                List(filteredHistoryEntries) { entry in
                    historyRowView(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            historyManager.copy(entry)
                            onDismiss()
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func historyRowView(entry: HistoryEntry) -> some View {
        HStack(spacing: 8) {
            switch entry {
            case .text(_, let string):
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(string.singleLinePreview(maxLength: 80))
                    .lineLimit(2)
                    .font(.system(size: 13))

            case .image(_, let imageID):
                if let thumbnail = historyManager.imageStore.thumbnail(id: imageID) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "photo")
                        .frame(width: 40, height: 40)
                }
                Text("Image")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
```

(`search` が空クエリで全件を返すため、`searchText.isEmpty` の分岐も不要になる。)

- [ ] **Step 4: 全テスト・手動確認(メニュー/ポップアップからのコピー、検索)・コミット**

```bash
git add copippe/HistoryManager.swift copippe/MenuView.swift copippe/PopupWindow.swift copippeTests/HistoryManagerTests.swift
git commit -m "refactor: replace index-based history APIs with entry-based ones"
```

---

## Phase 5: 並行性モデルの統一(@MainActor)

**目的:** UI から直接利用される `@Observable` クラス群を `@MainActor` に統一し、Swift 6 strict concurrency 下で偶然動いている状態をなくす(A7)。

### Task 5.1: 全マネージャ・ストアを @MainActor 化する

**Files:**
- Modify: `copippe/AppState.swift`、`copippe/HistoryManager.swift`、`copippe/SnippetManager.swift`、`copippe/ImageStore.swift`、`copippe/ClipboardMonitor.swift`
- Modify: `copippeTests/`(全スイート)

- [ ] **Step 1: 各クラス宣言に `@MainActor` を付与する**

```swift
@MainActor
@Observable
final class AppState { ... }
```

同様に `HistoryManager` / `SnippetManager` / `ImageStore` / `ClipboardMonitor` に付与する(`PopupState` は Task 2.3 で付与済み。`HotkeyManager` / `AppDelegate` / `PopupWindowController` は既に付与済み)。

- [ ] **Step 2: ClipboardMonitor の Timer クロージャを分離境界に適合させる**

`startMonitoring()` を以下に置き換える(Timer の `@Sendable` クロージャから MainActor 隔離メソッドを呼ぶため。Timer は `applicationDidFinishLaunching`(メインスレッド)から登録されメイン RunLoop で発火するので `assumeIsolated` は安全):

```swift
    func startMonitoring() {
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkClipboard()
            }
        }
    }
```

- [ ] **Step 3: テストスイートも同時に @MainActor 化する**

マネージャ群が `@MainActor` になると、それを同期アクセスする既存テストは**テストターゲットでコンパイルエラー**になる。アプリだけビルドして安心しないこと(`xcodebuild build` はテストターゲットをコンパイルしない)。本体への付与と同じコミット内で、`AppStateTests` / `HistoryManagerTests` / `SnippetManagerTests` / `ImageStoreTests` / `PersistenceTests` / `PasteboardTests` / `StringPreviewTests` の各 `@Suite` 直下に `@MainActor` を付与する(`HotkeyManagerTests` は付与済み):

```swift
@Suite("AppState Tests")
@MainActor
struct AppStateTests { ... }
```

- [ ] **Step 4: 両ターゲットをまとめてコンパイルし、残りの分離エラーを潰す**

Run: `xcodebuild build-for-testing -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST BUILD SUCCEEDED **`(`build-for-testing` はアプリ+テスト両ターゲットをコンパイルするため、ここを検証ゲートにする)

初回はエラーが出る可能性が高い。典型的には:
- `deinit` から MainActor メソッドを呼んでいる箇所 → 呼び出しを削除し、所有側(AppDelegate.applicationWillTerminate)に寄せる
- View の `init` / プロパティデフォルト値での生成 → `AppDelegate` での生成に寄せる(現状の構成はこの形なので大きな問題は出ない想定)

エラーが出るたびに「呼び出し元を MainActor に揃える」方向で修正し、`nonisolated(unsafe)` や `@unchecked Sendable` での回避はしない。

- [ ] **Step 5: 全テスト・手動スモーク(起動・コピー・履歴・ポップアップ)・コミット**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

```bash
git add copippe/ copippeTests/
git commit -m "refactor: unify actor isolation with @MainActor across managers"
```

---

## Phase 6: ファイル構造整理

**目的:** 1 ファイル多型の解消と命名整合(A8)。**ロジックは一切変更しない(移動のみ)。**

注意(pbxproj): 新規ファイルの追加・既存ファイルの削除はいずれも付録 A の手順に従う(本フェーズの新規ファイルはすべて**アプリターゲット**)。特に**ファイル削除時は 4 箇所すべて**(PBXBuildFile エントリ / PBXFileReference エントリ / PBXGroup の children 行 / PBXSourcesBuildPhase の files 行)を取り除くこと — 1 箇所でも残すと missing file でビルドが壊れる。各ファイル移動後に必ずビルドする。

### Task 6.1: PreferencesWindow.swift を 4 ファイルに分割する

**Files:**
- Create: `copippe/PreferencesView.swift`(`PreferencesView` のみ)
- Create: `copippe/GeneralTab.swift`(`GeneralTab`)
- Create: `copippe/HotkeyTab.swift`(`HotkeyTab` + `KeyRecorderButton` — 常にペアで使うため同居)
- Create: `copippe/SnippetTab.swift`(`SnippetTab`)
- Delete: `copippe/PreferencesWindow.swift`
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: 4 つの新ファイルへ型をそのまま移動する**

コード変更なしの移動のみ。import は各ファイルで必要なもののみ: PreferencesView → `SwiftUI`、GeneralTab → `SwiftUI` + `ServiceManagement`、HotkeyTab → `SwiftUI` + `AppKit`、SnippetTab → `SwiftUI`。

- [ ] **Step 2: `PreferencesWindow.swift` を削除し、pbxproj を更新する**

- [ ] **Step 3: ビルド・全テスト・コミット**

```bash
git add copippe/ copippe.xcodeproj/project.pbxproj
git commit -m "refactor: split PreferencesWindow.swift into per-view files"
```

### Task 6.2: KeyCodeMap を Models.swift から分離する

**Files:**
- Create: `copippe/KeyCodeMap.swift`(`KeyCodeMap` enum を移動。import は `Foundation` のみ)
- Modify: `copippe/Models.swift`(`KeyCodeMap` 削除)
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: 移動・pbxproj 登録・ビルド・コミット**

```bash
git add copippe/KeyCodeMap.swift copippe/Models.swift copippe.xcodeproj/project.pbxproj
git commit -m "refactor: move KeyCodeMap out of Models.swift"
```

### Task 6.3: PopupWindow.swift を Controller と View に分割する

**Files:**
- Create: `copippe/PopupContentView.swift`(`PopupContentView` を移動)
- Modify: `copippe/PopupWindow.swift`(`PopupState` + `PopupWindowController` のみ残す)
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: 移動・pbxproj 登録・ビルド・全テスト・コミット**

```bash
git add copippe/PopupContentView.swift copippe/PopupWindow.swift copippe.xcodeproj/project.pbxproj
git commit -m "refactor: split PopupContentView from PopupWindow.swift"
```

---

## Phase 7: エラーハンドリング(ログ導入)

**目的:** 永続化失敗の黙殺をやめ、Console.app で診断可能にする(E1)。**ユーザー向け動作は不変。**

### Task 7.1: os.Logger を導入して空 catch にログを入れる

**Files:**
- Create: `copippe/Logging.swift`
- Modify: `copippe/Persistence.swift`、`copippe/ImageStore.swift`、`copippe/CopippeApp.swift`、`copippe/HotkeyManager.swift`
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: `copippe/Logging.swift` を作成する**

```swift
import os

extension Logger {
    private static let subsystem = "com.copippe.app"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let app = Logger(subsystem: subsystem, category: "app")
}
```

- [ ] **Step 2: 各空 catch にログを追加する**

`Persistence.swift` の `JSONFileStore.save`:

```swift
        } catch {
            Logger.persistence.error("Failed to save \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
```

`ImageStore.swift` の `save(_:)` の catch:

```swift
        } catch {
            Logger.persistence.error("Failed to save image: \(error.localizedDescription)")
            return nil
        }
```

`CopippeApp.swift` の login item 登録 catch:

```swift
            } catch {
                Logger.app.error("Failed to register login item: \(error.localizedDescription)")
            }
```

`HotkeyManager.saveHotkeys()` の encode 失敗(現状 `if let` で黙殺)を明示する:

```swift
        do {
            let data = try JSONEncoder().encode(serializable)
            defaults.set(data, forKey: Self.hotkeyDefaultsKey)
        } catch {
            Logger.persistence.error("Failed to encode hotkeys: \(error.localizedDescription)")
        }
```

- [ ] **Step 3: pbxproj 登録(付録 A: `Logging.swift` → **アプリターゲット**)・ビルド・全テスト・コミット**

```bash
git add copippe/Logging.swift copippe/Persistence.swift copippe/ImageStore.swift copippe/CopippeApp.swift copippe/HotkeyManager.swift copippe.xcodeproj/project.pbxproj
git commit -m "refactor: log persistence failures instead of swallowing them"
```

---

## Phase 8: 最終検証・締め

### Task 8.1: ClipboardMonitor の変換ロジックにテストを追加する(T1)

**Files:**
- Modify: `copippe/ClipboardMonitor.swift`(変換関数をテスト可能にする)
- Create: `copippeTests/ClipboardMonitorTests.swift`
- Modify: `copippe.xcodeproj/project.pbxproj`

- [ ] **Step 1: 変換ロジックの可視性を変更する**

`extractImage(from:)` / `convertToPlainText(from:)` の `private` を外す(`@testable import` で見えるよう internal にする。挙動不変):

```swift
    func extractImage(from pasteboard: NSPasteboard) -> NSImage? { ... }
    func convertToPlainText(from pasteboard: NSPasteboard) -> String? { ... }
```

- [ ] **Step 2: テストを書く(`copippeTests/ClipboardMonitorTests.swift`)**

```swift
import AppKit
import Testing
@testable import copippe

@Suite("ClipboardMonitor Tests")
@MainActor
struct ClipboardMonitorTests {

    private let testDefaults = TestDefaults()
    private let testPasteboard = TestPasteboard()

    private func makeMonitor() -> ClipboardMonitor {
        let appState = AppState(defaults: testDefaults.defaults)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
        let historyManager = HistoryManager(
            appState: appState,
            fileURL: tempDir.appendingPathComponent("history.json"),
            imageStore: ImageStore(directory: tempDir.appendingPathComponent("images", isDirectory: true))
        )
        return ClipboardMonitor(appState: appState, historyManager: historyManager)
    }

    @Test("Plain string is extracted as-is")
    func plainString() {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)

        #expect(monitor.convertToPlainText(from: pasteboard) == "hello")
    }

    @Test("RTF data is converted to plain text")
    func rtfToPlainText() throws {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        let attributed = NSAttributedString(string: "styled", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        let rtfData = try #require(attributed.rtf(from: NSRange(location: 0, length: attributed.length)))
        pasteboard.clearContents()
        pasteboard.setData(rtfData, forType: .rtf)

        #expect(monitor.convertToPlainText(from: pasteboard) == "styled")
    }

    @Test("Empty pasteboard yields nil")
    func emptyPasteboard() {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        pasteboard.clearContents()

        #expect(monitor.convertToPlainText(from: pasteboard) == nil)
    }

    @Test("Image data is extracted as NSImage")
    func imageExtraction() throws {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        let tiff = try #require(image.tiffRepresentation)
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)

        #expect(monitor.extractImage(from: pasteboard) != nil)
    }
}
```

注: `convertToPlainText` / `extractImage` は引数の pasteboard のみに依存するため、`TestPasteboard` の隔離ペーストボードで `NSPasteboard.general` に触れずにテストできる。

- [ ] **Step 3: pbxproj 登録(付録 A: `ClipboardMonitorTests.swift` → **テストターゲット**)・テスト green 確認・コミット**

```bash
git add copippe/ClipboardMonitor.swift copippeTests/ClipboardMonitorTests.swift copippe.xcodeproj/project.pbxproj
git commit -m "test: add ClipboardMonitor conversion tests"
```

### Task 8.2: 最終検証チェックリスト

- [ ] **Step 1: クリーンビルド(Debug / Release)**

Run: `xcodebuild -project copippe.xcodeproj -scheme copippe -configuration Debug clean build && xcodebuild -project copippe.xcodeproj -scheme copippe -configuration Release build`
Expected: 両方 `** BUILD SUCCEEDED **`、新規警告ゼロ

- [ ] **Step 2: 全テスト**

Run: `xcodebuild test -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: 手動スモークテスト(全機能)**

1. アプリ起動 → メニューバーにアイコン表示
2. リッチテキスト(例: Safari の文字)をコピー → 貼り付けでプレーン化されている(isActive オン時)
3. メニューバーから Inactive に切替 → リッチテキストが保持される
4. テキストを 2 回コピー → 履歴に重複しない
5. スクリーンショット(⌘⇧⌃4)→ 履歴に画像エントリ + サムネイル表示
6. ⌃⌥V → ポップアップ表示、検索でフィルタ、クリックでコピー
7. ポップアップ表示中に Escape → 閉じる
8. Preferences > General: History limit 変更が反映される
9. Preferences > Hotkeys: ホットキー変更 → 新キーで動作、競合時アラート
10. Preferences > Snippets: フォルダ作成 / リネーム / スニペット作成・編集・削除、メニューとポップアップに反映
11. Launch at login オフ → 再起動してもオフのまま
12. アプリ終了 → 再起動 → 履歴・スニペットが復元される

- [ ] **Step 4: 残骸チェック**

Run: `grep -rn "TODO\|FIXME\|isUpdatingClipboard\|defaultPlainTextMode\|updateHotkey\|copyToClipboard" copippe/ copippeTests/`
Expected: ヒットなし

- [ ] **Step 5: git 状態確認**

Run: `git status --short && git log --oneline -30`
Expected: ワーキングツリーがクリーンで、本プランのコミットが Conventional Commits 形式で並んでいる

---

## スコープ外(今後の課題として別プランを推奨)

本プランは「無駄の解消」に限定する。以下は意図的に**やらない**:

1. **スニペットへのホットキー割当 UI**(D3 の機能完成)— `Snippet.hotkey` モデル・実行系・表示・`setSnippetHotkey` は温存してあるので、SnippetTab に `KeyRecorderButton` を置く小さな機能追加プランで実現できる
2. **Show Snippets のグローバルホットキー設定 UI** — `HotkeyAction.showSnippets` の実行系はあるが既定バインドも設定 UI もない(現状と同じ)
3. **`docs/` 配下の HTML 重複**(guide.html / guide-ja.html 等)— GitHub Pages サイトの構成変更はコードと独立した作業
4. **履歴の個別削除 UI** — Task 3.2 で API を削除した。必要になったら UI とセットで再設計
5. **ImageStore のサムネイルキャッシュ上限**(メモリ管理)— 履歴上限 100 件・40〜80px サムネイルでは実害なし
6. **`UserInterfaceState.xcuserstate` を含む過去履歴の書き換え**(git filter-repo)— 機密ではないため履歴改変のリスクに見合わない

## 実行メモ

- 各フェーズ末で必ず: ビルド green / テスト green / 手動スモーク(最低: 起動・コピー・履歴・ポップアップ)
- 途中で想定外のコンパイルエラー・テスト失敗に 30 分以上詰まったら、そのタスクを revert して原因を記録し、プランを修正してから再開する
- pbxproj 編集が壊れた場合は `git checkout -- copippe.xcodeproj/project.pbxproj` で戻し、付録 A の手順を再確認するか、Xcode GUI でのファイル追加(ターゲットチェックボックスに注意)に切り替える

---

## 付録 A: project.pbxproj へのファイル追加・削除手順(objectVersion 56)

このプロジェクトは Xcode の手動ファイル管理形式(objectVersion 56、folder-synchronized group なし)。新規ファイルはエディタで作るだけではビルド対象にならず、pbxproj への登録が必要。

### 前提知識(このプロジェクトの実際の構造)

- ID 規約: PBXBuildFile は `A1xxxx`、PBXFileReference は `B1xxxx` の連番(例: `A10001`/`B10001` = CopippeApp.swift)
- グループ: `G10002 /* copippe */` = アプリのソースグループ、`G10003 /* copippeTests */` = テストのソースグループ
- `PBXSourcesBuildPhase` セクションには**ブロックが 2 つ**ある: 先頭(アプリターゲット `copippe` 用、既存エントリに CopippeApp.swift 等が並ぶ)と後方(テストターゲット `copippeTests` 用、既存エントリに AppStateTests.swift 等が並ぶ)。**どちらに追加するかはファイルの所属ターゲットで決まる**

### ターゲットの対応(本プランで作る全ファイル)

| ファイル | グループ | Sources(ビルドフェーズ) |
|---------|---------|--------------------------|
| `copippe/Persistence.swift`、`copippe/Pasteboard.swift`、`copippe/StringPreview.swift`、`copippe/Logging.swift`、Phase 6 の分割ファイル群 | `G10002 /* copippe */` | **アプリターゲット**側 |
| `copippeTests/TestSupport.swift`、`copippeTests/PersistenceTests.swift`、`copippeTests/PasteboardTests.swift`、`copippeTests/StringPreviewTests.swift`、`copippeTests/ClipboardMonitorTests.swift` | `G10003 /* copippeTests */` | **テストターゲット**側 |

取り違えると: テストファイルをアプリ側に入れる → `@testable import copippe` がアプリ本体にリンクされビルドエラー、またはテストが test バンドルに含まれず**静かに実行されない**。

### 採番ルール

既存 ID の最大値は `A10033`/`B10033`(2026-06-10 時点)。本プランで追加するファイルは **`A10034`/`B10034` から順に**(`A10035`/`B10035`, `A10036`/`B10036`, …)採番する。歯抜け ID(`A10027`〜`A10030` 等)は使わない。**採番のたびに必ず** `grep -c "A100XX" copippe.xcodeproj/project.pbxproj` **が 0 であることを確認してから使う**(0 以外なら衝突しているので次の番号へ)。

### 追加手順 — 例 1: テストターゲットへ(`copippeTests/TestSupport.swift`)

1. 一意 ID を 2 つ決める(例: BuildFile `A10034`、FileReference `B10034`)。`grep -c "A10034" copippe.xcodeproj/project.pbxproj` と `grep -c "B10034" copippe.xcodeproj/project.pbxproj` がともに 0 であることを確認
2. `PBXBuildFile` セクションに追加:
   `A10034 /* TestSupport.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10034 /* TestSupport.swift */; };`
3. `PBXFileReference` セクションに追加(既存の Swift ファイル行をテンプレートにする):
   `B10034 /* TestSupport.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TestSupport.swift; sourceTree = "<group>"; };`
4. **所属グループ**の `children` に `B10034 /* TestSupport.swift */,` を追加(この例ではテストなので `G10003 /* copippeTests */`)
5. **所属ターゲット**の `PBXSourcesBuildPhase` の `files` に `A10034 /* TestSupport.swift in Sources */,` を追加(この例ではテストターゲット側のブロック — 既存エントリに `*Tests.swift` が並んでいる方)
6. 検証: `xcodebuild build-for-testing -project copippe.xcodeproj -scheme copippe -destination 'platform=macOS'` が `** TEST BUILD SUCCEEDED **`

### 追加手順 — 例 2: アプリターゲットへ(`copippe/Persistence.swift`)

手順は例 1 と同じで、配置先だけが変わる(ID は採番ルールに従い次の空き番号を使う。ここでは仮に `A10035`/`B10035`):

1. `PBXBuildFile`: `A10035 /* Persistence.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10035 /* Persistence.swift */; };`
2. `PBXFileReference`: `B10035 /* Persistence.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Persistence.swift; sourceTree = "<group>"; };`
3. グループは `G10002 /* copippe */` の `children` へ、Sources は**アプリターゲット側**の `PBXSourcesBuildPhase`(既存エントリに `CopippeApp.swift` 等が並んでいる方)の `files` へ追加
4. 検証は例 1 と同じ

### 削除手順(例: Phase 6 の `PreferencesWindow.swift`)

該当ファイルの ID を `grep -n "PreferencesWindow.swift" copippe.xcodeproj/project.pbxproj` で確認し、**4 箇所すべて**を削除する:

1. `PBXBuildFile` セクションの該当行
2. `PBXFileReference` セクションの該当行
3. 所属グループ(`G10002` または `G10003`)の `children` 内の該当行
4. 所属ターゲットの `PBXSourcesBuildPhase` の `files` 内の該当行

1 箇所でも残すと missing file エラーでビルドが壊れる。削除後に必ず `xcodebuild build-for-testing` で確認する。
