---
name: sa-battle-fx-check
description: 領地ゲーム（SA）のアクション戦闘（ルートの index.html と battle/）のエフェクトや描画を直したあと、従来の Canvas 2D 版と PixiJS 版を同じ時刻で止めて撮り、並べて確かめるとき。fx.js・fx2.js・pxr.js・pxfx.js・draw.js を変えたら push の前に使う。
---

# アクション戦闘のエフェクトをヘッドレスで撮って比べる

## 1. 撮る（1回 2〜3分。リポジトリ直下で）
```bash
node battle/tools/fx_shot.js /tmp/fx/gl                 # PixiJS 版（今の既定）
node battle/tools/fx_shot.js /tmp/fx/cv px=0            # 従来の Canvas 2D 版（比べる元）
python3 battle/tools/fx_cmp.py /tmp/fx/cv /tmp/fx/gl /tmp/fx   # → /tmp/fx/cmp_<場面>.png（左＝従来、右＝新しい、上から時刻順）
```
- 場面：arc（太刀2本）・ult（必殺の弧）・lance（突き）・hit（当たり・撃破・輪・吸引）・boss（敵将の撃破・癒し・星・追星・地走り・溜めの輪）・under（拘束の床と帯・強敵の気配・溜め）・star（星震）。しぼるときは3つめの引数に `arc,hit`。
- 2つめの引数は URL に足す引数：`px=0`（全部 Canvas）・`fxgl=0`（弧だけ前の形）。
- `FX_PLAY=1` を付けると、最後に70回ボタンを押して遊び、頂点の最大とエラーを出す。`DPR=2` で2倍の解像度（拡大して質を見るとき）。
- 仕組み：update を空にして時間を止め、`G.fx` に場面を積んで `t` をそろえ、`draw()` を呼んで撮る。敵の並びは乱数なので、左右で敵の数や位置が少し違うのは問題ない。
- 新しいエフェクトを足したら、`fx_shot.js` の `SCENES` に1行足す。
- Bash の timeout は 600000。2本は続けて実行する（並行させると重い）。

## 2. 見る（Read で cmp_*.png）
- 形・色・重ね順が従来と同じか（弧と突きはシェーダーの見た目に変わるのが正しい）。
- 丸い光（放射のグラデーション）が白く大きく出ていないか。線の端・点線・楕円の欠け。
- 足元の層（拘束の床・溜め）がキャラの後ろ、エフェクトがキャラの前にあるか。
- 標準出力：`{"px":true,"fx":true}`（Pixi とエフェクトの層が動いている）、`no errors`、頂点の数（重い場面で 1〜3万／コマが目安）。

## 3. 終わったら
- 結果をユーザーに一言で。ヘッドレスはソフトウェア描画なので、速さは比べられない（実機は未確認と明記）。
- 変えた js の `?v=` を index.html で上げる。CLAUDE.md の手順（引き継ぎに追記 → push → Pages の build が success → 試す URL を送る）。
