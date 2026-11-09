# T3 実処理の性能測定（Godot 4.7.2）

全21試行、各ケース3回、X11 / Mesa25.0.7 llvmpipe LLVM19.1.7、Compatibility、1280×720。2秒wall-clock暖機＋6秒採取、固定FPS・録画なし。各試行指標の中央値を表示。GPU実機/Web/iOS/Androidの合格値ではない。

| ケース | FPS | 平均ms | p95 ms | draw calls平均 | texture MB | sampled peak RSS MiB | frames合計 |
|---|---:|---:|---:|---:|---:|---:|---:|
| baseline | 5.72 | 174.91 | 199.51 | 295.8 | 505.0 | 804.1 | 105 |
| t3-2 | 5.75 | 173.94 | 199.16 | 326.6 | 489.3 | 791.7 | 104 |
| t3-10 | 4.85 | 206.21 | 242.40 | 511.0 | 489.3 | 798.1 | 89 |
| t3-30 | 3.44 | 290.47 | 321.01 | 955.3 | 489.3 | 810.4 | 65 |
| npc30 | 5.22 | 191.67 | 234.74 | 407.7 | 489.3 | 810.5 | 94 |
| resident24 | 5.44 | 183.77 | 202.61 | 350.5 | 502.9 | 835.4 | 101 |
| nonresident9 | 5.16 | 193.93 | 222.31 | 335.7 | 550.8 | 855.1 | 96 |

baselineは既存backtown＋兵2体をT3と同じcamera/解像度へ合わせた比較（通常版の画像/材質を維持）。t3-2/10/30は本番T3Host/Policy/Driver/HUD/EnemyProfileと同じ回転刃ノードを持つ機械、避難3人。増量機械28体は診断専用IDであり正式な勝利条件2基は変更しない。npc30は本番3人＋同じEvacuation実装の診断27人。住民は経路到達後safeスキップになる区間も含み、常時全員移動の上限負荷を保証しない。

resident24は**既にbacktownで常駐している画像24枚の追加Sprite描画**で、異種素材ロード増量ではない。nonresident9のみ、未キャッシュの異なるart/painted画像9枚をload/保持/追加描画。各試行ResourceLoader.has_cachedで9枚全て未キャッシュを確認。素材追加前後はhost更新を停止し2描画frameを待ってtexture計数を記録し、その後通常T3更新へ戻して採取。数値はdriver/resource計数で厳密なGPU VRAMではない。
nonresident9: 追加前texture計数中央値 398.3MB → 追加直後 488.2MB。同期load＋Sprite設定の中央値 217.9ms。描画/アニメの遅延upload・キャッシュ寿命も計数へ影響するため、最終サンプルのtexture差を9画像だけの純メモリ量と断定しない。

T3機械2→10→30の平均frame中央値 173.9→206.2→290.5ms。ソフトウェア描画下で増量悪化を確認。既存診断の市場2→30（181.56→322.38ms）とはcamera/敵外観/処理が異なるため直接の改善率にしない。今回baselineとT3はcamera条件を揃えたが、兵/機械の材質・形状やHUDは異なるので、差をcontroller単体コストと呼ばない。

静的候補：Battle._separate O(N²)、毎敵glints走査/個別material/反射/回転刃8歯、避難O(N)、追加の描画ノード。policyの閉鎖矩形走査は現在1件。個別AI/self CPU/GPU時間・描画/physicsの厳密な寄与分解はNOT TESTED。短い低FPS標本なのでp95/p99精度、統計的有意差、長時間/熱/通信条件は主張しない。

生値performance-final.json、runnerコマンド/環境は再現スクリプト、各ログperf-*.log。RSSは外部/procを100ms間隔で採取したサンプル最大でOS全期間peakではない。setupはシーン準備の実時間、cold import/HTTP転送時間は含まない。event数/会話数増量は今回NOT TESTED（事前監査のJSON fixture測定はactiveイベント拡張の保証ではない）。完成ゲームのFPS/メモリ/敵数上限は設定していない。
