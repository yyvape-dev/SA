---
name: sa-vfx-texture
description: 領地ゲーム（SA）の WebGL エフェクト（terrain/fx_gl.js）に、外部AIの白黒の素材（斬撃の帯・ノイズ）を取り込むとき。発注・変換・組み込み・コマ送りの確認まで。
---

# 外部AIの白黒の素材を WebGL のエフェクトに取り込む

## 0. 発注（まだなら）
- 発注票の型：https://claude.ai/artifact/J7PwVemHUTBcD4qE87bFcs （生成元 `_order_fx/index.html`・コミットしない）。
- 帯：1536×1024・黒地・白黒だけ・縁が柔らかい・**右端＝刃の頭（太い）、左端＝尾（細い）**・帯は縦の中ほど40%に。
- ノイズ：1024×1024・全面を埋める・白黒の幅を目いっぱい。継ぎ目はこちらで消す。

## 1. 置く → 変換（1分）
- 届いた絵を `terrain/tools/fx_src/` に `band_<名前>.png` か `noise_<名前>.png` で置く（グレースケールに直して保存してよい）。
- `python3 terrain/tools/fx_tex_build.py` → `terrain/assets/fx/`
  - 帯：切り詰めて 1024×256。R＝形の濃さ、G＝消える順番（芯ほど大きい＝後まで残る）。
  - ノイズ：512×512、半分ずらして混ぜ、継ぎ目なし。
- 見る：帯3本＋ノイズを2×2に並べた1枚を作って Read（継ぎ目・切れ・白飛び）。

## 2. 組み込み（terrain/fx_gl.js）
- 帯の種類は `shapes`（今は ink・blade・smash）。新しい帯は `for (const k of [...])` に名前を足す。
- 使い分けは `GLFX.slash({ tex })`。main.js の `strikeFX`：cleave＝smash、kick＝blade、ほか＝ink。
- 形の絵は CLAMP（繰り返さない）。流すのはすじのノイズ（uFiber）だけ。侵食は尾から先へ（`.72 + .28 * vUv.x`）。
- 素材を作り直したら `TEXV` を上げる。fx_gl.js を変えたら main.js の `fx_gl.js?v=` と index.html の `main.js?v=` を上げる。

## 3. コマ送りで確かめる（一騎打ちの撮影は 1.5 秒おきで、弧は写らない）
- 試し場 `terrain/_glbench2.html`（コミットしない）：3種を並べて `go()`。`window.SP=.05` で20倍遅くする。
- `python3 -m http.server 8765`（terrain で）→ playwright で `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`、ゲーム内 100/200/300/420/540ms（実時間は×20）で撮って縦に並べる。
- 見る所：刃が走る（100）→ 残る（200）→ 欠けて縁が燃える（300〜420）→ 消える（540）。細すぎ・すぐ消える・四角い端が見える、が無いこと。
- 最後に `sa-duel-check` で一騎打ちのエラーが無いことを確認。実機は未確認と書く。
