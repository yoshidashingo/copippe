# Components

## 1. CopippeApp (App Entry Point)
**Purpose**: SwiftUIアプリケーションのエントリポイント。MenuBarExtraを使用してメニューバー常駐アプリとして構成。

**Responsibilities**:
- アプリケーションライフサイクル管理
- MenuBarExtraの表示
- Dockアイコン非表示の設定（LSUIElement）
- 依存コンポーネントの初期化と注入

## 2. ClipboardMonitor
**Purpose**: システムクリップボード（NSPasteboard）を監視し、コピーイベントを検知する。

**Responsibilities**:
- NSPasteboard.generalの変更検知（ポーリング）
- コピーされたコンテンツの取得
- リッチテキストからプレーンテキストへの変換
- プレーンテキストをクリップボードに書き戻し
- Activate/Deactivate状態に応じた動作切り替え

## 3. HistoryManager
**Purpose**: コピー履歴の管理（追加、削除、永続化）。

**Responsibilities**:
- 最大20件のコピー履歴をFIFOで管理
- 履歴のファイルへの永続化（UserDefaults or JSON file）
- アプリ起動時の履歴復元
- 履歴項目の重複排除（同一テキストの連続コピー防止）
- 特定の履歴項目をクリップボードにセット

## 4. MenuView (SwiftUI View)
**Purpose**: メニューバーのドロップダウンメニューUI。

**Responsibilities**:
- Activate/Deactivateトグルの表示
- コピー履歴一覧の表示（テキストプレビュー付き）
- 履歴項目クリック時のクリップボードセット
- 履歴クリアボタン
- Quitボタン
- 現在のActivate状態の視覚的表示

## 5. AppState (Observable State)
**Purpose**: アプリケーション全体の状態管理。

**Responsibilities**:
- Activate/Deactivate状態の保持
- 状態変更の通知（@Observable）
- 状態の永続化（UserDefaults）
