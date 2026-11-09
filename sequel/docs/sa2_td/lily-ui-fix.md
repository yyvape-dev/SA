# リリィ操作パネルの既存UI/UXへの統一

ユーザーがiPhone16で基本動作を確認した903版について、リリィの操作パネルだけ既存戦闘UI/UXへ合わせるよう依頼。TDのT2/T3だけ修正する。既存touch_ui.gdのPad描画・タッチ判定・スティックを継承し、仮の長方形攻撃/回避ボタンを非表示化した。

既存の攻撃・回避/防御・移動のみを元の円形UIで扱う。ラナ専用スキル/必殺技のリリィへの追加はしない。T2Manual/scene/host、T3戦闘ロジック/保存/既存TouchUIの変更なし。T3はDriverへ接続してfloor/遮断境界のガード判定を維持する。GUIDEは右上イベント領域へ移し、攻撃/回避・左スティックとの干渉を避けた。

`sa2_td_lily_controls.gd`のTD-only coordinatorが元rawtouchを止めてPadに一本化し、毎frame所有権を確認する。敗北/結果/再挑戦/探索復帰で入力とノードを解放し元状態を復元する。独立レビューMedium（focus loss入力残留）はnative REDで再現し、フォーカス/アプリpause時のtransient解放でGREENにした。所有権は切替えず移動/押下状態だけを消す。

事前レビューC0/H0、コードレビューC0/H0/M1。原文はlily-ui-design-review.md、lily-ui-code-review.md。修正後はauthorが検証し、独立再レビューとは主張しない。

native実Godotテスト60項目PASS: 元720サイズgeometry、半高Pad geometry、multitouch、実攻撃/回避、focus-out、20敗北/再挑戦の所有ノード非増殖、T3 Driver単独physics、境界越しguard拒否、探索Pad復元。Web/公開版の結果は検証後に追記。旧903版URLは残し、更新版UIの実機受入は別確認とする。
