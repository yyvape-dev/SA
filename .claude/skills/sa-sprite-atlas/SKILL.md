---
name: sa-sprite-atlas
description: 領地ゲーム（SA）のアクション戦闘で、ラナのコマ（sprites/<技>_NN.png）を足す・差し替えるとき。動画からスプライトにしたあと、余白を切り詰めた技ごとのアトラス（可逆 WebP）に詰め直し、無劣化を確かめてゲームに組み込む。
---

# コマをアトラスに詰めて組み込む（ラナ）

## なぜ
- 1コマ＝1枚の PNG は、表示のために展開すると 1画素4バイト。周りの透明な余白もメモリを食う（2026-11-01 実測：240コマで 360MB）。
- アトラス（余白を切り詰めて大きな絵に詰める）にすると 143MB、ダウンロードも 24MB → 12MB、ファイル数 240 → 15。画素はそのまま（無劣化）。
- PixiJS 版では、アトラスを起動時に GPU へ送っておく（`PX.prewarm`）。初めて出す技でも引っかからない。

## 1. コマを置く
- 動画から抜く・背景を抜く・足元をそろえるのは、Skill `video-to-sprite-pipeline` の手順で。
- 出来たコマを `sprites/<技>_<2桁の番号>.png`（透過 PNG）に置く。例 `sprites/spin_00.png`〜。
- `sprites/*.png` は消さない（領地の画面 terrain/story.js・morning.js・main.js が立ち絵に使う。アトラスが読めないときの予備にもなる）。

## 2. 詰める（約30秒）
```bash
python3 battle/tools/atlas_build.py sprites sprites/atlas/rana --check
```
- 出力：`sprites/atlas/rana_<技>_<n>.webp`（技ごと、最大 2048 角）と `sprites/atlas/rana.json`。
- `--check`：全コマを元に戻して元の PNG と1画素ずつ比べる。「全コマ一致」以外なら組み込まない。
- 2048 より大きいコマがあると止まる → `--page 4096`（古いスマホは 4096 まで。それ以上にしない）。

## 3. ゲームに組み込む
- `battle/core.js`：`ATL_V` を1つ上げる（ブラウザの古い絵を使わせない）。
- 新しい技なら `M.clips` にコマ数、足元の基準（`XXX_A = { ax, ay, k }`、元のコマでの座標。アトラスでも同じ値）を足し、`battle/draw.js` の `drawHero` で名前を選ぶ。
- index.html の、変えた js の `?v=` を上げる。

## 4. 確かめる
- 位置のずれ：Canvas 版（`?px=0`）で、全コマを「アトラス」と「元の PNG」で同じ所に描いて比べる。`node battle/tools/atlas_check.js`（画面に出る色の差が最大 2/255 以下、位置のずれ 0 なら合格。ほぼ透明な画素の色は丸めで違うのが正常）。
- 動き：Skill `sa-battle-fx-check` の `FX_PLAY=1` で遊ばせて、撮った絵で技のコマを見る。
- 終わったら CLAUDE.md の手順（引き継ぎ → push → Pages の build が success → 試す URL）。

## まだ
- 仲間・敵は、もともと1枚のシート（duel_meta・side_meta）なので、この道具では詰め直していない。仲間のコマを大きく増やすときは、drawAlly をアトラスに対応させてから。
- さらに減らすなら GPU の圧縮形式（KTX2）。画質がわずかに落ちるので、コマを10倍以上にすると決めたときに。
