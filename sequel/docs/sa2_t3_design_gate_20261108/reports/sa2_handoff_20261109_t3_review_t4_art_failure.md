# SA2 次チャット移行正本 — T3 完了報告レビュー / T4 市場背景失敗分析
作成日: 2026-11-09 JST
種別: **引き継ぎ・是正指示**。既存の合意/仕様は変更しない。実装・美術完成を宣言するものではない。
公開する内容はネタバレなし。GitHub `yyvape-dev/SA` の資料・コードを正本とする。

## 0. 結論・今の判断
- **T3**: 独立実装ブランチとドラフトPR #2が作成され、コード・ローカルテストログ・実Godot映像がGitHubに存在する。だがGitHub Actions最新2回とも録画ステップFAILで、独立レビューは修正前コミットのみ。**T3総合受入は保留**。main未マージ。
- **T4**: 既存のbacktownレイヤー/3D配置構造は再設計不要。ソース調査で追加すべき絵5スロットが判明。**採用可能な新規5素材は0点**。画像生成の複数試行は形状・視点・透過・背景分離に不適合。Godot新素材の実画面適合は未実施。
- 新チャットは承認済み事項を繰り返し質問せず、まずこの文書と対象現物を確認し、下記のゲートを満たす作業を直接進める。新しい大規模方式/仕様変更のみ合意を求める。

## 1. 担当と既承認境界
- ChatGPT: 企画・要件・仕様合意・現物調査・小規模実装/軽微修正（直接GitHub反映可）・画像制作・成果物評価。
- Codex: 複雑な実装、広域変更、独立レビュー、テスト、実Godot証拠。T3はCodex担当。
- GitHub: 合意仕様・変更履歴・実装/検証記録の正本。
- Workは必要な大量調査/操作の補助。勝手にチャットの開発役割を廃止しない。
- `main`・SA1・正式物語本文・既存T2 ManualとT2シーンは非変更。T3の修正はT3ブランチへ、T4素材の追加/統合は別の隔離ブランチへ。ユーザーはT4制作開始を承認済み。新レイヤー・全面街区再設計・生成によるGodot画面代用は承認なし。

## 2. T3：事実・根拠・修正要求（美術作業とは分離）
### 2.1 GitHub現物（2026-11-09確認）
- PR: https://github.com/yyvape-dev/SA/pull/2  (draft/open, not merged)
- Branch: `feat/sa2-t3-street-encounter-20261108`
- HEAD: `ecf6439dbb7ed27d40d8e7a544a1cba98717608b`。起点 `ddc257067b82f0c796cdbc9c1becc46f7bc7a12e` より6 commits ahead、88 changed files。
- `sequel/docs/sa2_t3_implementation.md`: C2-09（同じLevel、Lily手動、機械2・避難3、AND成功、開始前checkpoint復旧、RESULT_PENDING、対象安全）を実装したとの報告。
- `sequel/docs/sa2_t3_evidence/suite.log`: 24 PASS行。GitHub Actions実行ログでも同じ24シナリオ実行PASS、PCK依存検証PASS。
- `sequel/docs/sa2_t3_independent_code_review.md`: 独立レビューはrevision `5ff6195` に対して Critical 0, High 1, Medium 4。作者が後続修正して自身のテストでcloseした記録。**最終コードの独立再レビューなし**。Highはexplore skill-slot menuからT3へ入力が奪われる問題で、修正とテストが作者により報告されている。M1〜M4も作者修正報告。独立に最終合格とは判定されていない。
- 動画/PNG: `sequel/docs/sa2_t3_external_review/media/` に GitHubバイナリ実体とmanifestが存在。manifestにbytes/SHA256があり、公式コードで生成したとの報告。ただし、このチャットのGitHubテキスト接続はバイナリのフレーム/内容を取得できず、**こちらによる映像目視再検査はNOT TESTED**。
- 実測: `sa2_t3_performance.md` のllvmpipe/OpenGL3、1280×720、ソフトウェア描画下の機械2体平均frame中央値173.94ms、30体290.47ms。スマホGPU性能の証明ではない。
- 未実施: iOS/Android/WebGL/IndexedDB/スマートフォン横長比率、長時間安定性。装飾/背景/正式UIはT4〜T6。

### 2.1a 正式工程の訂正：T7責務とT3検証の境界（2026-11-09）
**重要な訂正：** T3にiPhone/Android実機、Webブラウザの保存/再開、端末FPS/操作を要求したうえで未達と判定してはならない。これらは承認済み上位計画 `story/sa2-chapter1-20261106:claude/sa2_vertical_slice_implementation_plan_20261108.md` v4.2 の「ユーザー指定：スマホでの成果物提示と実機検証」で**T7（最終総合実測・品質判定）**に明記されている。T2/T3ではGodot自動実操作・連続動画を中間検証として先行し、T6でHUD/VFX可読性を確認する。T7への配置をCodexのT3実装欠陥として報告するのは工程評価の誤り。
- 承認済みT3実装brief第37行は「Prefer 1280×720 and horizontal phone aspect when runnable」であり、スマホ横長比率は**可能な場合の追加確認**であってT3の必須受入条件としては要求していない。出力比率のNOT TESTEDは事実として残してよいが、T3必須機能のFAILと混同しない。
- `T3中に修正が必要`: 2回のGitHub Actions録画ステップFAIL（明確な保存先パスの不一致）と、最終修正後の独立再レビュー未実施。T3のPR受入と最終品質判定も区別する。
- `T7計画どおり未実施`: iPhone/Androidの実タッチ操作・FPS・ロード・保存・再開・Web配布/ブラウザIndexedDB、スマホ表示/横長比率の最終品質評価。これらを今ここで独断でT3へ前倒ししない。
- `工程設計の反省`: 中間動画の画質/操作感・UI問題を発見しやすくするためのスマホ比率テストを推奨扱いとした点は、実機UIリスクを残す設計上の弱さである。前倒しスモークテストは計画に示された**事前合意ゲート**による新たな判断を要する。Codexに無断要求しない。
- T3修正指示・T4素材作業は依然別件。既存役割（ChatGPTの軽微開発含む）と上位計画の工程区分は変更なし。

### 2.2 CIの再現済み失敗：P0
- RUN1: https://github.com/yyvape-dev/SA/actions/runs/42538788129 — FAIL
- RUN2: https://github.com/yyvape-dev/SA/actions/runs/42539298815 — **FAIL**（最新HEAD ecf6439）
- 両方とも先行24シナリオとexport-packはPASS。失敗は `Record actual normal/loss/restart Godot input`。
- ジョブログは `ERROR: Can't save PNG at path: '/workspace/sa2-t3-evidence/captures/t3-win.png'.`、exit 1。
- 直接原因: `sequel/tests/sa2_t3_input_test.gd` のscreen capture fallbackが、GitHub Actions runnerに存在しない/書き込めない固定の `/workspace/...`。同testは `T3_SCREENSHOT` 環境変数による宛先変更に既に対応。一方、`.github/workflows/sa2-t3.yml` 録画stepは `/tmp/t3-captures` しか作成せず、`T3_SCREENSHOT` を渡していない。
- 最小修正案（まだ実行していない）: CI stepの環境に `T3_SCREENSHOT=/tmp/t3-captures/t3-win.png` を設定し、成功している既存mkdirを流用。残るnormal/loss/restart-save/restart-resume分岐の全ログを再実行で確認し、png/mp4・ffmpeg全デコード・upload-artifactを検証。testで失敗したPNGを黙って無視する修正は不可。
- **停止条件**: 修正していないCIをPASSと主張しない。CI成功後に最終コミットで独立再レビュー（少なくとも既出H1+M1〜M4の固定差分）を取得してからT3受入判断。端末/Web等はその後もNOT TESTED。
- これはT3ブランチでCodexに修正させる。T4の文書/画像作業をT3コードへ混ぜない。

## 3. T4：GitHubで確認した固定構造・実在アセット
### 3.1 正本
- 配置: `sequel/scripts/backtown_block.gd`（T2実装ブランチのコード）。ここに既存街の壁/店の位置、天幕、柱、階段、前景、看板、屋台等のデータがある。
- 形状ガイド: `sequel/art/guide_bt/guide.json`、`sequel/art/guide_bt/{対象名}.png`。guideの`v2` / `v2_w_bar_shack_low`を参照、古いトップレベルpartsを新しい基準と混同しない。
- 既存絵: `sequel/art/painted_bt/` 24 PNG（4外壁地素材、既存屋台3、路地2、看板、前景など）。元絵: `sequel/art/painted_bt_src/`。
- 素材処理: `sequel/tools/cut_bt.py`、`sequel/art/painted_bt/cut.json`。実装前にスクリプトの実際の引数・切出し仕様を読む。
- 路面: `sequel/assets/ground/cobble.png`、`slab.png` 実在。追加路面絵は現時点で発注不要。
- 既存は3Dの仮形状・色面・設置座標があることがコードから確認済み。ただし新規絵5点を重ねた**実Godot描画はまだない**。

### 3.2 不足する制作スロット — まずこの5点のみ
| ID | 元ガイド | 制作元画面 | 3D区画/位置 | 状態 |
|---|---|---|---|---|
| `stall_game` | `art/guide_bt/stall_game.png` | 1024×1536 px | STALLS center x4.3, width2.4m,height3.0m; guide bbox x2.9526..5.6474, y-0.3..3.7421 | 未制作 |
| `w_bar_shack_low` | `art/guide_bt/w_bar_shack_low.png` | 1536×1024 px | 酒場 n1 x -11.4..-4.0, guide bbox -11.45..-3.95 | 未制作 |
| `w_cabaret_low` | `art/guide_bt/w_cabaret_low.png` | 1536×1024 px | キャバレー n2 x -2.0..5.2 | 未制作 |
| `w_brothel_low` | `art/guide_bt/w_brothel_low.png` | 1536×1024 px | 宿 n3 x 7.0..14.2（外階段あり） | 未制作 |
| `w_shady_low` | `art/guide_bt/w_shady_low.png` | 1536×1024 px | 怪しい店 n4 x18.8..25.0 | 未制作 |
Guideの製作キャンバスは確定。**production上の最終crop/実物のpixel bbox、既存cut pipelineの適合、ゲーム内評価は未確定**。新しいレイヤーを作らず既存slotsを使う。T4のゴールは「5枚の美術生成」ではなく、「5枚の位置/形状/透過と実Godot適合の受入」。

## 4. T4失敗分析（確認できた現象と原因仮説を分離）
| 欠陥分類（重複なし） | 観測された事実 | 工程上の原因／検証可能な仮説 | 防止ゲート |
|---|---|---|---|
| 依頼対象ミス | 単体素材が必要なのに全景構成図・仕様ボードを2度生成 | プロンプトが成果物の媒体・1画像1アセットを固定していなかった | コンセプトボード/全景/リスト/テキストが出たら即不採用 |
| 幾何・投影ズレ | 屋台2枚目は斜め投影、元ガイドとレイアウト不一致 | 対応するGitHubのガイド**画像そのもの**を編集入力に渡さず文章から新規生成した | 元ガイドを編集基準に正面固定、投影/外接矩形/主要輪郭の比較 |
| 背景・単体分離失敗 | 屋台3枚目には遠景/床・別建物が含まれた | 背景や不要オブジェクトを画像生成で許した | 単体用透過/マゼンタ原画、外側は単色、遠景/床なし |
| 透過・αの不適合 | magenta除去の自動スクリプトをPASSと報告したが、遠景の画素が不透明のまま残存 | 単色mask処理は不要な**描画済み背景**を消す処理ではない。画像セグメントの意味分離ができていない | PNG alphaの存在だけでなく、対象のみ残る意味マスク、背景残留、halo、ズレを検査 |
| 実装・視覚検証不足 | source画像の完成受入前にGodot配置を完了していない | 出力規格QAと3D配置 QA が別工程のまま未接続 | QA PASS後にのみ別T4 branchで実配置し、Godot実画面で比較する |
| 運用・品質管理失敗 | 失敗ごとに原因を突き止めず別プロンプトや「次にやる」と報告して無駄な往復 | 原因調査→最小検証→結果確認の門番なし。チャット容量/ユーザー時間を消費 | 1案件1ゲート、失敗は要因を記録し方式を見直す。同一手法で連続再生成しない |

## 5. 次のT4実行手順（ユーザー承認済み。新しい質問不要）
1. **まず1枚のみ** `stall_game`。GitHubの`art/guide_bt/stall_game.png`の**画像を実際に取得**し、元キャンバス1024×1536・shape・色面（マゼンタ背景、紫の屋根、真鍮筐体、水色の機械面、茶カウンター）を視覚・座標で読み取る。手持ちの一連の失敗画像は基準として再利用しない。
2. 見本は `art/painted_bt_src/stall_food.png`、`stall_parts.png`、`art/concept/backtown_*.png` 等の**現物**と比較し、塗り/光/スケールを合わせる。スタイルを文章だけで推定しない。
3. **ImageGenの元ガイド編集（image-to-image）**に限定。造形を追加せず、レイアウト・屋根端・台/画面矩形・外接座標・正面投影・人物なし・背景なし・無文字を固定。白/黒/単色化が必要なら決定的ツールで元ガイドのマスクを保持する。画像編集ツールだけで1px完全一致を保証しない。生成出力が元ガイドに逸脱するなら、そのまま採用せず、元ガイドから抽出した既存shape maskで領域別に再構成する手法を検討する。
4. Python/Pillowで出力サイズ1024×1536、RGBA、背景alpha=0、透過境界のhalo、生成結果の主要矩形/輪郭を**元ガイドと比較**。スクリーンショットで目視。最小基準：向きが完全正面、世界の街/床が無い、建物/横に出る小物が追加されない、サイズ/外接座標がガイドと一致。元ガイド由来の形を変える発明は認めない。
5. 満たした候補だけをソースとして保存し、既存`cut_bt.py`の実装を読んで`art/painted_bt_src/`→`painted_bt/`の仕組みに接続する。**ユーザー向けの合成風景イメージを納品素材と呼ばない**。
6. 確実に動くGodot4.7.2環境を実際に確認し、T3の編集中ブランチを変更しない別T4 branchで仮配置。新旧画面の同一カメラPNG・仮床/住民/リリィとの重なりを比較。ここで失敗なら制作素材の工程へ差し戻す。実Godotが実行できなければNOT TESTEDとする。
7. `stall_game`でこの方式が実証された後、同じ元ガイド編集フローで壁4点（酒場→キャバレー→宿→怪しい店）を個別に作り、同様にチェック。UI/T6はT3実際の画面を確認した後に別契約で扱う。
8. 制作ブランチと作業ログ、元ガイドsha、ソース画像・出力PNG、mask/寸法検証結果、Godot実画面キャプチャをGitHubに記録。**受入に必要な可視証拠を示すまで完成扱いしない。**

### T4 STOP条件
- 元ガイド画像を利用/確認できない。文字説明の新規生成へ切替え禁止。
- 画像生成を同じ方法で3回以上失敗し、再度同種プロンプトを出そうとしている。まず根本方式の見直し。
- ガイド形状が保てない、生成された床/遠景/文字が混入、α処理後もゴミが残る。
- Godotが使えず、生成画像を実画面の代替として報告しようとしている。
- main/SA1/T3作業ブランチにT4を混入させようとしている。

## 6. 証拠・受入表
| 作業 | 状態 | 根拠 |
|---|---|---|
| T3ブランチと実装差分確認 | PASS | GitHub compare起点→HEAD、PR #2 |
| T3ローカル24実行記録の参照 | PASS（ログ確認） | suite.log + 2 CIのテストステップ |
| T3 CI全体 | FAIL | 42538788129 / 42539298815 |
| 最終T3独立再レビュー | NOT TESTED | 独立レビューは5ff6195時点 |
| T3動画存在/manifest | PASS（存在・manifest） | external_review/media/ |
| T3動画の本チャットでの目視 | NOT TESTED | バイナリ内容取得・再生なし |
| T3実機/Web/横比率 | NOT TESTED | implementation/PR明記 |
| T4既存slot/サイズ/5点の不足棚卸し | PASS（ソース確認） | backtown_block.gd、guide.json、art directory |
| T4新規制作物5点の受入 | FAIL / 0 of 5 | 過去生成は位置/投影/背景に不適合 |
| T4実Godot合成 | NOT TESTED | 新素材未適合 |

## 7. 現在のGitHub正本リンク
- T3 PR: https://github.com/yyvape-dev/SA/pull/2
- T3実装報告: https://github.com/yyvape-dev/SA/blob/feat/sa2-t3-street-encounter-20261108/sequel/docs/sa2_t3_implementation.md
- T3 review: https://github.com/yyvape-dev/SA/blob/feat/sa2-t3-street-encounter-20261108/sequel/docs/sa2_t3_independent_code_review.md
- T3 CI RUN2: https://github.com/yyvape-dev/SA/actions/runs/42539298815
- T4先行調査文書: https://github.com/yyvape-dev/SA/blob/docs/sa2-t3-design-gate-20261108/sequel/docs/sa2_t3_design_gate_20261108/reports/t4-market-art-gap-and-production.md

## 8. 次チャットの最初の依頼
「GitHub `yyvape-dev/SA` の `docs/sa2-t3-design-gate-20261108` にある本引継ぎ文書を全文読んでください。既存の`AGENTS.md`/Handoffとゲームアート関連スキル（tool-routing、quality-gate、create-game-assets、raster-pipeline、systematic-debugging等）を実際に読んでください。再承認質問・新規全景・仕様ボード・汎用コンセプト画像を生成せず、まずGitHubの`sequel/art/guide_bt/stall_game.png`本物を編集入力に用い、輪郭/サイズ/透過を元ガイドと比較して1枚を制作してください。T3修正は別作業として2回連続CI失敗の原因と最終独立再レビューをCodexに提示し、T3コードをこの背景作業で変更しないでください。結果は制作素材と検査証拠で報告してください。」
