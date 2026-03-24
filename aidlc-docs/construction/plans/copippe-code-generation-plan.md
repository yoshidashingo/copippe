# Code Generation Plan - copippe

## Unit Context
- **Unit**: copippe (単一ユニット)
- **Type**: Greenfield macOS MenuBar App
- **Stack**: Swift + SwiftUI, macOS 14+
- **Distribution**: Mac App Store (App Sandbox)

## Generation Steps

### Step 1: Xcode Project Setup
- [x] Xcodeプロジェクト構成ファイルの生成（.xcodeproj/project.pbxproj）
- [x] App Sandbox Entitlements ファイル
- [x] Info.plist 設定（LSUIElement=true）
- [x] Assets.xcassets（アプリアイコン用プレースホルダー）

### Step 2: AppState - 状態管理
- [x] `copippe/AppState.swift` - @Observable状態クラス
- [x] Activate/Deactivate状態管理
- [x] UserDefaultsによる永続化

### Step 3: HistoryManager - 履歴管理
- [x] `copippe/HistoryManager.swift` - 履歴管理クラス
- [x] 最大20件のFIFO管理
- [x] JSON永続化（App Sandboxコンテナ）
- [x] 重複連続コピー防止
- [x] クリップボードセット機能

### Step 4: ClipboardMonitor - クリップボード監視
- [x] `copippe/ClipboardMonitor.swift` - クリップボード監視クラス
- [x] Timer-basedポーリング（NSPasteboard.changeCount）
- [x] リッチテキスト → プレーンテキスト変換
- [x] クリップボード書き戻し
- [x] AppState.isActiveに応じた動作制御

### Step 5: MenuView - メニューUI
- [x] `copippe/MenuView.swift` - SwiftUIメニュービュー
- [x] Activate/Deactivateトグル
- [x] 履歴一覧表示（テキストプレビュー）
- [x] 履歴クリアボタン
- [x] Quitボタン

### Step 6: CopippeApp - エントリポイント
- [x] `copippe/CopippeApp.swift` - SwiftUI Appエントリポイント
- [x] MenuBarExtra構成
- [x] コンポーネント初期化・注入
- [x] SMAppService（ログイン時自動起動）

### Step 7: Unit Tests
- [x] `copippeTests/AppStateTests.swift`
- [x] `copippeTests/HistoryManagerTests.swift`

### Step 8: Documentation
- [x] `aidlc-docs/construction/copippe/code/code-summary.md` - 生成コードのサマリー

## File Structure (Generated)

```
copippe/                          # Workspace root
├── copippe.xcodeproj/
│   └── project.pbxproj
├── copippe/
│   ├── CopippeApp.swift          # App entry point + MenuBarExtra
│   ├── AppState.swift            # @Observable state management
│   ├── ClipboardMonitor.swift    # Clipboard polling + plain text conversion
│   ├── HistoryManager.swift      # History FIFO + persistence
│   ├── MenuView.swift            # Menu UI
│   ├── copippe.entitlements      # App Sandbox
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/
│           └── Contents.json
├── copippeTests/
│   ├── AppStateTests.swift
│   └── HistoryManagerTests.swift
├── README.md
└── .gitignore
```
