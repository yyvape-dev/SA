# 続編（SA2・融合都市）引き継ぎ

## 現在地（2026-11-05）
- 前作SAは完成。続編＝横スクロール＋奥行きの帯の2.5Dアクション。街も横スクロールで歩き、ストーリーを挟みつつ、アクションで装備・スキルを掘る。柱＝アクション操作と派手なエフェクト（モーションは増やしにくいので、スキルの幅はエフェクト・移動距離で出す）。
- 決定（ユーザー）：主人公＝ラナ（絵は描き直す予定。今は前作の連番を仮置き）。舞台＝ネオン街とスチームパンクが融合した近未来都市。iPhone は横持ち。Godot 4.4.1、Web 書き出し（スレッド無し）。実装は Claude。
- 縦切り1：下町の大通り1区画（`scripts/city_block1.gd`）。歩き・走り（スティックを倒しきる／Shift）・攻撃2種（J／Z）・回避（K／X）。左半分のタッチでスティック、右下に攻撃・回避。敵はまだ無い。
- 遊べるURL：https://yyvape-dev.github.io/SA/sequel/web/

## 絵の方式（決定。ユーザー承認）：下絵を塗ってもらい、箱に投影する
- AIに「前景だけ」「層ごと」を描き分けさせない（GPTの試作で失敗）。代わりに：
  1. Godot で街を箱（グレーボックス）で組む。部品（piece）＝1件の絵。
  2. `CAPTURE_GUIDE=1` で起動すると、部品ごとに「ゲームと同じ位置のカメラで、その部品だけ、背景マゼンタ」の下絵と、そのカメラの行列（`art/guide/guide.json`）を書き出す。全体の `key_full.png` は画風を決める1枚。
  3. GPT に下絵を添付して「形を変えずに上から塗る」（発注票：https://claude.ai/artifact/PUQA2u7Xmp5NVWiXQaBvzD 、生成は `tools/make_order.py`）。
  4. `python3 -I sequel/tools/import_paint.py <絵> <id>`：大きさをそろえ、形のずれを探して直し、IoU を出す（0.93未満は作り直し）。`art/painted/<id>.png` へ。
  5. ゲームは、絵があれば `proj_paint.gdshader` で下絵のカメラから箱へ投影する（マットペイント方式）。無ければ箱の仮の色。カメラが左右に動くと奥行きどおりに視差が出る。
- 事実：投影のずれは、試しの縞模様で確認済み（箱の辺と一致）。カメラが部品の中心から離れると、箱の側面の絵が伸びる（仮説：画面の端の範囲なら目立たない。実際の絵で確認する）。
- 地面はコード（前作の教訓）。部品の箱や位置を変えたら、下絵を撮り直し、その部品は塗り直しになる。

## 操作・数値
- カメラ：主人公から (0, 3.8, 13.5)、注視 y2.1、fov 36、左右 −12〜12。部屋 x −19〜19、帯 z −3.2〜3.5。
- ラナ：背の高さ 1.85m（待機の366px）。`assets/rana/rana.json`＝前作のアトラスを足元基準に変換（idle・walk・run・atc・atb）。

## 確認の手順
- 撮影：`cd sequel && CAPTURE_PLAY=1 LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1280x720x24' godot --path . --rendering-driver opengl3 --windowed --resolution 1280x720` → `captures/`（git 管理外）。
- 書き出し：`godot --headless --path sequel --export-release "Web" web/index.html`（テンプレートは 4.4.1 の web_nothreads）。index.wasm は版が同じなら毎回同じ中身。
- ブラウザ：web/ を http で配信し、playwright（swiftshader）で 844×390 を撮る。

## 次の候補
1. 発注票の9件が届いたら取り込み → 実機で見え方。
2. 敵（群れ）と当たり・ヒットストップ・エフェクト（スキルの幅をエフェクトと移動距離で）。
3. 日本語フォント（UI の文字）、街の人・扉・区画の切り替え。
4. ラナの新しい絵（元の mp4 から連番。前作の `video-to-sprite-pipeline`）。
