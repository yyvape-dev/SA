# SA2 ランカ導入の引き継ぎ（2026-11-12、Claude）— GPT／Codex 向け

## 開始条件
- GitHub `yyvape-dev/SA`、対象 `sequel/`、Godot 4.7.2。
- 作業ブランチ：`feat/sa2-ranka-20261112`（T6 先頭 `3f7c168`〈test/sa2-t6-lily-touch-controls-20261111〉から切った）。**main は変更していない**（T7 引き継ぎの決まりどおり）。
- 先に読む：`CLAUDE.md` → `sequel/HANDOFF.md` 先頭 → 本資料 → `docs/sa2_t7_handoff_20261111.md`。

## ユーザーの決定（2026-11-12 チャット。ユーザーの言葉を要約）
- ランカは **リリィと同時参戦（ラナ＋リリィ＋ランカの3人）**。仲間としてのオート稼働と、特定イベントで主人公格として自分で操作する、の2つを入れる。
- 通常攻撃：三連撃の動画（突き→上段→回し蹴り）を分けた 3 本を順に。（最初は「掌底」を足した 4 種だったが、09:59 ユーザー指摘で掌底の動画は「くらい」と判明 → 被弾の clip `hit` に回した）
- 09:59 ユーザー指摘：歩きと、スティックを強く倒したときの走りを分ける（手動操作は回避中しか走らなかった）。天照の決めの絵がくらいに見える → 差し替え（星震の動画の腕の交差→雷）。
- スキル：
  - 技1 **指弾**（指さしの動画）＝指先から気弾を遠くへ。
  - 技2 **円環**（小瓶を飲むように見える動画。ユーザー「指を顔の前に構えるポーズ」）＝**自分を中心にした大きな円環の連続範囲攻撃**。
  - 技3 **星震**（頭に蒼い雷をまとい腕を交差する動画）＝**画面広範囲への SA1 の星震**。
  - 必殺技 **天照**＝**画面全範囲の激しい光と振動、花びらのエフェクトが舞う連続攻撃**。
- 色：**青・白・朱色の花・金**。
- 会話用の立ち絵動画も入れる。

## 未決（ユーザー判定待ち。勝手に決めない）
1. ランカの背の高さ：仮 **1.93m**（前作の比 ranka 214.12 ÷ rana 205 × 1.85m）。`tools/make_ranka.py` の `HEIGHT_M`。
2. 1発の強さ `RDMG`＝13（リリィ 11）、技の待ち（指弾 8・円環 12・星震 22 秒）、天照の倍率（8回×1.0＋決め 9.0）は仮。
3. ストーリー上の合流時期（物語の資料では中盤以降）。今は本編（main.tscn・ダンジョン）で最初から3人。`?ranka=0` で外せる。
4. 技名は画面に出さない（従来の決まり）。コードと資料の中の呼び名。

## 入れたもの
### 素材（`tools/make_ranka.py`、`RANKA_STAGE=cut|pack|idle|cutin`）
- 元：`art/ranka/src/*.mp4`（8本、マゼンタ背景、24fps）。atk_palm・atk_combo・skill_point・skill_ring・skill_thunder・walk・run・event_idle。
- `assets/ranka/ranka_0〜1.webp`（可逆、計 22MB、地区 pck **al2**）・`ranka.json`・`cutin.webp`（会話の立ち絵の1コマ目、縮めない）。
- clip：idle・walk(27)・run(31)・hit（くらい 13 コマ。元 `src/hit.mp4` の胸の閃光と破片のコマは飛ばした）・atk_c1／c2／c3（三連撃を切り分け）・atk_back（c1 の出だしを逆に＝構えへの戻り）・skill_point／ring／thunder（8fps に間引き）。
- atk_combo の焼き込みの黄〜橙の閃光・弧・ピンクのぶれは、コマごとの枠（`FX_BOX`）の中だけ消した（比較：`docs/sa2_ranka_img/combo_baked_removed.jpg`）。**残り**：足の一部にピンクのぶれ（動きのぶれとして残した）。
- 会話用の立ち絵：`assets/event_idle/ranka_idle.webp`（**9×8＝72 コマ・12fps＝6秒**。リリィ・ラナは 6×6・3秒。6秒の動画が最初と最後でほぼ同じなので丸ごと使った）。
- HUD の顔：`assets/ui/t6/t6_ranka_portrait.png`（`tools/make_ranka_ui.py`）。
- 日本語フォント `sa2_t6_ja.otf` に9字を追加（`tools/extend_ja_font.py`、Noto Sans CJK JP、OFL）。

### コード
- `scripts/ally.gd`（リリィ）：仲間ごとに変える所を変数に（`asset_dir`・`ult_key`・`follow_ofs`・`actor_id`・`display_name`）。フック `_after_atk`・`manual_next`・`slot_ids`・`fresh_cd`。**リリィの値・動きは従来どおり**（全テスト通過）。
- `scripts/ranka_ally.gd`（ally.gd を継承）：通常攻撃（自動は c1→c2→c3 と続け、途切れたら atk_back、掌底と交互／手動は押すたび c1→c2→c3→掌底、0.9 秒空いたら c1 から）、スキル選び、天照。
- `scripts/ranka_skills.gd`：技の表（形は lily_skills.gd と同じ）。shape `"screen"`＝ランカから左右 9.5m の敵すべて。
- `scripts/ranka_fx.gd`：花びら（コードで作る絵）・気弾・円環・星の雨・夜空の星・光の柱。リリィの稲妻（白銀＋蒼）とは別の見た目。
- `scripts/battle.gd`：`ranka`・`ranka_ult`・`ranka_ult_gain`、`ally_list()`（自動の仲間）、`ult_busy(who)`（必殺技の重なり防止。ラナ・リリィ・ランカ共通）。ゲージは仲間ごと（`ult_key`）。当たりの色 `hit_pal`。
- `scripts/enemy.gd`：敵の攻撃が仲間2人に当たる。ランカも hit で被弾する。
- `scripts/main.gd`：`_load_ranka()`（リリィの後、待たない）。`ranka_wanted()`：`?ranka=0`／`RANKA=0` で出さない、撮影の起動（CAPTURE_*）は `RANKA=1` のときだけ。カットイン `ranka_cutin`（藍の帯・朱の線）。
- `scripts/sa2_t2_lily_manual.gd`：スティック 0.9 超か Shift で走り（6.2m/秒、ラナと同じ）。リリィの手動操作にも効く。手動操作をキャラ共通に（通常攻撃の順は `actor.manual_next`、ゲージは `actor.ult_key`、待ちは `actor.fresh_cd()`）。
- `scripts/touch_ui.gd`・`t6_hud_art.gd`・`skill_icons.gd`：手動中の3枠・ゲージ・顔・名前をキャラに合わせる。ランカの技アイコンは**コードの図形（仮）**。ラナの HUD にランカのゲージ（リリィの下）。
- `scripts/sa2_t2_playable.gd`：**ランカの操作の入口** `?mode=ranka`（`SA2_RANKA_TEST`／`ranka_test_room`）。標的3体（600）、標的／実戦、全部リセット、**リリィ同行**（自動の仲間を一緒に出す）、**会話の立ち絵**（その場で立ち絵ループに切り替え）。撃破で経験値は増えない。天照のゲージは2段で開始。会話の立ち絵は `_event_idle_sprite(actor_id)`（`EVENT_IDLE` の表）で、今後の会話イベントでも使える。
- `tools/export_web.py`：地区 `al2`、`art/ranka/*` を本体から除外。

## エフェクトの方式（2026-11-12 10:25 ユーザー決定「SA1 と同じ方式でやってみよう」）
- 外部AI（GPT）の白黒の素材（黒地・白黒・中に濃淡）に、コードで色の帯・侵食・ノイズ・大きさの曲線を付ける。SA2 には前からこの描き方がある（`scripts/tex_fx.gdshader`、`fx.gd` の `tex_quad`）ので、新しいシェーダーは作っていない。
- 素材：元 `art/vfx_src/ranka/`（ring・pillar・flare・ki_band・petals・burst〈GPT、2026-11-12〉、band_blade・band_ink・band_smash〈SA1 の物〉）→ `tools/make_vfx_tex.py` → `assets/vfx/ranka/`（RGBA、RGB＝明るさ、A＝形。花びらは 4×2 のシート）。
- `fx.gd`：`tex_quad` に `aspect`（横÷縦）・`grow_x`・`ang`、戻り値（板）、`res://` の名前、色の帯 `ranka`・`vermilion`。既存の呼び出しは変わらない。
- 使い所（`ranka_fx.gd`・`ranka_ally.gd`）：当たり＝flare（強い当たりは burst も）、突き・指弾＝ki_band、蹴り＝band_blade、円環・着弾＝ring（床）、星震の柱・円環の締め・天照の決め＝pillar、星震の締め・天照の決め＝burst、天照の連撃＝band_ink、花びら＝petals。
- 比較：`docs/sa2_ranka_img/vfx_tex_before_after.jpg`（左＝前、右＝今）。iPhone での見え方は未確認。

## 確認（事実）
- Godot 4.7.2 で既存の全テスト（21本）＋新しい `tests/sa2_t7_ranka_test.gd` が通過（`sa2_world_failure_test` は出力に "FAILURE" の語を含むが結果は PASS）。
- 新テストの内容：入口・操作の担当・3枠・ゲージ2段、連撃の順 c1→c2→c3→掌底、単発の c1 から戻り→構え、3スキルとも敵に当たり待ちが入る、天照で画面の敵すべてに当たりゲージ 100 消費・演出の後に cine とカメラが戻る、リリィ同行で自動のリリィが戦う、会話の立ち絵の切り替え、経験値が増えない。
- 実描画（xvfb・1280×720・OpenGL 互換）：`RANKA_CAPTURE=<フォルダ>` で要所を PNG に。並べた画像は `docs/sa2_ranka_img/`。
- 本編の自動の4周（`DUNGEON_TEST=1`、3人）：全部クリア・抜け道なし。ノーマル 83.1・42.9・48.5 秒／被弾 3・2・2、ハード 63.0 秒／4。ランカの技 指弾 16・星震 7・円環 4・天照 2。リリィの技も従来どおり出る。

## 配信（2026-11-12 09:38 ユーザー決定：B に変更）
- 試し版を main の `previews/sa2-ranka/` に置いた（本編 `sequel/web/` は触っていない）。起動シーンを `sa2_t5_training_preview.tscn` に差し替えて `export_web.py`（WEB_OUT=web_ranka）で書き出したもの。project.godot の差し替えはコミットしていない。
- URL：https://yyvape-dev.github.io/SA/previews/sa2-ranka/?mode=ranka （?mode=lily・?mode=rana も同じ版）。Pages の反映は success。手元の gzip 配信＋chromium（844×390）でランカの入口の起動・読み込み（ranka_loaded 約36秒、swiftshader）を確認。Pages そのものはこの作業環境から開けず未確認。
- 3人同時の本編（main.tscn）の試し版は出していない。

## 未確認・残り
- **Web 書き出し・iPhone 実機は未実施**（この作業では書き出しテンプレートを入れていない）。配信するときは `python3 -I sequel/tools/export_web.py` で al2 が出来るか、起動時のメモリ（ランカの絵 GPU 約 2 ページ分＝4096² 2枚）を確認。T6 で iPhone Safari の起動クラッシュの原因が未特定なので、3人同時の本編は特に重さに注意（仮説：メモリ）。
- 星震の「夜空へ暗転」：`battle.big_moment` の背景の暗さは、今の T6 の裏町の背景では目に見えて暗くならなかった（撮影で確認。原因は未調査）。
- ダウン（倒れる）の動画は無い。
- 技アイコン・エフェクトの見た目はユーザーの判定前。T6 の決まり「VFX の追加作業は勝手に横展開しない」に従い、ランカ以外の技は触っていない。
