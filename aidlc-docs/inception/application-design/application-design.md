# Application Design - copippe

## Architecture Overview

copippeは5つのコンポーネントで構成されるシンプルなmacOSメニューバー常駐アプリケーション。

```
+------------------+
|   CopippeApp     |  SwiftUI App Entry Point
|   (MenuBarExtra) |  Dockアイコン非表示
+--------+---------+
         |
    +----+----+----------+
    |         |          |
    v         v          v
+--------+ +----------+ +-----------+
|AppState| |Clipboard | |History    |
|@Obs    | |Monitor   | |Manager    |
+---+----+ +----+-----+ +-----+-----+
    |           |              |
    |  reads    | calls        |
    |<----------+ addEntry()   |
    |           +------------->|
    |                          |
    v                          v
+--------------------------------+
|          MenuView              |
|  Activate toggle, History list |
|  Clear, Quit                   |
+--------------------------------+
```

## Components

### 1. CopippeApp
- SwiftUIアプリエントリポイント
- MenuBarExtraでメニューバー常駐
- LSUIElement=trueでDockアイコン非表示

### 2. AppState (@Observable)
- Activate/Deactivate状態管理
- UserDefaultsに永続化

### 3. ClipboardMonitor
- Timer-basedポーリングでNSPasteboard.general監視
- Activate時のみ動作
- リッチテキスト → プレーンテキスト変換
- 変換後クリップボード書き戻し + 履歴追加

### 4. HistoryManager (@Observable)
- 最大20件のFIFO履歴管理
- JSON/App Sandboxファイルで永続化
- 重複連続コピー防止
- 履歴項目のクリップボードセット

### 5. MenuView
- Activate/Deactivateトグル表示
- 履歴一覧（テキストプレビュー）
- 履歴クリア・Quitボタン

## Data Flow

1. **コピー検知**: ClipboardMonitor → プレーンテキスト変換 → HistoryManager.addEntry() → クリップボード書き戻し
2. **履歴ペースト**: MenuView → HistoryManager.copyToClipboard() → NSPasteboard → Cmd+V
3. **状態切替**: MenuView → AppState.toggleActivation() → ClipboardMonitor動作変更

## Technology Decisions
- **状態管理**: @Observable (macOS 14+)
- **永続化**: JSONファイル（App Sandboxコンテナ内）
- **クリップボード監視**: Timer + NSPasteboard.changeCount（macOS標準手法）
- **自動起動**: SMAppService (Login Items, macOS 13+)
- **メニューバー**: MenuBarExtra (SwiftUI, macOS 13+)
