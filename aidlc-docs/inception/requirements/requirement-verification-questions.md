# Requirements Clarification Questions

copippeの開発要件を明確にするため、以下の質問にお答えください。
各質問の `[Answer]:` タグの後に、選択肢のアルファベットを記入してください。

## Question 1
開発に使用するプログラミング言語・フレームワークはどれですか？

A) Swift + SwiftUI（モダンなmacOSアプリ開発の標準）
B) Swift + AppKit（従来型のmacOSアプリ開発）
C) Objective-C + AppKit（レガシーだがクリップボード操作に実績あり）
D) X) Other (please describe after [Answer]: tag below)

[Answer]:A

## Question 2
アプリの配布方法はどれを想定していますか？

A) Mac App Store経由での配布
B) 自サイトやGitHub Releasesからの直接配布（.dmg / .zip）
C) Homebrew Caskでの配布
D) 配布方法は未定・今は開発のみに集中
E) X) Other (please describe after [Answer]: tag below)

[Answer]:A

## Question 3
「Activate」の切り替え方法はどのようなUIを想定していますか？

A) メニューバーアイコンのクリックでトグル（ON/OFF切り替え）
B) メニューバーのドロップダウンメニュー内にActivate/Deactivateの項目
C) グローバルキーボードショートカットで切り替え
D) A + C の組み合わせ（メニューバークリック＋キーボードショートカット両対応）
E) X) Other (please describe after [Answer]: tag below)

[Answer]:B

## Question 4
コピー履歴の保存はアプリ終了後も永続化しますか？

A) アプリ終了時に履歴をクリア（メモリ上のみ）
B) アプリ再起動後も履歴を保持（ファイルに永続化）
C) ユーザーが選択可能（設定で切り替え）
D) X) Other (please describe after [Answer]: tag below)

[Answer]:B

## Question 5
macOSの最小サポートバージョンはどれですか？

A) macOS 14 (Sonoma) 以降
B) macOS 13 (Ventura) 以降
C) macOS 12 (Monterey) 以降
D) できるだけ古いバージョンもサポートしたい
E) X) Other (please describe after [Answer]: tag below)

[Answer]:A

## Question 6
コピー履歴からのペースト操作はどのように行いますか？

A) メニューバーのドロップダウンから履歴項目をクリックすると、クリップボードにセットされる
B) メニューバーのドロップダウンから履歴項目をクリックすると、アクティブなアプリに直接ペーストされる
C) キーボードショートカットで履歴ウィンドウを表示し、選択してペースト
D) X) Other (please describe after [Answer]: tag below)

[Answer]:A

## Question 7
「書式を省いた純粋なテキスト」の処理について、Activate時の動作はどれが正しいですか？

A) コピー時にリッチテキストからプレーンテキストに変換して保存
B) ペースト時にプレーンテキストとして貼り付け（クリップボード上はリッチテキストのまま）
C) コピー時にクリップボードの内容をプレーンテキストに即座に書き換え
D) X) Other (please describe after [Answer]: tag below)

[Answer]:A

## Question 8
ログイン時の自動起動機能は必要ですか？

A) はい、ログイン時に自動起動する機能を含める
B) いいえ、手動起動のみ
C) 設定で切り替え可能にする
D) X) Other (please describe after [Answer]: tag below)

[Answer]:A
