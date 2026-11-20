# 敵キャラ 第1弾（9体）— Claude Code への引き継ぎ

置き場所：`sequel/art/enemies/`（このフォルダで `SRC=src KEYED=_work/keyed python3 tools/key.py && KEYED=_work/keyed OUT=frames python3 tools/build.py` を実行）。既存の `sequel/tools/make_foes.py` との関係は、組み込み時に確認すること。

チャット側で、緑背景の抜き・ループの切り出し・大きさの統一・足元の位置合わせまで確認済み。
確認用の画像：`enemies_sheet.png`（赤線＝足元）。測った値：`measure.json`。

## 中身
- `src/` … 動画AIの元動画（緑背景、24fps）。名前は `<敵>_<動き>.mp4`
- `tools/key.py` … 緑抜き（緑っぽさで透明度を決める → 縁の色を最寄りの不透明な画素の色に置き換え → 緑かぶりを除去 → 小さなゴミを除去）
- `tools/build.py` … 歩きのループ周期を検出、大きさを歩きにそろえる、足元を基準に共通の枠へ書き出す（歩き1コマ目の全高＝400px）
- 再現：`SRC=src KEYED=_work/keyed python3 tools/key.py && KEYED=_work/keyed OUT=frames python3 tools/build.py`（必要なもの：numpy, scipy, opencv-python, pillow）

## 敵と動き
| 敵 | walk | atk1 | atk2 |
|---|---|---|---|
| hammer_arm（ハンマーアーム） | 60コマのループ | 97 | 97 |
| hover_sentry（ホバー型の番兵。浮いている） | 41 | 73 | 97 |
| maintenance_soldier（整備兵） | 26 | **73＝敵の回復**（ユーザー指定） | 73 |
| mechanical_lancer（機械ランサー） | 23 | 73 | 97 |
| mechanical_spine_dancer（脊椎の踊り子） | 36 | 97 | 97 |
| prosthetic_arm_bouncer（義手の用心棒） | 48 | 73 | 97 |
| prosthetic_leg_raider（義足の襲撃者） | 45 | 73 | 73 |
| quadruped_sentry（四脚の番兵） | 50 | 97 | **無し** |
| steam_shield（蒸気の盾兵） | 36 | 73 | 97 |

## 事実として分かっていること（注意点）
- quadruped_sentry の atk1 は、2本届いたがまったく同じファイルだった（md5 が一致）。atk2 は無い
- 画面の端で見切れているコマがある：spine_dancer の atk1 で 26コマ、leg_raider の atk2 で 7コマ。方針どおり、とりあえずそのまま使う
- 動画に焼き込まれた軌跡がある：lancer の atk2 にピンクの弧、leg_raider の蹴りに光の筋。sa2-ally-add の手順（コマごとの枠 FX_BOX の中だけ消す）で消すかどうかは、並べた画像をユーザーに見せて判断してもらう
- 大きさの合わせ方：歩きの1コマ目の上部を型にして照合した（照合の一致度 0.88〜0.94）。ハンマーアームの攻撃は照合が不安定だったので 1.0 に固定、盾兵は頭だけで照合して 1.02（measure.json で match=-1 になっているのが、手で決めた値）
- 足元：各クリップの1コマ目の足裏とその中央を基準にしている。攻撃中の踏み込み（前に出る動き）は残してある。ホバー型は足が無いので、下の針の先を足元にしている
- 攻撃は24fpsの全コマを書き出してある。アトラスの規格（4096のページ、技は8fpsに間引く）は sa2-ally-add に合わせる

## ユーザーにまだ聞いていないこと（勝手に決めない）
- どのテーマの敵にするか（テーマごとに雑魚2＋ボス1）、ボスにするかどうか
- 体力・攻撃力・ゲーム内での背の高さ（背は、身長の確認資料を作ってまとめて決める方針。数値は表で決めてからコードに入れる方針）
- 被弾の動画が無い（このままだと、被弾の見せ方をどうするか決める必要がある）
