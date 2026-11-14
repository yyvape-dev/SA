# ダンジョン背景の追加発注（2026-11-15、Claude Code）

## 状況（事実）
- T2・T3・T4 の部品をゲームに組み込んだ（branch `claude/skill-tree-implementation-fsvlcl`）。T3 は改訂版 `_r2`（b1〜b4・f1）を採用、T2 の大物は `t2_x1_r2` を採用。T4 は b1〜b4・f1〜f3・back1・far1・g1・x1・x2 をそのまま採用。
- 設計書（`docs/sa2_dungeon_design_T1-T4.md`）の部品一覧に対して、**未着は T3 の大物 `t3_x1` だけ**。
- 組み込み後の判断：T3 の床 `t3_g1` は平均輝度 81（T2 43・T4 40）と明るく、建物より浮いた。コード側で明るさを 0.53 倍にして合わせた（描き直しは不要）。

## 発注：`t3_x1` 浮遊瓦礫の残存壁（1 枚）
- 用途：T3 の部屋に 1 部屋最大 1 点、正面の建物の列の中に 1 枚として並ぶ大物（コードは `x1` が届けば自動で使う）。
- 寸法の目安：幅 8m × 高さ 5m（ゲームでは 150px＝1m。T3 の b 部品は約 1620×770px）。足元の線は b1〜b4 とそろえる。
- 参照に直接渡す画像：`art/painted_bt/w_shady.png`・`art/painted_bt/back_alley_1.png`（本番の画風）、`art/incoming/dungeon_20261114/batch09/t3_b1_r2.png`・`batch10/t3_b3_r2.png`（同じテーマの採用版。色と材質をそろえる）。
- 保存先：`sequel/art/incoming/dungeon_20261114/batch11/t3_x1.png`（PNG 原本、再圧縮しない）＋ HANDOFF・manifest・prompts（今までの便と同じ）。保存したら全画素を読めるか確かめる。
- 作るのはこの 1 枚だけ（使わない案を作らない）。

### プロンプト（全文）
```text
Create ONE new standalone game environment asset for T3 ruins near a demonic gate. Match the ACTUAL PRODUCTION reference images' oil-painted broad angular brush strokes, dark shadow grouping, textured black iron, weathered brown wood, grey stone and tarnished copper; match the attached accepted T3 parts in palette and material. Do not make smooth 3D render or flat uniformly lilac stone. Purple supernatural light only in sparse cracks, not a uniform purple wash. Orthographic front elevation, all silhouette within padded canvas. Solid flat #FF00FF background. No people, text, letters, UI, Japanese motifs, floor plane. Landscape canvas about 2:1. ONE large surviving fragment of a ruined townhouse wall, width 8m height 5m: thick broken grey stone wall with a torn iron beam, a hole through the middle, cracked violet fissure near the ground line only. Above the broken top edge, a small cluster of 4-6 stone chunks and one bent iron bar float in the air, held by faint violet threads of light, all within the upper third and clearly above head height. Flat straight foot line at the bottom matching the other front parts. No gate ring, no bridge, no stairs, no lamps, no shop goods. Entire object visible with margin.
```

## 発注しないもの（理由）
- 敵・ボスの設定画：ユーザーが別に用意している（設計書の 6・8・9・10〜12 番が未着）。
- T1 の背景：今の歓楽街の部品を使う方針（作り直さない）。
- 床の継ぎ目（T3・T4 の床は縮小で周期が見える＝ QA の FAIL）：ゲームの画面では目立たないので今は直さない（目立てば後で）。
