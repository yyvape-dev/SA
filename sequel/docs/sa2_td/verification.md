# TD初期準備の検証

## 対象と判定

配布候補は **903b0b9e2c9c91151d35f3802197fc127cae469a**、clean source、Godot4.7.2公式単一スレッドWeb。iPhone 16はユーザー指定、iOS/Safari版は未確認。実機未接続のため実機判定NOT TESTED。

| 項目 | 判定 | 根拠 |
|---|---|---|
| データ契約・未知ID mapping拒否・保存probe roundtrip・p95集計 | PASS | td-contract.log、missing class RED→GREEN |
| T1/T1.5/T2/T2.5/T3/通常街回帰 | PASS | 新規24件、regression-suite.log |
| 公式Web出力・runtime JSON/フォント/event同梱 | PASS | exporterのPCK目録検証、manifest |
| 初期Web版全spot起動・probe再読込・T1送り・T3 touch開始 | PASS | 実Chromium/SwiftShader（11efda4等の先行版） |
| T2 real touch攻撃→回復待ち→回避 | PASS | 6efbe3eでattacks1/dodges1、同フレーム連打RED→正しい順序GREEN |
| 候補903b0b9全spot最終スモーク | PASS | browser-results-903b0b9.json: T1 line1、T2 attacks1/dodges1、T3 street、errors0、probe reload |
| user dir分離 | PASS（実dir/guard） | 全spot `/userfs/SA2-TD-Mobile-Spots`、他dirでは起動拒否、probe実reload |
| 既存Web saveの同origin sentinelバイト比較 | NOT TESTED | dir分離の実確認と混同しない |
| PNG目視 | PASS | 候補903b0b9の日本語ボタン/街絵/コンパクトtoolbarを実画面で確認、media/ |
| iPhone16/Safari操作・ノッチ・保存終了再開・FPS | NOT TESTED | 端末未接続、device-record.md未記入 |
| Android/長時間/増量の端末性能 | NOT TESTED | 今回の端末実測ではない |
| スマホ到達可能な公開URL | 未公開 | 既存main Pages非変更。新規公開は承認済み、repo作成403で未実施 |

Chromium156.0.8078.79 / Playwright1.62.1、844×390のtouch emulationと390×844画面を使用。これはiPhoneのSafari/WebKit検証ではない。frame時間は最大300実process間隔のwall clockを集計（ゲーム時間倍率のdeltaを使用しない）。FPSはEngine値。`loadToReadyMs`はbrowser navigationからscene-readyまで、`loadToSampleMs`は入力試験を含む。ソフトウェア描画値を端末性能・快適性の合格へ読み替えない。

## 独立レビューとauthorの対応

独立原文はindependent-review.md。修正前のHigh1（guide metadata除外）をTDのみJSON保持/PCK目録検証/実描画で対応。MediumのURL維持、dirty版識別、T0表示、実入力のassertを修正。専用custom_user_dirと起動guardを加え、実Web dirを全spotで確認した。修正後の独立再レビューは未実施であり、authorによる実行確認と区別する。端末性能や元T3の独立再レビューをこのTDレビューが代行したとはしない。

Lowのspot registry重複は既存5種のTD限定として保留。全素材packでの初回容量/ロード負担も残る。画質の独断変更なし。前回のsoftware増量測定を今回端末結果として再利用しない。

## 保存された成果物

ソース/計画/レビュー/試験スクリプトはTD branch、Web出力manifestはevidence/web-manifest.json。候補Web ZIPは **117,458,018 bytes**、SHA256 `063e58453af76e3b9c26116dc19c2257db6ec81b189380d65edcc80d10315ffb`。ZIP CRCと各ファイルSHA256を検証済み。公開Web URLではなく配布用静的ファイル一式。

GitHub CIの11efda4実行 https://github.com/yyvape-dev/SA/actions/runs/42562076749 は全体PASS。CIはnative契約/24回帰/公式Web export/artifact作成を担当し、ブラウザ入力試験はこのローカル実Chromiumで別実行。903b0b9のCIは実際の新規runを確認して追記する。

候補903b0b9の新規CI https://github.com/yyvape-dev/SA/actions/runs/42562340575 も全体PASS。native契約・24回帰・Web export・artifact uploadが成功。ビルド/runtime/testソースはこのSHAに固定し、後続の検証証拠追記は資料のみ。

## 公開工程の追加状況

ユーザー承認を受けてSA2-TD新設を実行したがGitHub側HTTP403（integrationのrepo作成権限なし）。公開用workflow/landing/厳密なZIP検証スクリプトをhosting/に用意し、検証済みZIPからPagesと同じ版別ディレクトリを生成した。作成権限が解消するまで公開URLの到達判定はNOT TESTED。公開準備のローカル試験とGitHub Pages自体の稼働は区別する。

ローカル版別URL配下でT0保存probeの実reloadとT1会話タップ送りがPASS。evidence/hosting/browser-results.json。実公開サーバーのHTTPやiPhone実機は未実施。

## 公開後の最終状態（2026-11-09 JST）

公開URL https://yyvape-dev.github.io/SA2-TD/ 。repo新設とPages初回設定は所有者が完了し、公開run42564101383がPASS。公開全WebファイルをHTTP200で取得、実デプロイmanifestのbytes/SHA256と全件一致、WASM MIMEも確認。公開入口393×852の5リンク/横はみ出しなし。公開版に対してChromium/SwiftShaderで全spot、保存probe reload、T1 line1、T2 touch attacks1/dodges1、T3 touch STREETを確認しerrors0。実画面も目視。iPhone/Safari実機と端末性能はNOT TESTED。

Releaseアップロードが接続401だったため、公開版はActions内で固定ソース903b0b9を公式Godot4.7.2で再ビルドした。旧ローカルZIPとのバイト一致は主張せず、公開版の実manifestと公開ファイル一致を検証した。証拠はevidence/published-*.json、公開側正本は https://github.com/yyvape-dev/SA2-TD/tree/main/evidence 。既存SA Pagesはlegacy/main/rootのまま確認済み。
