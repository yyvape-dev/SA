# SA2 T2.5 独立コードレビュー（2026-11-08、ネタバレなし）

## 修正前レビュー

- 対象: `feat/sa2-t2-sequel-integration-20261108` / `059ef3f91126ce200f239d4054e0c039df7cd125`
- 比較基準: `main` / `db1d8333dab5c6c9f86a00531be1ea64743aa7af`。GitHub compareは27 commits ahead / behind 0。
- 独立した読み取り専用レビュー担当が既存 `main.gd` / `enemy.gd` / `battle.gd` / `ally.gd` / `touch_ui.gd` とT2追加コードを確認。修正者も根拠を確認した。
- 指摘件数: Critical 0 / High 1 / Medium 1 / Low 1。静的根拠と実行確認を区別する。

| ID | severity | 修正前のファイル・行 | 再現条件・根拠 | 推奨修正 |
| --- | --- | --- | --- | --- |
| R1 | High | `scripts/sa2_t2_playable.gd:67-74` | 結果保存または勝利後の探索保存から再起動。load成功後もRESULT/EXPLOREをelseでFlow.newに置換し、即保存するため結果・完了記録を消去する。 | 保存モードごとに復帰し、新規初期化はロード失敗時に限定。実シーンで結果・完了保存からの起動を検証する。 |
| R2 | Medium | `scripts/sa2_t2_playable.gd:94,100,275` | 勝利→探索復帰→残った演習ボタン押下。Manualをqueue_freeしてもCanvasLayerとlambdaが残り、解放済み参照を呼ぶ。 | 演習専用ボタンを探索復帰時に解放。実入力後にSCRIPT ERRORがないことを確認する。 |
| R3 | Low | `tests/sa2_t2_lily_manual_test.gd:14-31` | 既存テストをGodot 4.7.2で実行するとPASS後に3 ObjectDB instances leaked。FakeFoeを生成後freeしていない。 | 終了前にテスト所有ノードを解放。既存assertionは維持する。 |

## 判定保留

- 結果画面ではManualだけが停止し敵物理更新は続く。ただし敗北後はbattle.player_alive()がfalseとなり新しい攻撃は始まらない。無限に被弾し続ける確定不具合としては扱わない。実画面と状態を追加確認する。
- 既存T2テストはguard_candidateのみで、実シーン復帰・入力・通常戦闘を保証しない。従来動画も直接アダプタを呼び、敵の攻撃時刻を設定しているため人間の入力経路を保証しない。
- INSTANCEの既存復帰は演習を初期化して再開する方式で、敵HPや位置の完全な途中再現ではない。

## 作業・検証記録

### 修正とRED→GREEN

- R1/R2: `sa2_t2_5_recovery_test.gd`を先に追加。未修正コードで結果の消失、完了記録の消失、残存する演習ボタンが失敗することを実エンジンで確認（`recovery-red.log`、exit 1）。モード別復元と探索復帰の共通処理、演習ボタン専用コンテナの解放を実装し、同じ検証がPASS（`sa2_t2_5_recovery_test-final.log`）。既存の戦闘アダプタ・ラナ・仲間AI本体は変更しない。
- R3: 既存テストのリーク警告を修正前に確認後、所有するFakeFoeをfree。全assertionを維持し、時間窓の両端／直外、距離と奥行きの境界、非攻撃状態の検証を追加。修正後はリーク警告なし。
- 新規入力テストはアダプタのattack/dodgeを直接呼ばず、キーボードとViewportのGUI入力を通す。敵の攻撃時刻を変更せず、自然なAIの予兆を観測してK入力する。
- 再現テストの可視性判定は`is_visible_in_tree()`を使用。非表示会話パネル配下の子ボタンの`visible`プロパティだけを調べると誤検出するため。
- 入力注入は固定1280×720のViewport座標で実施。headlessのウィンドウ座標変換を混同しない。これはLinuxのイベント注入であり、iPhone実機試験ではない。

### 実行環境・スキル

- エンジン: `4.7.2.stable.official.ed1daf0bf`。最初に配置されていた4.6.3は検証に使用せず、公式4.7.2 ZIPを取得した。
- 当初X11/Waylandが利用できずXvfb/sudoも無かったが、配置済みXorgのdummyドライバでユーザー所有の一時仮想画面を起動。OpenGL llvmpipeで実描画できることを実行確認した。
- GitHubプラグインで対象repoのpull/push権限を確認。CLIのGH_TOKEN認証は失敗したため、リポジトリ更新はGitHubプラグインで対象refを指定し、期待する旧HEADを照合する。mainへの書き込み指示を含む古いCLAUDE.mdより、今回のユーザー制約を優先する。
- 読了・適用: executing-plans、test-driven-developmentとwriting-good-tests、systematic-debugging、requesting-code-reviewとcode-reviewer、receiving-code-review、verification-before-completion、tool-routing、quality-gate。using-superpowersとCodex参照、using-git-worktrees、cloud-environment-runtimeのnetworking/packages、cloud-desktopも読了。新たなworktree/ブランチは作らず、対象ブランチだけを取得した専用checkoutで実施。
- 設計資料、ストーリーブランチv4.2計画と引き継ぎ、CLAUDE.md、sequel/HANDOFF.mdを確認。追加AGENTS.mdは存在しなかった。物語本文は改稿していない。

### ローカル実行結果

| 項目 | 結果 | 根拠と限界 |
| --- | --- | --- |
| A T1 | PASS | 37項目、実Godot headless |
| B T1.5 | PASS | JSON・文字送り・保存行復帰の既存試験 |
| C T2単体・境界 | PASS | 既存5条件に時間／距離／lane境界と状態条件を追加 |
| D 会話→演習と入力 | PASS | SPACE、タッチ移動、GUI攻撃、J/K入力を実シーンに注入 |
| E AI被弾・敗北・再挑戦 | PASS | 初期HP4の試験fixtureから実敵攻撃でHP0。結果GUIで再挑戦、HP100・attempt2を確認 |
| F 実当たり・勝利 | PASS | 2体それぞれの実死亡通知時HPが0以下。戦闘結果は入力から生成 |
| G 探索・通常戦闘復帰 | PASS | 演習ボタン解放、ラナの実攻撃、ラナ攻撃終了を待って独立したリリィAIの実ダメージを確認 |
| H 別プロセス再起動 | PASS（チェックポイント方式） | 実演習開始save→別Godot起動、実敗北結果save→別起動→GUI再挑戦、実勝利探索save→別起動。敵ごとの途中HP・位置・攻撃時刻の継続保存は未実装であり、この項目のPASSに含めない |
| I 修正回帰 | PASS | R1/R2のRED→GREEN、R3の警告解消 |
| J タッチ | PASS（Linux注入のみ） | ScreenTouch/ScreenDragの移動とrelease、GUIクリック。スマホ実機・多点同時押しの最終受入は未実施 |

### 動画・独立した最終レビュー

- ローカル実ファイル: `/workspace/sa2-t2-5-evidence/captures/t2_5_input.mp4`。Godot Movie Makerの連続526 frames / 24fps / 21.916667秒をH.264・1280×720へ変換。画像生成や静止画による代用なし。
- 動画を全デコードし、1秒ごとの接触シートで冒頭から探索復帰後まで目視確認。会話、敗北・再挑戦、標的2体、勝利、通常ラナとリリィAIが写る。黒画面だけの動画ではない。人間による操作感の最終受入とは区別する。
- ログ: `/workspace/sa2-t2-5-evidence/logs/`。失敗時と最終成功時のログを両方保存。
- 別の読み取り専用担当が修正後の全差分・テスト・ログを独立レビューし、再現根拠あるCritical/High/Mediumの残件なしと判断した。動画品質・実機・エクスポート・敵HPの厳密な途中保存はレビューの判断保留として残す。
- CIには既存検証を残したまま、回帰・入力・別プロセス再開・追加連続録画・全デコード検証を追加。新動画のartifact内パスは`sequel/captures/sa2_t2/t2_5_input.mp4`。最新Run IDと取得後の実パスは最終報告およびローカル`delivery.json`を正とする。
- ChatGPTへの直接添付はこの実行環境のツールでは保証できない。実MP4と取得情報を引き継ぎ、添付済みと主張しない。

## 残るリスク・受入範囲

- iPhone/Android実機確認はNOT TESTED（T7）。正式美術・本文・HUD/VFXの最終受入、配布エクスポートは今回の修正対象外。
- INSTANCEは演習開始チェックポイントへ戻す既存方式を保持。敵ごとのHP・位置を維持する完全な途中継続は未実装。これを必要とする受入条件にはFAILとする。
- 今回の自動検証合格はゲーム品質の最終受入を意味しない。最新コミットのCI・動画成果物確認が終わるまでT2.5完了とは扱わない。
