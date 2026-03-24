# Component Methods

## ClipboardMonitor

### startMonitoring()
- **Purpose**: クリップボード監視を開始する
- **Input**: なし
- **Output**: なし
- **Note**: Timer-basedポーリングでNSPasteboard.generalの`changeCount`を監視

### stopMonitoring()
- **Purpose**: クリップボード監視を停止する
- **Input**: なし
- **Output**: なし

### handleClipboardChange()
- **Purpose**: クリップボード変更を検知した際の処理
- **Input**: なし
- **Output**: なし
- **Note**: プレーンテキスト変換 → 履歴追加 → クリップボード書き戻し

### convertToPlainText(_ content: NSPasteboard) -> String?
- **Purpose**: クリップボードの内容をプレーンテキストに変換
- **Input**: NSPasteboard
- **Output**: String?（プレーンテキスト、取得できない場合nil）

## HistoryManager

### addEntry(_ text: String)
- **Purpose**: 履歴に新しいエントリを追加
- **Input**: String（コピーされたテキスト）
- **Output**: なし
- **Note**: 20件超過時は最古を削除、重複連続防止

### removeEntry(at index: Int)
- **Purpose**: 指定位置の履歴を削除
- **Input**: Int（インデックス）
- **Output**: なし

### clearAll()
- **Purpose**: 全履歴をクリア
- **Input**: なし
- **Output**: なし

### copyToClipboard(at index: Int)
- **Purpose**: 指定履歴項目をクリップボードにセット
- **Input**: Int（インデックス）
- **Output**: なし

### save()
- **Purpose**: 履歴をファイルに永続化
- **Input**: なし
- **Output**: なし

### load()
- **Purpose**: ファイルから履歴を復元
- **Input**: なし
- **Output**: なし

## AppState

### toggleActivation()
- **Purpose**: Activate/Deactivate状態を切り替え
- **Input**: なし
- **Output**: なし

### isActive: Bool (property)
- **Purpose**: 現在のActivate状態
- **Note**: UserDefaultsに永続化
