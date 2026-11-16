# 実施範囲・最終検証記録

## スキル・ツール

本文読了/適用：using-superpowersとCodex参照、brainstormingとbuilder-check参照、writing-plans、requesting-code-reviewとcode-reviewer、receiving-code-review、verification-before-completion、systematic-debugging、tool-routing、quality-gate、cloud-environment-runtimeとnetworking/packages。ユーザー候補8スキルは全て利用可能、未読を読了扱いしたものなし。writing-plansは今回の承認用変更マップ/テスト計画へ適用し、承認後の詳細実装計画・実装の実行は保留。TDD/実装スキルはT3本実装をしないため未適用。

GitHub connector、git、exec、apply_patch、Python、Godot、Xorg dummy、画像ビューを実使用。ffmpegは実行ファイル存在確認のみ。初期環境Godot4.6.3と要求4.7.2の差を確認し、公式4.7.2 ZIPを隔離取得。ZIP SHA256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` は公式release API asset.digestと一致。

Xorg起動失敗はソケット作成/接続のsandbox制限をログで切り分け、承認済み外側実行で成功。初回importのconfig書込エラーは保存先を隔離XDG_CONFIG_HOMEへ変更、最終importを同じ4.7.2で再実行。測定runnerの/usr/bin/time未搭載は外部/procサンプリングに置換し、失敗ログも保存。これらは測定環境だけの変更で製品コード修正なし。

## 要件別結果

| 要件 | 判定 | 根拠/限界 |
|---|---|---|
| 最新HEAD/差分照合、明示story ref資料6件取得 | PASS | 開始/終了ともddc2570一致、story9bc4281固定 |
| A〜Jコード/シーン調査 | PASS（静的と限定実行） | survey.md。未実装の機能は有としない |
| 1件追加時のコード/データ/再生成/保守評価 | PASS（静的） | survey追加マップ。工数は見積り |
| Godot4.7.2実描画比較 | PASS（限定診断） | city21＋market12＋ablation3試行。headless FPSや端末GPUへ代用なし |
| NPC避難AI/実T3・Web/端末増量性能 | NOT TESTED | 既存は背景crowdとfixture JSON。T3未実装 |
| A/B/C比較・推奨/不採用理由 | PASS（設計提案） | design.md、B未承認 |
| 独立3軸設計レビュー→修正→再評価 | PASS（設計） | 独立agent read-only、High2/Medium3を設計で解消。実装を検証した意味ではない |
| 実装対象/状態/保存/テスト/素材/停止条件 | PASS（案） | design.md v2。未決条件は保持 |
| 既存T1状態チェック | PASS | flow.log:37 checks、exit0、4.7.2 headless |
| 既存T2 guard境界 | PASS | manual.log:guard timing and geometry、exit0、4.7.2 headless |
| Godot最終import | PASS | import-final.log、exit0、エラー/リークなし |
| T1.5/T2.5全回帰/CI/製品export再実行 | NOT TESTED | 製品無変更の設計工程なので全てを再実行していない。過去資料の合格を今回実施としない |
| リポジトリ/既存実装保護 | PASS | detached checkout clean、原本scriptsとruntime同一、branch/commit/pushなし |
| 動画 | NOT TESTED/今回は未作成 | 未実装T3の動画は作らず、実Godot PNG3点を納品。次の実装レビューは実Godot H.264 MP4必須 |
| T3本実装/品質受入 | NOT TESTED | ユーザー承認前、実装なし |

## 納品と非公開資料の分離

ZIPはユーザー向けreport、検証harness、raw JSON、ログ、選択した実画面PNGを含む。制作者用story本文、取得した資料コピー、プロジェクト原本、巨大runtime/Godotバイナリは含めない。GitHubへの資料保存は今回行っていない。映像の直接添付済みやMP4納品済みとは主張しない。

停止条件：Bの採否、実装branch、共有Ally/Battle/Enemy変更と受入基準の承認、NPC-only上下経路/人数/配置/失敗閾値の判断が揃うまで本実装しない。T2の既承認方式を再承認対象にしない。
