---
name: sa-map-check
description: 領地ゲーム（SA の terrain/）の領地マップを、発展度（0〜5）ごとに同じ視点で撮って並べ、確かめるとき。森の後退・道の舗装・街の小物・民家・住民など、マップの見た目を直したあと、push の前に使う。
---

# 領地マップを発展度ごとに撮って確かめる

## 0. 準備
- リポジトリのルートで静的サーバー：`python3 -m http.server 8123 >/dev/null 2>&1 &`（もう動いていれば不要。`curl -s -o /dev/null -w "%{http_code}" localhost:8123/terrain/`）。
- 構文チェック：`cd terrain && node --input-type=module --check < main.js`。

## 1. 撮る（1枚 約1分。Bash の timeout は 600000）
```bash
node terrain/tools/map_shot.js <発展度,…> <出力フォルダ> [拡大 x y]
```
- 例：`node terrain/tools/map_shot.js 0,3,5 /tmp/mapc`（本拠の街の全体）
- 寄り：`node terrain/tools/map_shot.js 1,2,5 /tmp/mapz 1.8 560 980`（広場の右。x,y は基準画像の画素。広場の中心は本拠 470,1000、以後 x+930 ずつ）。
- 中身：URL の `?dev=N` で全区域の発展度を固定（会話も出ない）。出力は `devN.png` と横に並べた `sheet.png`。標準出力に各ページの発展度とエラー。404 の `stump.png`（外部AIの切り株が届くまで）と `por_*_4.png` は既知。
- 保存から計算した発展度を確かめるとき：`__t.build(区画, 施設, 段階)` → `__t.dev()`（広場ごとの配列、0＝本拠）。

## 2. 見る（Read で sheet.png → 寄りの devN.png）
- 森：段階ごとに広場から輪が広がるように退いているか。境目の内側に切り株が残るか（城下町＝5 では消える）。
- 道：土 → 砂利（2〜）→ 石畳（3〜）。石畳の色が広場の石畳と揃っているか（白すぎ・れんが壁っぽさに注意）。
- 小物：0＝井戸だけ（土の広場）／1＝屋台・樽・干し草・荷車・たいまつ／2＝広場の石畳・ベンチ・柵・低木の並木／3＝噴水・街灯・花壇・小さな松の並木（たいまつは消える）／4＝遠い角の街灯。
- 大きさ：井戸や小物が区画と比べて大きすぎないか。

## 3. 数値の場所（terrain/main.js）
- `DEV_R`（切り開く半径）、`DEV_TH`（点数のしきい値）、`devOf`（点の数え方）、`lvd(mesh, 広場, 出る段階, 消える段階)`（小物）、地面のシェーダーの「道の格上げ」（砂利 gR・石畳 sR の半径、石の色 stC）。

## 4. 終わったら
- 結果を一言で。実機は未確認と明記し、試す URL（`https://yyvape-dev.github.io/SA/terrain/?dev=0`〜`5`）を添える。
