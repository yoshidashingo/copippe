# Code Summary - copippe

## Generated Files

### Application Code (`copippe/`)
| File | Description |
|------|-------------|
| `CopippeApp.swift` | SwiftUI @main エントリポイント。NSApplicationDelegateAdaptorでAppDelegate連携。MenuBarExtraでメニューバー常駐。 |
| `AppState.swift` | @Observable状態管理。Activate/Deactivateの状態保持とUserDefaults永続化。 |
| `ClipboardMonitor.swift` | Timer-basedクリップボード監視（0.5秒間隔）。NSPasteboard.changeCountで変更検知。リッチテキスト→プレーンテキスト変換。 |
| `HistoryManager.swift` | 最大20件のFIFO履歴管理。JSON永続化（Application Supportディレクトリ）。重複排除機能。 |
| `MenuView.swift` | SwiftUIメニュービュー。Activate/Deactivateトグル、履歴一覧、クリア、Quit。 |
| `copippe.entitlements` | App Sandbox有効化。 |

### Test Code (`copippeTests/`)
| File | Tests |
|------|-------|
| `AppStateTests.swift` | 初期状態、トグル、UserDefaults永続化 (3テスト) |
| `HistoryManagerTests.swift` | 追加、重複防止、最大件数、空エントリ、削除、クリア (8テスト) |

### Project Configuration
| File | Description |
|------|-------------|
| `copippe.xcodeproj/project.pbxproj` | Xcodeプロジェクト設定。macOS 14+、Swift 6、LSUIElement=YES、App Sandbox。 |

## Key Design Decisions
- **クリップボード監視**: Timer（0.5秒間隔）によるポーリング。macOSにはクリップボード変更通知がないため、changeCountの比較が標準手法。
- **自己変更の無視**: `isUpdatingClipboard`フラグで、自身のクリップボード書き戻しによる無限ループを防止。
- **永続化**: Application Support/copippe/history.json にJSON保存。App Sandbox対応。
- **ログイン自動起動**: SMAppService.mainApp.register() を使用（macOS 13+）。
