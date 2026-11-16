# Godot 4.7.2 増量性能・拡張性レポート

## 判定

**既存コードでの限定測定は実施済み。T3の性能受入はNOT TESTED。** 実Godot/X11/OpenGL描画、ソフトウェアレンダラーllvmpipeの結果。headless FPS、Movie Makerの固定fps、スマホGPUの測定値を混ぜていない。承認済み性能目標がないため、勝手な30/60fpsやメモリ上限でPASSにしない。

Godot `4.7.2.stable.official.ed1daf0bf`（公式ZIP）。搭載の4.6.3はversion確認のみ、測定には不使用。Linux x86_64、Mesa 25.0.7、llvmpipe LLVM19.1.7 256bits、Xorg dummy、1280×720、Compatibility/OpenGL3、Dummy audio、VSync変更要求はdriver非対応警告あり。/dev/driなし、端末hardware GPUなし。Xorg/エンジンはsandbox外の同じ環境で実行。描画画像を実際に取得/目視確認済み。

## 方法と再現

調査元checkoutと別のruntimeへコピーし、bench.gdだけ追加。元のBattle/Enemy/Ally/main/素材は書換えなし。既存 `main.tscn` をinstantiate、既存街のLevelを保持、Battle.spawnで既存兵2種を生成。Rana/Allyの自動攻撃を止め、敵が自然AIで攻撃し続けるようHPだけ大きい試験sentinelにした。これはT3リリィ操作・機械や避難の試験ではない。HUDのHP比率が通常値を超えるのも測定fixture由来で製品挙動ではない。

- 全ケース：同じseed=20261108、同じplayer位置、同じ解像度/設定。各ケース3個の独立プロセスを順番に実行。2秒wall-clock暖機→6秒wall-clock採取。録画/--fixed-fpsなし。
- FPS：process_frame間の `Time.get_ticks_usec()`差を採取し、1000/平均ms。p95は各試行のソート済み標本からfloor((N−1)×.95)。表は試行ごとの指標の中央値、pooled p95ではない。
- メモリ：Godot MEMORY_STATIC、RENDER_TEXTURE_MEM_USEDと、外部Pythonによる/proc/PID/statusの100ms毎RSS。表のpeakは**サンプル中の最大**で、厳密なOS全期間peakではない。Godot内から/proc/self/statusは空だったためRSSは外部で計測。GPU VRAMではなくsoftware renderer下のtexture計数。
- setup：SceneTreeからmain.tscnロード開始→素材/敵/NPC/JSON準備まで、エンジンプロセス起動前時間やimportを含まない。OS filesystem cacheは温かい。cold起動/HTTP/pack転送時間とは別。
- draw callsはPerformance monitorのフレーム値平均。physics monitorも採取したが、Godot全physics更新の値でAI/衝突だけのCPU self-timeではない。
- micro：本採取終了後に既存Battle._separate(delta=0)を1000回呼び、平均usec/回。移動を起こさず同じ実装のpairwise検査コストを見る。frame時間へ加算しない。

実行：`python /workspace/sa2-t3-audit/spike/run_bench.py`、続いて `run_market_bench.py`。runnerは隔離runtime、Xorg :93、各env、実行引数を持つ。再現時は先に同梱spike/xorg.confでXorg起動し、Godot4.7.2でruntimeをimportする。外側X11ソケットにアクセスできる権限が必要。生値はmeasurements.json（21試行）とmarket-measurements.json（12試行）、各logs/。

## ケース

- current3：通常街の初回waveと同じ3体（自動wave自体は停止して一定数）、crowd11。通常街は将来7体まで増えるがその全waveプレイ試験ではない。
- target2/10/30：同じcityで敵数だけ変更。2/10/30は検証仮定で、完成ゲームの目標数ではない。
- npc110：背景Sprite群を既存_build_crowdで11→110へ。画面外を含む既存更新負荷。避難AI/全員同時可視/経路探索は含まない。
- asset24：既存painted_btにある**異なる24画像**を追加でload/保持し、小Spriteとして画面内に表示。ソース22.20MB、同じ画像のコピーで数だけ増やしたテストではない。全画面の高密度overdraw/アニメ/音声100種ではない。
- event100：既存C2-09テストJSONを別の100ファイル/IDへ複製し、実DB.load_eventで読み込み/検証/保持。本文の新規追加なし。baselineの2ファイルも同じfixture方式。**active event controllerは既存にない**ため100イベント進行/探索の負荷証明ではない。
- back0/2/10/30：TOWN=backの既存市場候補でも実行。既存固定NPC/建築を保持、動的crowd11。通常backtownはauto_spawnなしなのでback0が現状baseline。

## 実測一覧

別紙performance-table.md。各試行exit 0、AUDIT_RESULTと実画面PNGを取得。p95は1試行約17〜36フレームしかなく、3回合計でも57〜105標本。**短時間・低fpsで変動が大きい診断**であり、precisionや統計的有意差を主張しない。長時間p99/GC/熱/端末の測定はNOT TESTED。
| ケース | 敵 | 動的crowd | 追加異種texture | 読込JSON | FPS中央値 | 平均ms中央値 | p95 ms中央値 | draw calls平均中央値 | texture MB中央値 | sampled peak RSS MiB中央値 | setup ms中央値 | frames合計 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| current3 | 3 | 11 | 0 | 2 | 5.05 | 197.83 | 246.03 | 118.8 | 481.4 | 773.1 | 1396.1 | 89 |
| target2 | 2 | 11 | 0 | 2 | 5.43 | 184.17 | 209.78 | 115.5 | 456.0 | 721.4 | 1371.0 | 96 |
| enemy10 | 10 | 11 | 0 | 2 | 4.40 | 227.37 | 280.82 | 140.7 | 503.7 | 781.5 | 1278.9 | 79 |
| enemy30 | 30 | 11 | 0 | 2 | 3.36 | 297.79 | 355.81 | 202.3 | 503.7 | 788.0 | 1303.2 | 60 |
| npc110 | 2 | 110 | 0 | 2 | 5.14 | 194.55 | 208.25 | 133.5 | 456.0 | 726.4 | 1275.1 | 94 |
| asset24 | 2 | 11 | 24 | 2 | 5.26 | 190.02 | 210.03 | 139.5 | 525.8 | 785.5 | 1637.9 | 96 |
| event100 | 2 | 11 | 0 | 100 | 5.07 | 197.28 | 210.47 | 115.5 | 456.0 | 722.1 | 1293.7 | 93 |
| back0 | 0 | 11 | 0 | 2 | 5.81 | 171.98 | 195.81 | 202.8 | 424.7 | 698.5 | 1412.3 | 105 |
| back2 | 2 | 11 | 0 | 2 | 5.51 | 181.56 | 201.31 | 209.3 | 478.2 | 750.3 | 1473.5 | 98 |
| back10 | 10 | 11 | 0 | 2 | 4.03 | 248.41 | 296.46 | 234.2 | 526.0 | 807.9 | 1329.5 | 74 |
| back30 | 30 | 11 | 0 | 2 | 3.10 | 322.38 | 374.37 | 295.7 | 526.0 | 804.9 | 1414.7 | 57 |

## 実測から言える範囲

1. city敵2→10→30で平均frame中央値184.17→227.37→297.79ms（約+23%/+62%）、draw calls115.5→140.7→202.3。市場敵0→2→10→30でも171.98→181.56→248.41→322.38ms。増量で悪化する傾向は見えるが、2基のT3合格や30体の製品上限を意味しない。
2. 同じ敵atlasを増やしてもtextureが人数比例で増えない。2→10の増加には初使用される敵攻撃ページも含まれ、10と30は同じ約503.7MB(city)。異なる24画像追加ではtexture計数約456.0→525.8MB（+69.8MB）、追加load中央値306.81ms、setup約1371→1638ms。圧縮ソース容量と展開メモリは別。pack分割/必要textureの事前ロード/参照解放の設計価値がある。
3. crowd11→110はdraw calls約+18、MEMORY_STATIC約+1.09MB、平均frame約+5.6%。FPSの試行範囲は重なるため軽微な差の断定はしない。避難AIと同時100人可視は未測定。
4. JSON2→100のload+validateは中央値2.65→5.50ms、MEMORY_STATIC約+0.24MB。短いfixtureだけの結果で、1000行×100件やactiveイベントの速度を推定しない。1件選択ロードできるDBは流用し、毎frame全会話走査を追加しない。
5. `_separate` microはcity敵2/10/30で約0.91/27.04/232.92usec、marketでは1.01/29.82/248.90usec。静的pair数1/45/435に対応して増加。**30体の分離約0.25msが300ms超の描画frame全体を支配する証拠ではない**。空間分割をT3=2体へ即追加する根拠にしない。
6. physics monitor中央値はcity2/10/30で13.20/36.00/36.57ms、market0/2/10/30で0.10/12.31/35.53/31.02ms。非単調で、サーバ待ち/低fpsの複数tick/自然な攻撃タイミングも混ざる。AI・当たり判定の個別ボトルネックと呼べない。

## 静的推論と未測定

- 静的：敵ごとにsprite/影/反射/HPbar、各material更新、glints全件走査、背景前景とFXの重なりがある。Battle._attack_fromとAlly.nearestは敵数線形、分離は二乗。NPC背景更新も線形。これらはソースからの計算量で個別CPU/GPU profile値ではない。
- NOT TESTED：hardware GPU別FPS/実GPU時間、iPhone/Android/WebGL、HTTP低速/IndexedDB、cold import/起動、長時間peak/thermal/p99、音声・アニメ異種100件、避難AI・T3controller・機械・境界solver・save増量、T3実際のcombat/VFX操作負荷。
- 共有リソースと描画ノードを増やす負荷、異種素材resident量と転送量、保存/会話parseとイベント処理を別評価する。B案の選択だけでは描画は軽くならない。A/B/Cの性能差は全方式が未実装なのでNOT TESTED。

## 次の測定ゲート

承認後にT3実装と専用負荷fixtureで、同じ2/10/30＋実避難NPC数/増量＋必要素材resident量をこの環境と端末Webで測る。判定端末/解像度/最低許容性能はユーザー合意後に設定。負荷が問題ならまず表示対象・反射/FX・ロード発生点をprofileして差分最適化し、画質を独断で下げない。専用コントローラの追加だけで大幅高速化を約束しない。

## 描画寄与の追加切り分け（3試行、実描画）

同じback0のsetup/更新/texture参照を維持したまま `scene.level.hide()` の1条件だけ変更（bench_noworld.gd / run_ablation.py）。背景/固定NPC/動的crowdの描画をまとめて外すが、その更新と参照は保持し、Rana/Lily/UIは残る。FPS中央値5.81→13.75、平均frame171.98→72.75ms、p95中央値195.81→87.70ms、draw calls202.8→50。texture計数424.7MBは同一。描画を減らすと約99ms改善したので、この環境で街描画の寄与が大きいことを実験で確認した。個別shader/GPU/overdrawのself-timeはNOT TESTED。レベルを消すことは製品最適化案ではなく診断であり、画質変更はしていない。生値ablation-measurements.json、追加3試行合計252フレーム。
