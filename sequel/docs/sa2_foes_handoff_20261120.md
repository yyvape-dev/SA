# SA2 敵 第1弾（9体）の組み込み — 2026-11-20

## 入れたもの（事実）
- 連番：`art/enemies/README.md` の手順で再現。出た `frames/measure.json` は同梱の `measure.json` と完全に一致。
- アトラス：`tools/make_enemies.py` → `assets/foe2/foe2.json`＋`<敵>_<n>.webp`（可逆、4096 のページ、計 63.2MB）。Godot の取り込みは非可逆 0.95（敵の攻撃と同じ前例）。歩き 12fps・攻撃 8fps に間引き。
- `make_foes.py` との関係：別ファイル（foe.json＝前作の一般兵・g1、foe2.json＝今回）。battle.gd が両方を読み、kind＝敵の名前で引く。make_foes.py を流し直しても消えない。
- Web：地区 pck `en1`（`tools/export_web.py`）。`?mode=foes` の部屋に入るときだけ読む。本体は増えない。
- 敵の登録：`enemy.gd` の `HEIGHT`（背）と `FOE2`（体力・攻撃の倍率、回復）。**値はすべて仮**。
- 届く距離：当たりのコマで前へ出た分＋0.3m（一般兵の 1.45m 未満にはしない）。当たりのコマ＝攻撃の中で前へいちばん出たコマ（仮）。
- 整備兵の攻撃1＝回復（ユーザー指定）：4m 以内の敵（自分も）の体力を最大の 25％戻す。赤い床の予兆は出さない。ラナには当たらない（仮）。
- 被弾：動画が無いので、今は前と同じ「歩きの1コマ目で後ろへ滑る＋白光り」。
- テスト部屋：`sa2_t5_training_preview` に `?mode=foes`（ラナの戦闘テストの部屋を使い回し、9体を左4・右5に並べる。標的／実戦の切り替え・リセットあり）。
- テスト：`tests/sa2_foes_room_test.gd`（9体が出る・両方の攻撃が最後まで流れる・回復で体力が戻りラナは被弾しない・リセット）PASS。`sa2_t6_rana_test_room_test` も PASS。`FOES_CAPTURE=<フォルダ>` で撮影。
- 画像：`docs/sa2_foes_img/foes_grid.jpg`（名前｜歩き｜攻撃1｜攻撃2）、`trail_*.jpg`（焼き込みの軌跡、8fps のコマに番号）。

## 2回目（2026-11-20 ユーザーの答え）
- 軌跡：ランサーの攻撃2だけ消した（`make_enemies.py` の `FX_BOX`。枠の中の明るいピンク〜黄緑だけを消し、槍は残す）。義足の襲撃者は残す。`ONLY=<敵>` でその敵だけ作り直せる。
- テーマ：雑魚2＋ボス1。ボス候補＝ハンマーアーム・四脚の番兵（割り当ては未決）。
- 体力・攻撃力：今の値で可。
- 被弾：B（絵を傾けて揺らす。`enemy.gd` の `_hurt_pose`）。撮影 `docs/sa2_foes_img/foes_hurt.jpg`。
- 設定資料：[sa2_enemies_settings.md](sa2_enemies_settings.md)、身長の並び `docs/sa2_foes_img/height_lineup.jpg`。
- Web の試し版：`previews/sa2-foes/?mode=foes`。

## 未決（ユーザー判定待ち）
- 焼き込みの軌跡を消すか：ランサー攻撃2 のコマ 10〜14（ピンクの弧、12〜13 は緑の土煙も）、義足の襲撃者 攻撃1 コマ 6・攻撃2 コマ 9（光の筋）。
- テーマの割り当て・ボス、体力・攻撃力、背の高さ、被弾の見せ方。
- 本番（ダンジョン）の出現にはまだ入れていない。Web 書き出し・Pages 反映は未実施。
