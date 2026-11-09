# SA2 T4 新チャット引き継ぎ正本 — 関節アニメーション・遊技機演出・新MAP美術（2026-11-09）

> 本書は2026-11-09の **16m遊技場・独立MAP・微小アニメーション** の現状と次の作業を引き継ぐ。過去の7mカジノ案・宿屋跡への挿入案・縮尺是正時点の未完了判定を上書きする。旧正本は経緯の資料としてのみ使用する。**新チャットは既承認事項の再質問や作業計画の説明で止まらず、T4ブランチでコードと素材を変更し、Godot 4.7.2の実画面・動画まで検証すること。**

## 1. 正確な対象と禁止事項
- Repo: `yyvape-dev/SA`; **唯一の書込対象ブランチ**: `test/sa2-t4-gamehall-relayout-20261109`。
- Godot project: `sequel/`; Godot **4.7.2**, GL Compatibility, カメラ **D2**（16.8° FOV、距離15.3m）、既存テスト画面は1688×780。
- **main、T2、T3、他プロジェクトは変更しない。** 既存街区の構成、決定済みカジノ原画・色・画風・16m縮尺を勝手に変えない。
- ユーザーはキャラクターの顔・服装や原画の塗りを保全したい。キャラや遊技機全体を揺らして「動いた」ことにするのは不合格。動かす関節・内部部品だけを局所的に動かす。元絵を唯一の基準とし、差分生成画像を新しい原本に昇格させない。
- レンダリングの実証はGodot実行・実撮影のみ。ImageGenやPython合成動画はGodot実画面の代用にしない。
- ユーザーがレビューしやすいよう **GIF/動画をチャット内に直接表示**。MP4はチャット埋め込みが壊れた前例がある。**正しく再生できるか未検証なのに再生可能と断定しない。** GIF直表示＋MP4への明示的なリンクを併用し、必要に応じて個別フレームPNGも直接表示。
- 確認質問・不要な計画説明・素材の再提出依頼を繰り返さない。PASS/FAIL/NOT TESTEDと実証を短く記録。

## 2. ユーザーが承認済みの仕様（再確認不要）
- カジノは上方が画面外に見切れる巨大常設施設。**幅16.0m**、既存のGodot取り付け板は高さ10.0m、中心 world X=0（-8〜+8m）、Z=-6.18付近。
- 豪華な紫/金の帝国裏歓楽街遊技場。正面開放、スロット・テーブル・客・ディーラーが見える、強い遠近感を持つ油彩完成画を採用。再生成不要。
- 現在のMAPは既存の裏町から**左方向に移動→ローディング→完全に別のMAP（新フロア）**。元の裏町の道路・建物構成をコピーし、新MAPの中央部分に16mカジノを設置。新MAP右端から旧MAP左端に戻れる。
- 表示用3200×2000pxは採用画像の機械的拡大・クロップであり、AI超解像成功ではない。**高解像度の細部が実際に存在することと混同しない。**

## 3. 現在の実装と重要ファイル
- `sequel/scripts/main.gd`: T4専用の `_t4_check_edge`, `_t4_change_floor`, `_t4_animate_floor`; 左境界 -23.55m、右境界 +23.55m、ローディング経由で再構築。原本の裏町ルートもそのまま残す。
- `sequel/scripts/t4_gamehall_floor.gd`: `build_backtown()` で既存街区の **ベースを新しいLevelとして再生成**し、中央の対象ジオメトリだけ非表示化、幅16mの遊技場と6枚の可動テクスチャを設置。`GAMEHALL_16M_ART_LAYERS`。**独立MAPは成立しているが、街区レイアウトは現段階ではコピーで、周辺の美術完成とは違う。**
- `sequel/tests/t4_gamehall_local_detail.gdshader`: 現在の微小演出。2スロットのリール表示の局所揺れと走査光、ルーレット盤内のみ回転、人物3名の上半身局所UV変形。**このシェーダーは `tests/` 内にあり `t4_gamehall_floor.gd` から本番用に参照しているため、次回本実装品質まで持っていくなら `scripts/` への移管と参照更新・回帰検証を検討する。** 単に移管してPASSにしない。
- `sequel/tools/t4_gamehall_make_motion_layers.py`: 採用原画から元ピクセルをマスクして6可動PNG生成、隠れた下地のみOpenCV Teleaで補完。ここで作った背景は機械的な近似であり、美術完成保証はない。
- `sequel/art/painted_bt/gamehall_motion/`: `background_clean.png`, `left_slot_machine.png`, `right_slot_machine.png`, `roulette_cluster.png`, `cloaked_man.png`, `left_woman.png`, `right_woman.png`, `motion_manifest.json`。全PNGは3200×2000の座標維持型。
- `sequel/art/painted_bt_src/t4_approved_source_parts/` に現在の採用済み原画のデータ片があり、`t4_gamehall_make_motion_layers.py` がSHA256 `d9e200bbdb5059613a3ea52804abe8f95cada42cb82e82e4705054ad140951a1` を検証する。古い7m時点の `gamehall_user_original_20261109.jpeg`（別原画）に間違って戻さない。
- `sequel/tests/sa2_t4_floor_transition_capture.gd`: 左端→ロード→別Level→遊技場表示と動作→右端→元MAP、D2カメラ・スクリーンショットを実テスト。
- `.github/workflows/sa2-t4-floor-transition.yml`: Godot4.7.2でテストし、PNG、24フレームからGIFとMP4を書き出し、T4ブランチに保存。
- `.github/workflows/sa2-t4-floor-media-qa.yml`: チャット内で見せる縮小JPEG・base64を書き出す補助。

## 4. 最後に検証された結果
- 実走成功CI（撮影暗転修正版）: https://github.com/yyvape-dev/SA/actions/runs/42589799714
- `sequel/captures/t4-gamehall-floor/` に以下のGodot実ファイルがある:
  - `01_existing_backtown_west.png`（既存街区の西端）
  - `02_loading_visible.png`（実際のローディング）
  - `03_new_gamehall_centre.png`（暗転解除後の新MAPカジノ正面）
  - `04_new_gamehall_motion.png`（新MAP上の微小動作）
  - `05_return_original.png`（元MAP復帰）
  - `motion_00.png`〜`motion_23.png`
  - `t4_gamehall_new_map_motion.gif` と `t4_gamehall_new_map_motion.mp4`（24コマ・H.264 MP4）。
- CIログ: `T4_NEW_FLOOR_BUILT ... width=16m height=10m ... animated=6`; `T4_FLOOR_TRANSITION_PASS floor=gamehall`; `T4_FLOOR_TRANSITION_PASS floor=backtown`; `T4_FLOOR_ROUTE_PASS ... screenshots=29`。
- **PASS**: 新MAP別Level生成、左側からのロード移動、右側からの復帰、6レイヤーを新MAPで駆動する処理、Godot4.7.2実撮影、24フレームMP4/GIFの出力。
- **NOT TESTED**: 実端末での手動プレイ/操作性、人物の肘・手首・首などの真の関節動作、スロットリールの図柄としての自然な進行、独立MAPの周辺レイアウト/美術完成品質、透明境界/補完の完全な画面品質、モバイルの負荷・FPS。
- **要注意**: 現在の人物の動きは局所UV歪みであり、スケルタルリグではない。腕が独立して自然に動くことは未実現。人物・スロット筐体・テーブル全体を揺らす方式はユーザーに不評で廃止済。

## 5. 次の実作業（この3点。レビュー可能な完成形まで連続実行）
### A. 人物の関節単位動作
- 元絵の人物3名（左右の女性、コートの男性）を基準に、可動の首・肩/上腕・前腕・手を**元ピクセルの機械的な切り出しで細分化**。足元・胴・頭の比率と立ち位置は固定。元絵にない隠れ部分のみ最小補完する。
- 顔・手・衣服の破損、切断線、余白のにじみが出ないよう原画再合成→1動作ループ→Godot D2実画面で検査。**画像1枚のシェーダー歪みを「関節アニメーションPASS」としない。** 動作例：スロット操作の手、ディーラーの手配り、客の首振り・グラス/カードを持つ手（実在する元画像パーツに限る）。
- リグが必要で、素材の欠損が原因で自然な動作が不可能なら、その部位だけを最小限加筆し、元絵との重ね合わせ・品質比較をしてから採用。

### B. 遊技機の明瞭な演出
- **スロット筐体・テーブル・椅子は位置と外形固定**。リール図柄の見える回転/停止、ボタンや宝石の発光、点滅の周期、ルーレット盤/球の視認できる変化を局所的に実装。過度な全体揺れ・横方向のテクスチャ継ぎ目は禁止。
- 動作の有無だけでなく、通常D2カメラで「何が動いたか」視認可能かを検査。必要なら実撮影部分を非破壊で拡大して並列提示。

### C. 新MAP周辺の美術
- 新MAPは現裏町のコピーなので、16mカジノの**左右のつながり、道路との境界、床の光・反射、看板/外壁の明度・色差、入口足元**の破綻を実画面で観察し、T4の新MAP側だけで是正。
- 既存旧MAPの店や道路を変更しない。16mの柱/開口のサイズ、マゼンタ外周、重複する旧NPC/樽/柱、可動レイヤーの前後関係も確認。
- 現在の `global_position` 範囲による非表示処理は根絶的な美術調整ではない。不要なコピー要素の除去が範囲外へ広がらないよう注意。新MAPだけの対象ID/実画面検証で管理。

## 6. 合格条件と結果の伝え方
1. 3名それぞれに**関節として動く部位**があり、動作が自然で足/胴の基準がずれない。元絵基準、マスク/隠れ部分、輪郭の破綻無し。手や首の独立運動がなければFAILまたはNOT TESTED。
2. リール・遊技盤・光が通常視野で明瞭に動くが、筐体/台は固定。2秒ループ前後、継ぎ目、フレーム差分、視認性と質をチェック。
3. 新MAPの背景・床・カジノ入口が馴染み、既存店を上書きしない。元MAPとのロード往復が回帰なし。新MAP D2の左/中央/右と、足元が見える画角を撮影。
4. Godot4.7.2で**各動作の実再生と実画面録画**。GIF/MP4とPNG接写を採録し、**チャット内で直接表示**。MP4を無検証のHTML埋め込みに頼らない。
5. T4ブランチのGitHub差分とCI結果を確認し、main/T2/T3を変更していないことを確証。未確認事項はNOT TESTEDで報告。

## 7. 必読資料とスキル
- 本書全文・前正本 `sa2_t4_handoff_20261109_scale_correction.md` の歴史的経緯・旧正本 `sa2_handoff_20261109_t4_gamehall_relayout.md` の第8節（ただし現状の仕様は本書優先）。
- 上記すべての主要ソース/テスト/Workflow、`motion_manifest.json`、Godot実スクリーンショットを実際に開く。
- インストールされている場合はスキル `game-art-animation/tool-routing`, `quality-gate`, `asset-qa`, `sprite-animation`, `sprite-workflow-external`, `character-consistency`, `godot-shaders`, `create-game-assets` の本文・必要な参照ファイルを**実際に読む**。実行ホストで読めなければその事実と停止条件を明示し、読んだふりをしない。
- Tool/Skill名前の列挙を利用したことと混同しない。編集前に取得した正しいブランチ・素材・依存関係を確認し、編集後はCIと実画面で再検証。

## 8. 次チャットに貼る実行指示
> GitHub `yyvape-dev/SA` の `test/sa2-t4-gamehall-relayout-20261109` にある `sequel/docs/sa2_t3_design_gate_20261108/reports/sa2_t4_handoff_20261109_next_animation_art.md` を全文読み、記載スキルと現行実装コード・素材・実撮影を確認した上で、人物の関節単位動作、遊技機の明瞭な局所演出、新MAP周辺の美術調整をT4ブランチで実装し、Godot 4.7.2の実動画・実画像をチャット内に表示して品質検証まで完遂。静止画の貼り直し確認に戻らず、既承認事項を再質問しない。main・T2・T3を変更しない。PASS/FAIL/NOT TESTEDを実証ベースで報告する。
