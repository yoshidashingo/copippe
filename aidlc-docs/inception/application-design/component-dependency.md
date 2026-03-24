# Component Dependencies

## Dependency Matrix

| Component | Depends On | Communication Pattern |
|-----------|-----------|----------------------|
| CopippeApp | AppState, ClipboardMonitor, HistoryManager, MenuView | 初期化・注入 |
| ClipboardMonitor | AppState, HistoryManager | プロパティ参照、メソッド呼び出し |
| HistoryManager | (none) | 独立 |
| MenuView | AppState, HistoryManager | @Observable バインディング |
| AppState | (none) | 独立 |

## Dependency Diagram

```
+------------------+
|   CopippeApp     |
|   (Entry Point)  |
+--------+---------+
         |
         | creates & injects
         |
    +----+----+----------+
    |         |          |
    v         v          v
+--------+ +----------+ +-----------+
|AppState| |Clipboard | |History    |
|        | |Monitor   | |Manager    |
+---+----+ +----+-----+ +-----+-----+
    |           |              |
    |  reads    | calls        |
    |<----------+ addEntry()   |
    |           +------------->|
    |                          |
    v                          v
+--------------------------------+
|          MenuView              |
|  (reads AppState & History)    |
+--------------------------------+
```

## Communication Patterns

- **AppState → ClipboardMonitor**: ClipboardMonitorがAppState.isActiveを参照（@Observable経由）
- **ClipboardMonitor → HistoryManager**: 新しいコピーを検知した際にaddEntry()を呼び出し
- **MenuView → AppState**: Activate/Deactivateトグルの操作
- **MenuView → HistoryManager**: 履歴項目クリック時のcopyToClipboard()呼び出し、clearAll()
- **HistoryManager**: 独立コンポーネント。外部依存なし。永続化はApp Sandbox内のファイルに保存
