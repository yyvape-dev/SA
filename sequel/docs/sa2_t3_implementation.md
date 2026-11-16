# SA2 T3 C2-09 実装・検証報告

承認済みB案を限定仕様で実装。起点は `ddc257067b82f0c796cdbc9c1becc46f7bc7a12e`。開始時のリモートHEADは起点と一致し、設計ゲート `fd57198b17e098d31402c0fac1d74bea9650d8e0` と明示的story refの資料を参照した。実装ブランチは `feat/sa2-t3-street-encounter-20261108`。mainへ変更・マージしない。

## 実装

`sa2_t3_playable.tscn` と `sa2_t3_host.gd` が既存街Levelを保持して構成する。encounter/definition/profile、control lease/manual driver、combat policy、evacuation、checkpoint/snapshot、HUDを分離。Battle/Enemy/Allyの共有変更はnullable opt-in policyとprofileだけ。既存T2 Manual・シーン・main.gd・Player・SA1・正式本文・Claude指示は変更していない。

状態は EXPLORE → STREET → RESULT_PENDING → COMPLETE。HP0をAND成功判定より先に処理し、敗北または中断起動はSAFEへ戻す。RESULT_PENDINGは保存成功まで操作・探索復帰を解除しない。current/backup/tempの検証、チェックサム、schema/キー/ID検証と原子的renameを使用。temp単体を確定結果として復旧しない。共有HP/ゲージとactor transient、NPC初期経路、敵・イベントを開始前状態へ復元する。

機械は同一profile・別安定IDの2基。住民は背景crowdとは別所有の3人。既存階段に対応する専用waypointを下り、安全地点へ向かう。リリィと機械は下層のみ。全攻撃形状のダメージ直前にroster/floor/遮断境界を検証し、ダッシュ・攻撃移動・被弾・pull・knockback・両対象separationをsweepする。帰還後も宣言済み閉鎖境界を維持する。

既存街・リリィ/Rana・住民画像を流用。機械SVG/回転刃、避難・閉鎖マーカーとHUDは仮素材。正式美術・音声・台詞・報酬・経験値は追加しない。T3の探索装備メニューはメモリ上だけで扱い、成長saveに書き込まない専用Progress adapterを用いる。

## 受入結果

| 条件 | 結果・証拠 |
|---|---|
| 同一Levelで探索→手動戦闘→探索 | PASS playable/input |
| 手動入力、AI二重更新防止、移動/攻撃/回避/防御 | PASS actual key/touch input |
| 機械2基のみ対象、住民/人物/設備の無ダメージ | PASS contract/boundaries |
| 避難3＋停止2、逆順/重複/無効ID/同時勝敗 | PASS state/playable |
| 遮断境界・floorと全移動/攻撃経路 | PASS boundaries/review |
| 20回敗北再挑戦、ノード/接続/状態非増殖 | PASS playable |
| 戦闘終了→別プロセス起動→HP63等の開始前復元 | PASS restart-save/resume |
| 勝利後再起動、再発生なし、閉鎖維持 | PASS resume-win |
| 保存失敗、破損current/backup、未知schema/temp | PASS state/save_fault（4段階fault＋実open失敗） |
| 成長save/T2 save非破壊 | PASS review、未知metadataもバイト比較 |
| T1/T1.5/T2/T2.5/通常街 | PASS 新規実行suite |
| T3 Resource/JSON/画像のimport/PCK同梱 | PASS 空プロジェクトのpack検証・pack起動 |
| 実Godot描画・正常/敗北/再起動動画 | PASS 1280×720、H264/yuv420p/faststart、全フレームdecode・代表画面目視 |
| スマートフォン横長比率 | NOT TESTED 指定1560×720の動画も1280×720出力だったため合格扱いしない |
| iPhone/Android/Web実機・WebGL/IndexedDB | NOT TESTED |

## 再現と証拠

Godot `4.7.2.stable.ed1daf0bf`。`GODOT_BIN=/path/to/Godot T3_LOG_DIR=/tmp/t3 bash sequel/tests/run_sa2_t3.sh` が24シナリオを新規実行し全件PASS。固定FPSは機能テストの決定性用であり実性能値には使用しない。RED/GREENは欠落policy/encounter/host、loss flags、review modal/closure、growth save、finite clip等を記録した。最終ログは `sa2_t3_evidence/`。過去CI結果を今回の実行結果に流用していない。追加CIはpush後に実行状況を確認する。

配布検証: `Godot --headless --path sequel --editor --export-pack 'T3 Web' /tmp/t3.pck`、ソースのない空projectで `sa2_t3_pack_test.gd -- /tmp/t3.pck`、`--main-pack /tmp/t3.pck --quit-after 5`。Web向けPCKの依存同梱検証でありブラウザ実行の合格ではない。

録画は実Godot OpenGL3/X11で `--fixed-fps 24 --write-movie` とinput testを使い、ffmpeg libx264/yuv420p/faststartへ変換、全フレームdecodeした。通常系では実入力・自然AI予兆・ガード/回避・HP減少・実経路完了を通す。敗北系ではcheckpoint取得後に検証用HP4とし自然攻撃で敗北しGUIで再挑戦する。再起動系は開始前HP63を保存して実際にプロセスを終了し別プロセスを起動した。正常/敗北/再起動MP4とPNGはチャット納品の証拠ZIPに収録する。画像生成モックは使っていない。

## 性能と独立レビュー

別紙 `sa2_t3_performance.md`、生データ `sa2_t3_evidence/performance.json`。同条件21試行、llvmpipeソフトウェア描画。機械2→30で平均フレーム時間中央値173.94→290.47ms。描画品質は変更していない。端末GPUの性能合格ではなく、AI/描画/GPUの個別帰属や長期プレイは未検証。

実装者とは別のレビュー担当がロック済み `5ff6195` を検査しCritical0/High1/Medium4。原文は `sa2_t3_independent_code_review.md`。modal ownership、探索境界/room復元、checkpoint任意キー、経路境界検証、素材測定の5件を修正し、authorによるRED/GREENと最終24シナリオで確認した。独立担当による修正後再レビューを実施したとは主張しない。追加で4段階保存faultと成長save非破壊も確認した。現時点で既知の未解決Critical/High/Mediumはない。

## 残課題

正式素材・音響は対象外。スマートフォン比率、物理端末/Webの入力・保存・描画、長時間安定性は未検証。ソフトウェア描画は低FPSで、端末受入前にGPU環境で再測定する必要がある。新しい敵はprofile/画像、イベントはdefinition/routesを追加できるが、今回はC2-09の2基3人検証に限定した。T4以降へ共通DSLを拡張したり今回の固定成功条件を一般化したりしていない。mainへのマージと実機配布は本作業で実施しない。
