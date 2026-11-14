# SA2 プロローグ進行プレビュー Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. 現ユーザーの指定ブランチで直接継続する。

**Goal:** 設計済みP0-01〜07を独立した操作可能な仮組みで接続し、台本・保存と室内構図をレビュー可能にする。
**Architecture:** 既存DB・会話パネルを再利用。小さな専用状態管理は会話・操作待ち・完了を管理し、別の室内表示が確定配置を復元する。本編やFlowStateに接続しない。
**Tech Stack:** GDScript / Godot（対象4.7.2、利用可能な実行環境4.6.3は別記）。
**Spec:** docs/superpowers/specs/2026-11-14-sa2-prologue-design.md

## Global Constraints
- feat/sa2-prologue-20261114のみ。SA1・本編起動・既存Web配信を変更しない。
- 引用台詞を保持し、接続文は実装用補筆として出典を記録。真相とランカの行先を追加しない。
- 新規画像生成は実施せず、人物未制作を明示した仮組み。既存ラナ・リリィを使用。
- 紙の発見より前に発見フラグを付けない。会話スキップは現在の会話だけ。
- 専用JSON保存は成長セーブと分離。各確定状態で保存し、演出コールバックを保存しない。
- export_web.pyは読了。今回Web配信・専用パック制作は対象外とし、完成絵・4.7.2検証後に行う。

## Review Focus
- 会話終了の二重通知・連打で操作待ちを飛び越さない。
- 壊れた保存と未知の行IDで人物位置や完了フラグが先取りされない。
- 会話途中と書き置き直後の復帰で同じ行・同じ配置に戻る。
- 画面比率が変わっても操作対象と人物の足元が会話窓に隠れない。
- UI上のタッチ・ログ・スキップが移動として漏れない。

### Task 1: 出典付き台本と専用進行状態
**Files:** dialogues/ja/P0-*.json、scripts/sa2_prologue_state.gd、tests/sa2_prologue_state_test.gd
**Interfaces:** snapshot()/restore(data)、finish_dialogue()、interact(action)、set_line(id)、move_to(x,z)、save_to(path)/load_from(path)。状態はbeat_id・line_id・player位置。導出フラグを保存入力から信用しない。
- [x] 状態テストを先に書き、不正遷移・距離条件・会話内スキップ・全経路・全チェックポイントの復帰・壊れた保存の拒否を検証する。未実装時FAILを確認。
- [x] 引用／補筆の区別を持つ外部JSONを作り、最小の状態管理でPASSにする。
- [x] 既存DBと会話UIの回帰を実行する。

### Task 2: 独立シーンと室内構図
**Files:** sa2_prologue_preview.tscn、scripts/sa2_prologue_preview.gd、scripts/sa2_prologue_room.gd、tests/sa2_prologue_preview_test.gd
**Interfaces:** Stateのbeatが配置の正本。表示側は確定配置→会話開始の順。UI操作中は移動しない。紙の拡大と道具への寄りは該当beatのみ。
- [x] シーン接続のテストを先に書き、会話ロック・近接入力・復帰・スキップ境界・全文送り・ログ・完了を検証。未実装時FAILを確認。
- [x] 3室の床・机・小物・人物を作り、ラナ移動と共通の文脈ボタンを接続する。
- [x] 両比率で描画確認。環境で不可能な検証は未検証と記す。

### Task 3: レビュー・引き継ぎ
**Files:** sequel/docs/sa2_prologue_progress_20261114.md、sequel/HANDOFF.md
- [x] テスト結果・実行版・画面見本・補筆台本・未制作素材を記録。
- [x] 差分レビューとgit diff --check。専用ブランチへcommit/pushし読み戻す。本編Pagesの公開と混同しない。

## 実行記録
- 専用ブランチを新規checkoutし、その中で継続。新しいworktreeやmainの変更は不要と判断。
- 設計を全面的な完成アート版に拡張せず、今回の実装範囲を進行・台本・仮組みの検証に固定。背景・新人物・細かな演技・Webは成果報告で明示して次工程へ残す。
- 状態・シーンのテストを未実装時にFAIL確認。レビューの自動送り不具合・向きの復元漏れもFAIL→修正→PASS。
- 3室の確定配置と固定カメラを正本とし、汎用コマンドエンジンを追加しない。暗転中の復帰は確定後の配置。
- 4.7.2が無いため4.6.3でのテストと撮影を区別。Webのバイナリは作成・更新しない。
- レビューと検証の詳細は sequel/docs/sa2_prologue_progress_20261114.md。
