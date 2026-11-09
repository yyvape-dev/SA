# SA2 T3 外部レビュー入口

このディレクトリから、会話履歴・ローカルworkspaceを使わずレビューできる。機能コードの固定対象は **47b6e8869dff831d828c39c4cff9335b055099e6**、起点は **ddc257067b82f0c796cdbc9c1becc46f7bc7a12e**。この資料追加ではゲームコードを変更しない。

## 読む順序

1. [仕様書](specification.md)：承認されたゲーム挙動・境界・保存契約・対象外。
2. [承認済み実装指示](design-gate/reports/implementation-brief-approved.md)、[設計v2](design-gate/reports/design.md)、[独立設計レビュー](design-gate/reports/independent-review.md)。設計資料コピー元は `docs/sa2-t3-design-gate-20261108` の `24d38c98f69956a6370819bf9b836db793568ef7`。実装開始時参照fd57198からの更新は承認briefと別件T4資料の追加のみで、設計本文差分はない。T4資料は本レビューに含めない。
3. [実装・受入マトリクス](../sa2_t3_implementation.md)、[実装計画](../../../docs/superpowers/plans/2026-11-08-sa2-t3.md)、[進行記録](../sa2_t3_progress.md)。
4. [独立コードレビュー原文とauthor修正対応](../sa2_t3_independent_code_review.md)。独立レビューは5ff6195時点。最終修正を独立担当が再レビューしたとは扱わない。
5. [性能報告](../sa2_t3_performance.md)、[生データと24件の最終ログ](../sa2_t3_evidence/)、[既存コード調査](design-gate/reports/survey.md)、[設計時検証](design-gate/reports/verification.md)。設計時測定と今回実装後測定を混同しない。
6. 実画面：[正常MP4](media/t3-normal.mp4)、[敗北・再挑戦MP4](media/t3-loss.mp4)、[別プロセス再起動MP4](media/t3-restart.mp4)、[戦闘PNG](media/t3-battle-1280.png)、[帰還PNG](media/t3-win-1280.png)。GitHubプレビューで再生できなければRaw/Downloadを使用。全て実Godot描画で、動画はH264/yuv420p/faststart。バイト数とSHA256は[manifest](media-manifest.json)。

## コードと再現

[Host](../../scripts/sa2_t3_host.gd)、[Encounter](../../scripts/sa2_street_encounter.gd)、[Policy](../../scripts/sa2_street_combat_policy.gd)、[Checkpoint](../../scripts/sa2_street_checkpoint.gd)、[Snapshot](../../scripts/sa2_street_snapshot.gd)、[Lease](../../scripts/sa2_control_lease.gd)、[Driver](../../scripts/sa2_street_manual_driver.gd)、[Evacuation](../../scripts/sa2_evacuation.gd)、[定義](../../events/C2-09.tres)、[Profile](../../enemies/cutting_machine.tres)、[テスト一式](../../tests/)。共有変更はBattle/Enemy/Allyのopt-inのみ。レビュー差分は起点SHAから対象SHAまでで確認する。

Godot 4.7.2でリポジトリrootから `GODOT_BIN=/path/to/Godot T3_LOG_DIR=/tmp/t3 bash sequel/tests/run_sa2_t3.sh`。専用のXDG_DATA_HOMEを設定し検証用user saveを隔離する。手動起動は `Godot --path sequel res://sa2_t3_playable.tscn`。SPACE開始、WASD移動、J攻撃、K回避/予兆中防御、E避難開始。HUDボタンと左側touch移動も使用できる。

## レビュー依頼範囲・注意

正確性/回帰、保守性/データ検証、敵・NPC・素材増量時の性能を評価する。特に保存失敗時の公開結果、対象外ダメージ、全移動経路の閉鎖境界、modal/input ownership、20回再試行、別プロセス復元を検査する。未解決Critical/Highがあれば受入不可。

現状のローカル機能試験24件はPASS。端末GPU、iPhone/Android、WebGL/IndexedDB、スマートフォン横長比率と長時間運転はNOT TESTED。性能はllvmpipeソフトウェア描画であり端末合格ではない。動画固定24fpsは性能値ではない。mainマージ・正式素材・音響・報酬・物語改稿は対象外。正式物語本文は外部向け資料に転載しない。

## GitHub CIの確認結果

機能コミット47b6e88の[新規CI実行](https://github.com/yyvape-dev/SA/actions/runs/42538788129)は **FAIL**。Godot準備、24件回帰ステップ、空projectでのpack依存検証は成功したが、`Record actual normal/loss/restart Godot input`ステップで失敗した。これはローカル録画成功とは別の結果であり、CI録画成功・CI全体合格とは扱わない。原因の特定・修正は未実施。この資料追加コミットによるCI再実行も、結果確認前に合格扱いしない。

PNG保存先の原因確認・限定修正・実Godot再検証は[CI修正報告](../sa2_t3_ci_screenshot_fix.md)を参照。上記FAILは修正前の履歴であり、修正後CIと区別する。

修正後の新規CI **42541909216は全体PASS**（機能/テストコード4466a2a）。保存先明示・未設定のローカル実描画もPASS。詳細とCI結果JSONは上記修正報告を参照。この追記は資料のみで、検証済みコードを変更しない。
