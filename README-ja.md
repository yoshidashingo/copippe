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

- **プレーンテキストペースト** — Activate時、コピー操作でリッチテキストの書式（HTML、RTF）を自動的に除去し、常にプレーンテキストとして貼り付けできます
- **クリップボード履歴** — メニューバーのドロップダウンから最大20件のコピー履歴にアクセス可能
- **メニューバー常駐** — Dockにアイコンを表示せず、メニューバーで静かに動作
- **履歴の永続化** — クリップボード履歴はアプリ再起動後も保持されます
- **自動起動** — macOSのログイン項目を利用して、ログイン時に自動起動
- **軽量設計** — SwiftとSwiftUIで構築し、メモリ使用量を最小限に抑えています

## 動作環境

- macOS 14 (Sonoma) 以降

## インストール

1. **[Releases ページ](https://github.com/yoshidashingo/copippe/releases/latest)**から最新版をダウンロード:
   - [`copippe-v0.1.zip`](https://github.com/yoshidashingo/copippe/releases/latest/download/copippe-v0.1.zip) — Zipアーカイブ
   - [`copippe-v0.1.dmg`](https://github.com/yoshidashingo/copippe/releases/latest/download/copippe-v0.1.dmg) — ディスクイメージ
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
4. **履歴** — 履歴の項目をクリックするとクリップボードにセットされるので、⌘Vで貼り付け
5. **Clear History** — 保存された履歴をすべて削除
6. **Quit** — アプリを終了

### メニューバーアイコン

| 状態 | アイコン |
|------|----------|
| Active | 塗りつぶしクリップボードアイコン |
| Inactive | 枠線クリップボードアイコン |

## ソースからビルド

```bash
git clone https://github.com/yoshidashingo/copippe.git
cd copippe
xcodebuild -project copippe.xcodeproj -scheme copippe -configuration Release build
```

または `copippe.xcodeproj` をXcodeで開いて ⌘B でビルドしてください。

## ライセンス

MIT
