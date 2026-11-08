# T2 リリィ素材読み込み待ち修正・外部AI向け引き継ぎ

## 対象・承認範囲

- リポジトリ: `yyvape-dev/SA`。書き込み先は `feat/sa2-t2-sequel-integration-20261108` のみ。
- 修正起点: `6d77c47ae5f3496f29340701dfb239cdbbaafa45`。
- ユーザーは「解像度を下げない読み込み制限修正」と、外部AIが変更を理解できる記録を承認した。本変更はその範囲に限定する。
- main・SA1・他ブランチ・承認済み本文への変更／マージ禁止。A案の独立したリリィ操作アダプタと回避兼用ジャストガードを維持する。

## 原因と変更前の挙動

`main.gd::_ready()` は `_load_ally()` を起動する。Webでは同メソッドが `district.ensure("al1")` をawaitしてから実際のAllyノードを作る。一方、T2は親の_ready終了後に120 process_frameだけ待ち、`battle.ally == null`ならアプリを終了していた。

120フレームは60fpsで約2秒、30fpsで約4秒に相当し、読み込みの成否と無関係に締め切りが変わる。容量増加や通信遅延で、正常に進行中の読み込みを失敗扱いする。

## 何をどう変更したか

### `scripts/sa2_t2_playable.gd`

1. T2で `_load_ally()` をオーバーライドし、既存の `super._load_ally()` が戻った後に `t2_ally_load_done` と `t2_ally_load_resolved(loaded)` を更新する。既存ローダーのダウンロード・JSON解析・Ally生成はそのまま使う。通常シーンの `main.gd` 自体は変更しない。
2. 120フレームのポーリングを `_t2_wait_for_ally()` に置き換える。すでにAllyがある場合は即成功、ローダーが失敗終了済みなら即失敗、処理中なら完了通知をawaitする。
3. 無期限待機を避けるため、`ALLY_LOAD_TIMEOUT_SECONDS = 60.0` のTimerを併用する。`ignore_time_scale = true` と `PROCESS_MODE_ALWAYS` によりゲームの時間倍率・一時停止に左右されない。フレーム数を期限にしない。通常実行時は非スケーリング時間の秒数であり、`--fixed-fps`によるCIの模擬時間と実際の通信秒数は区別する。
4. 成功・失敗・時間切れのいずれでも待機Timerを停止・解放する。時間切れはローダーの完了状態を偽装せず、遅れて来た通知だけで演習や会話を再開始しない。
5. 待機が必要な間は既存ローディング画面を表示しラナ操作をロック。T2の初期化が終わったら既存のフェードで戻す。失敗時の終了方針は保持し、ログでロード失敗と60秒タイムアウトを区別する。

### `tests/sa2_t2_asset_wait_test.gd`

- 既存シーンを継承するテスト用クラスで、実ローダーの呼び出しだけを180フレーム遅延させる。その後は元の素材と実Allyノードを使い、会話開始とリリィ操作対象の接続を検証する。
- 修正前: Godot 4.7.2で120フレームの期限に到達し、`SA2_T2_FAIL: Lily atlas/companion did not load`、exit 1。再現ログ: `/workspace/sa2-asset-wait-evidence/logs/red.log`。
- 修正後のローカル検証: 30fps／600fpsの両方、および`--fixed-fps`を指定しない実時間実行でPASS。既存T1 37項目・T1.5・T2ガード境界・T2.5復帰・実入力戦闘の5スクリプトもPASS。独立した読み取り専用レビューでCritical／High／Mediumの指摘なし。
- 追加の待機契約試験: キャッシュ済み成功、失敗終了済み、非同期失敗、非同期成功、時間倍率0でのタイムアウト、Timer解放、遅延通知で進行が重複しないこと。
- 非同期失敗等の単体ケースはI/O境界の完了状態を模擬する。Web通信そのものを検証したと扱わない。

### `.github/workflows/sa2-t2-compatibility.yml`

- 既存の回帰・録画検証を保持し、30fps／600fpsの追加試験を組み込む。成功マーカーと既存のエラー検出を利用し、追加ログは既存artifactへ格納する。

### `HANDOFF.md`

- 外部AIが最初に読む引き継ぎ文書の冒頭に、本書への参照と変更範囲を追加する。

## 画質・容量への影響

画像、アトラス、素材パック、インポート設定、エクスポート設定、描画解像度、圧縮率は変更しない。低解像度素材への差し替えや非可逆圧縮は行っていない。デメリットは、失敗と判断するまで最大60秒待つ場合があること。60秒を超える正常な通信は引き続きタイムアウトする。

Timerはメインスレッドの同期処理を強制中断するものではない。また、待機の期限とHTTP取得のキャンセルは別契約である。現在は起動失敗時に既存どおりアプリを終了する。将来この関数を終了しない画面で再利用する場合は、通信キャンセルと遅延完了の扱いを別途設計すること。

## 再検証方法

Godotは `4.7.2.stable.official.ed1daf0bf`。テスト用のXDG_DATA_HOMEを別ディレクトリにして通常セーブから隔離する。

```sh
godot --headless --path sequel --fixed-fps 30 --script res://tests/sa2_t2_asset_wait_test.gd
godot --headless --path sequel --fixed-fps 600 --script res://tests/sa2_t2_asset_wait_test.gd
```

成功は `SA2_T2_ASSET_WAIT_PASS` とexit 0、SCRIPT ERROR／ERROR／リーク警告なしで判断する。追加テストとともに `sequel/tests/` の既存5スクリプトも実行する。変更差分は `git diff 6d77c47..HEAD -- sequel .github/workflows/sa2-t2-compatibility.yml` で確認できる。

## 未変更・未検証を次のAIへ引き継ぐ

- 操作切替の全面共通化、イベント設定の外出し、素材パック分割、メモリ削減、敵の近傍検索、CIの高速／録画分離は本変更では実施しない。以前の追加レビューに挙げた将来課題として残す。
- 実際の低速Web回線でのパック取得、iPhone/Android実機は未検証。本試験はGodotネイティブ実エンジンの遅延ロード再現である。
- 前回T2.5のGUI攻撃の単発CI失敗は原因未確定。今回の読み込み修正で解決したとは扱わない。完全な敵HP／位置の途中保存も未実装。
- ローカルログは `/workspace/sa2-asset-wait-evidence/logs/`。最新コミットのCI結果・Run IDは作業終了時の報告を参照する。T2.5全体のPARTIAL判定をこの修正だけでPASSへ変更しない。
