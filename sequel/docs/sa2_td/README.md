# TD：iPhone 16向けspotテスト準備

承認済みv4.3 TDを実施する。初回対象はユーザー指定 **iPhone 16**。iOS版・ブラウザは未確認。Safariを第一候補とするが、iPhone/Safariで動作確認済みとはしない。

## 起動するspot

| spot | 内容 | 限界 |
|---|---|---|
| T0 | 版、FPS/平均/p95 frame、保存probe・永続領域の表示 | 環境診断。物語のプレイ場面ではない |
| explore | 既存街の探索・タッチ移動 | 本番プロローグへの連続導線ではない |
| T1 | 既存JSON fixtureの会話・タップ送り | T1/T1.5機構の確認。本番台詞追加なし |
| T2 | 既存リリィ演習・タッチ攻撃/回避防御 | 既存T2シーンとManualは変更しない |
| T3 | 同じ街・機械2・住民3・勝敗/復元 | 既存T3実装をそのまま利用 |

`?spot=t0/explore/t1/t2/t3`で直接指定できる。TD menuへ戻ると新しいエンジンで起動し、古い入力leaseを残さない。選択spotはURLにも反映する。横画面を基本とし、縦画面の製品UI完成を目的にしない。T0は表示、各spotのStatsで診断を開閉する。Save probeは端末の保存経路確認で、ゲームの勝敗を操作するボタンではない。

## 保存と原本保護

TD Web featureでcustom user dirを`SA2-TD-Mobile-Spots`へ固定。実Webで`/userfs/SA2-TD-Mobile-Spots`を確認した。この領域以外ではlauncherがゲームspot開始を拒否する。probeは専用JSON、T3も専用checkpoint名。通常ゲームのuser dirと混在させない。OSのブラウザデータ消去・private mode・容量不足等による保存喪失は実機検証対象。既存saveへの未知metadata sentinel比較をWebで行ったとは主張しない。

## 再現

Godot 4.7.2公式engineと`web_nothreads_release.zip`を用意し、repository rootから:

```sh
GODOT_BIN=/path/to/Godot python sequel/tools/export_td_web.py --out /absolute/path/outside/source
python sequel/tools/serve_td_web.py /absolute/path/outside/source --port 8765
```

ローカル検証URLは`http://127.0.0.1:8765/`。これはスマートフォンからアクセスできる公開URLではない。配布ビルドはコミット済みclean sourceのみ許可し、manifestにSHA/dirty/Godot/全出力のSHA256を含める。`--allow-dirty`は開発preview専用。データ契約は`Godot --headless --path sequel --script res://tests/sa2_td_test.gd`。touch付きブラウザ検証は`NODE_PATH=/path/to/node_modules TD_BROWSER_OUT=/tmp/td-browser node sequel/tests/td_browser_smoke.cjs`（Playwright 1.62.1/Chromium）。任意のT3本体を疑似成功させるAPIは追加しない。

出力は約141MiB（PCK約103MiB＋WASM約38MiB、圧縮前）。初期候補は動作検査優先の全資源packで、軽量化済み製品ではない。スマホの回線・RAM・WebGLの制約を実機で測る必要がある。画質を下げてはいない。追加素材はpackへ入るため容量が増える。

## iPhone 16で実施する順序（公開後）

1. Safariで版付きテストURLを開く。iOS版・ブラウザ名・日時・ビルドSHA、初回表示までの体感/秒数を記録。横向きにする。
2. T0でStatsを撮影。Save probe→ページ再読み込み→tokenが同じことを確認。private modeは通常試験と分ける。
3. exploreで左側をドラッグして移動。ノッチ/ブラウザバー/左右端でキャラやボタンが欠けないか確認。
4. T1で日本語が読めるか、全文表示→次行→閉じるをタップで確認。
5. T2で会話終了→左ドラッグ移動→攻撃→攻撃終了後に回避。機械の予兆に合わせ防御。HP減少、敗北/再挑戦、勝利/探索帰還を確認。途中でブラウザを閉じて同じspotで再開する。
6. T3でSTART→左ドラッグ移動→GUIDE→攻撃/回避防御。機械2停止かつ住民3避難で帰還を確認。敗北と再挑戦、戦闘中終了/再起動時の開始前復元、勝利後再読込で再発生しないことを確認。
7. 各spotのStats（FPS/mean/p95）と不具合画面/画面録画を残す。全てを一度に成功させる必要はなく、spotごとにPASS/FAILを返す。

報告様式は[実機記録票](device-record.md)。ここでのFPSは端末で観測した場合だけ実機値とする。Chromiumのtouch emulation、llvmpipe/SwiftShader、固定FPS動画をiPhone性能へ読み替えない。

## 公開配布の提案・未実施範囲

既存Pagesは`https://yyvape-dev.github.io/SA/`、main/rootを公開中（読取り確認）。これをTDで変更しない。候補は別の公開テストrepository `SA2-TD` を新設し、そのActions/Pagesから版別静的ファイルを配信する。料金・独自ドメイン・アカウント認証の新規導入なしを前提にするが、アカウント上のrepo/Pages新設と公開になるためユーザー確認後に行う。約141MiBをGitへ直入れせず、Web artifactの配布方式とPages上限を公式手順で再確認してから公開する。公開URLができるまでは「iPhoneからアクセス可能」と報告しない。

[独立レビュー](independent-review.md)は修正前評価。author修正/テストは[検証報告](verification.md)に分ける。ホスティング、実iPhone/Android操作、長時間運転、端末性能、T3最終独立再レビューは別の未完項目。これはTD初期準備でありT7最終合格ではない。
