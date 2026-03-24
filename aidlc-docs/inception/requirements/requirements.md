# Requirements Document - copippe

## Intent Analysis
- **User Request**: Macで稼働するシンプルでメモリフットプリントの小さいコピペツールの開発
- **Request Type**: New Project（新規プロジェクト）
- **Scope**: System-wide（macOSネイティブアプリケーション全体）
- **Complexity**: Moderate（メニューバー常駐アプリ、クリップボード管理、履歴永続化）

## Technology Stack
- **Language**: Swift
- **Framework**: SwiftUI
- **Minimum OS**: macOS 14 (Sonoma)
- **Distribution**: Mac App Store

## Functional Requirements

### FR-1: メニューバー常駐
- アプリはmacOSメニューバーにアイコンとして常駐する
- Dockにはアイコンを表示しない（メニューバー専用アプリ）
- メニューバーアイコンをクリックするとドロップダウンメニューが表示される

### FR-2: Activate/Deactivate機能
- ドロップダウンメニュー内にActivate/Deactivateの切り替え項目を設ける
- Activate状態：コピー時にリッチテキストからプレーンテキストに変換して保存する
- Deactivate状態：通常のクリップボード動作（変換なし、履歴収集もしない）
- 現在の状態（Active/Inactive）がメニュー上で視覚的にわかること

### FR-3: プレーンテキスト変換
- Activate時、ユーザーがコピー操作を行うと、クリップボードの内容をプレーンテキストに変換する
- リッチテキスト（HTML、RTF等）の書式情報を除去し、純粋なテキストのみを保持する
- 変換後のテキストをクリップボードに書き戻す

### FR-4: コピー履歴管理
- 最大20件のコピー履歴を保持する
- 新しいコピーが追加されると、最も古い履歴が削除される（FIFO）
- 履歴はドロップダウンメニュー内にリスト表示される
- 各履歴項目はテキストの先頭部分をプレビューとして表示する

### FR-5: 履歴からのペースト
- ドロップダウンメニューの履歴項目をクリックすると、その内容がクリップボードにセットされる
- ユーザーは通常のペースト操作（Cmd+V）で貼り付け可能

### FR-6: 履歴の永続化
- コピー履歴はアプリ終了後もファイルに保存される
- アプリ再起動時に履歴を復元する

### FR-7: ログイン時自動起動
- macOSログイン時にアプリを自動起動する機能を含める
- Login Itemsの仕組みを使用する

### FR-8: アプリ終了
- ドロップダウンメニューに「Quit」項目を設ける

## Non-Functional Requirements

### NFR-1: メモリフットプリント
- シンプルでメモリ使用量が小さいことを重視する
- 不要なリソースを保持しない設計とする

### NFR-2: Mac App Store準拠
- App Sandboxに対応する
- App Storeのガイドラインに準拠する
- 適切なエンタイトルメントを設定する

### NFR-3: macOS 14 (Sonoma) 以降対応
- macOS 14以降で動作すること
- SwiftUIのmacOS 14以降で利用可能なAPIを使用する

## Success Criteria
- メニューバーに常駐し、Activate/Deactivateが正しく切り替わる
- コピー時にプレーンテキスト変換が正しく動作する
- 最大20件の履歴が正しく管理される
- 履歴がアプリ再起動後も保持される
- ログイン時に自動起動する
- メモリ使用量が小さい
