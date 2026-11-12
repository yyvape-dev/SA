# リリィ操作パネルの既存UI/UXへの統一

ユーザーがiPhone16で基本動作を確認した903版について、リリィの操作パネルだけ既存戦闘UI/UXへ合わせるよう依頼。TDのT2/T3だけ修正する。既存touch_ui.gdのPad描画・タッチ判定・スティックを継承し、仮の長方形攻撃/回避ボタンを非表示化した。

既存の攻撃・回避/防御・移動のみを元の円形UIで扱う。ラナ専用スキル/必殺技のリリィへの追加はしない。T2Manual/scene/host、T3戦闘ロジック/保存/既存TouchUIの変更なし。T3はDriverへ接続してfloor/遮断境界のガード判定を維持する。GUIDEは右上イベント領域へ移し、攻撃/回避・左スティックとの干渉を避けた。

`sa2_td_lily_controls.gd`のTD-only coordinatorが元rawtouchを止めてPadに一本化し、毎frame所有権を確認する。敗北/結果/再挑戦/探索復帰で入力とノードを解放し元状態を復元する。独立レビューMedium（focus loss入力残留）はnative REDで再現し、フォーカス/アプリpause時のtransient解放でGREENにした。所有権は切替えず移動/押下状態だけを消す。

事前レビューC0/H0、コードレビューC0/H0/M1。原文はlily-ui-design-review.md、lily-ui-code-review.md。修正後はauthorが検証し、独立再レビューとは主張しない。

native実Godotテスト60項目PASS: 元720サイズgeometry、半高Pad geometry、multitouch、実攻撃/回避、focus-out、20敗北/再挑戦の所有ノード非増殖、T3 Driver単独physics、境界越しguard拒否、探索Pad復元。Web/公開版の結果は検証後に追記。旧903版URLは残し、更新版UIの実機受入は別確認とする。

## 修正後のauthor検証

候補 `1bd34b84811cc255a98bb4b268e4525005d834c6`、Godot4.7.2、clean export。native60項目と旧24シナリオがPASS。候補CI https://github.com/yyvape-dev/SA/actions/runs/42567396614 もPASS（native/UI/回帰/Web出力）。Web実画面はmedia/lily-ui/。攻撃/回避の円と左スティックは既存Padの描画そのままで、長方形操作ボタンは表示しない。新規美術なし。

ローカルWebのT0/T2/T3試験PASS: T2 attacks1/dodges1、左ドラッグとrelease、DOM blurイベント後move_vectorゼロ、T3 touch開始とGUIDE→実避難movingを確認。20再挑戦はnative実体で所有ノード非増殖。T3のガードはDriver経由で、遮断境界越しのguardは成立しない。

focusの検証範囲: native通知による解放はRED→GREEN。Webはheadlessタブ操作ではblur/visibilityが発生しないことをtraceで確認したため、その操作を実際のapp切替検証とは扱わない。DOM blurを明示配送し、実JavaScriptBridge callback経由の解放を確認。実iPhoneのapp切替/新UI受入はユーザー確認待ち。実機再検証済みとは記載しない。

独立コードレビューMedium1件の対処はauthorが確認。独立再レビュー未実施。既存戦闘/Manual/保存schemaとtouch_ui.gdは無変更。UI復帰以外の能力・戦闘規則を追加しない。

## 公開後の検証

更新版 https://yyvape-dev.github.io/SA2-TD/?v=1bd34b8 、runtime source1bd34b8。公開run42567816201 PASS。実公開全spotのブラウザ試験PASS、更新版の全ファイルと実manifest一致、旧903の全ファイルは元bytes/SHA256のまま。公開スクリーンショットをmedia/lily-ui/に保存。native試験をT3の20再挑戦（GUIDE parent/signal/所有node数）まで追加し100項目PASS。候補CI42567396614は旧60項目harness＋24回帰でPASS、100項目は拡張後のlocal実行と区別。新UI実機受入はユーザー再確認待ち。
