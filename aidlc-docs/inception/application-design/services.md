# Services

## Overview

copippeは小規模なユーティリティアプリのため、明示的なサービスレイヤーは設けず、コンポーネント間の直接的な依存関係で構成する。

## Orchestration Pattern

```
CopippeApp (Entry Point)
    |
    +-- AppState (@Observable, shared state)
    |       |
    +-- ClipboardMonitor (reads AppState.isActive)
    |       |
    |       +-- HistoryManager (addEntry on clipboard change)
    |
    +-- MenuView (reads AppState, HistoryManager)
            |
            +-- Toggle → AppState.toggleActivation()
            +-- History click → HistoryManager.copyToClipboard()
            +-- Quit → NSApplication.terminate()
```

## Data Flow

1. **コピー検知フロー**:
   ClipboardMonitor (polling) → 変更検知 → AppState.isActive確認 → プレーンテキスト変換 → HistoryManager.addEntry() → クリップボード書き戻し

2. **履歴ペーストフロー**:
   MenuView → HistoryManager.copyToClipboard() → NSPasteboard.general にセット → ユーザーがCmd+V

3. **状態切り替えフロー**:
   MenuView → AppState.toggleActivation() → ClipboardMonitor が isActive を参照して動作変更
