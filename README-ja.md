<h1 align="center">
  <img src="docs/icon.png" alt="copippe" width="128">
  <br>
  copippe
  <br>
  <br>
</h1>

<p align="center">
  Macで稼働するシンプルでメモリフットプリントの小さいクリップボードツールです。
</p>

<p align="center">
  <a href="https://github.com/yoshidashingo/copippe/releases/latest"><img src="https://img.shields.io/github/v/release/yoshidashingo/copippe?v=1" alt="release"></a>
  <a href="https://github.com/yoshidashingo/copippe/blob/main/LICENSE"><img src="https://img.shields.io/github/license/yoshidashingo/copippe?v=1" alt="license"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="platform">
  <img src="https://img.shields.io/badge/swift-6-orange" alt="swift">
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README-ja.md">日本語</a>
</p>

## 特徴

### クリップボード
- **プレーンテキストペースト** — Activate時、コピー操作でリッチテキストの書式（HTML、RTF）を自動的に除去し、常にプレーンテキストとして貼り付けできます
- **クリップボード履歴** — メニューバーのドロップダウンからテキスト・画像を含む最大30件のコピー履歴にアクセス可能（件数は設定で変更可能）
- **画像対応** — コピーした画像をPNGサムネイルとして保存し、クリップボードに復元可能
- **履歴の永続化** — クリップボード履歴はアプリ再起動後も保持されます

### スニペット
- **スニペット管理** — よく使うテキストを登録・編集・管理
- **フォルダ整理** — スニペットをフォルダにグループ分けして整理
- **メニューからアクセス** — メニューバーのフォルダサブメニューからすぐに貼り付け

### 検索・クイックアクセス
- **グローバルホットキー** — どのアプリからでも Ctrl+Option+V でフローティング検索ポップアップを表示
- **ポップアップウィンドウ** — 履歴・スニペットをインクリメンタル検索、キーボードナビゲーション、タブ切り替え対応
- **スニペット個別ホットキー** — 特定のスニペットにグローバルホットキーを割り当てて即座に貼り付け

### 全般
- **メニューバー常駐** — Dockにアイコンを表示せず、メニューバーで静かに動作
- **設定画面** — 履歴件数、ホットキー、起動時動作の設定、スニペット管理を専用ウィンドウから操作
- **自動起動** — macOSのログイン項目を利用して、ログイン時に自動起動
- **軽量設計** — SwiftとSwiftUIで構築し、メモリ使用量を最小限に抑えています

## 動作環境

- macOS 14 (Sonoma) 以降

## インストール

1. **[Releases ページ](https://github.com/yoshidashingo/copippe/releases/latest)** から最新版をダウンロード:
   - `copippe-vX.Y-macOS.zip` — Zipアーカイブ
   - `copippe-vX.Y-macOS.dmg` — ディスクイメージ
2. `.zip` または `.dmg` を開き、`copippe.app` をアプリケーションフォルダに移動
3. copippeを起動

> **注意**: このアプリは公証（Notarization）されていません。初回起動時にmacOSによってブロックされます。以下のいずれかの方法で開いてください:
>
> **方法A**（ターミナル）:
> ```
> xattr -cr /Applications/copippe.app
> ```
> その後、通常通りアプリを起動してください。
>
> **方法B**（システム設定）:
> 1. `copippe.app` を開こうとする（ブロックされます）
> 2. **システム設定** → **プライバシーとセキュリティ** を開く
> 3. 下にスクロールしてブロックされたアプリのメッセージを見つけ、**このまま開く** をクリック

## 使い方

1. copippeを起動すると、メニューバーにクリップボードアイコンが表示されます
2. アイコンをクリックしてドロップダウンメニューを開きます
3. **Activate/Deactivate** — プレーンテキストモードのオン・オフを切り替え
4. **履歴** — テキスト・画像の履歴項目をクリックするとクリップボードにセットされるので、⌘Vで貼り付け
5. **スニペット** — フォルダサブメニューを展開して登録済みスニペットを貼り付け
6. **Preferences** — 設定ウィンドウを開いてホットキー、履歴件数、スニペットを管理
7. **Ctrl+Option+V** — どのアプリからでもフローティングポップアップを開いて履歴・スニペットを検索
8. **Clear History** — 保存された履歴をすべて削除
9. **Quit** — アプリを終了

### メニューバーアイコン

| 状態 | アイコン |
|------|----------|
| Active | 塗りつぶしクリップボードアイコン |
| Inactive | 枠線クリップボードアイコン |

### キーボードショートカット

| ショートカット | 動作 |
|--------------|------|
| Ctrl+Option+V | 履歴・スニペットポップアップを表示 |
| Esc | ポップアップを閉じる |
| ↑/↓ | ポップアップ内の項目を移動 |
| Enter | 選択して貼り付け |

## ソースからビルド

```bash
git clone https://github.com/yoshidashingo/copippe.git
cd copippe
xcodebuild -project copippe.xcodeproj -scheme copippe -configuration Release build
```

または `copippe.xcodeproj` をXcodeで開いて ⌘B でビルドしてください。

## ライセンス

MIT
