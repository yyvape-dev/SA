# T3既存コード・シーン調査（ネタバレなし）

## 来歴と権限

開始時GitHub get-refとgit ls-remoteの双方で実装HEAD=`ddc257067b82f0c796cdbc9c1becc46f7bc7a12e`を再取得。指定起点と一致、追加差分なし。資料は別ref `story/sa2-chapter1-20261106`、取得SHA=`9bc4281d75bff3e3ddb39e7e97d1ad0144c45bf3`のgit showで取得。/workspaceには当初checkoutなし。`sa2-t3-source`は独立したdetached調査checkout、`sa2-t3-audit/runtime`は測定用複製。GitHubへ書込/branch作成/commit/pushなし。

必読6資料を取得・参照。story本文は制作者資料として参照のみ、台詞/未公開展開を本報告へ転載しない。新しいユーザー指示と引き継ぎ冒頭のT3ゲートが過去のT2未着手記述より優先。同じT3 B案の承認記録は見つからず。既承認はT2の独立Manual/回避兼用guardと既存戦闘流用で、T3方式の承認ではない。

GitHubコネクタによるref/ファイル読取とCLI clone/fetch成功。書込み権限は今回不要なのでNOT TESTED。CLIはsandbox内proxy到達失敗、承認済み外側実行で読取成功。最初のbranchesエンコードURLはconnectorのINVALID_ARGUMENTで、正しいgit/ref APIへ切替。権限不足やrepo不存在と誤診しない。

## A〜Jの現物

全パスは実装SHA固定の `sequel/` 以下。行番号は調査時のもの。

| 項目 | 現状/根拠 | 実行証拠と不足 |
|---|---|---|
| A 街の直接スポーン | **あり**。main.gd:133-161で同じ街ルートにBattle/Player。battle.gd:161-176 `_physics_process`→`_spawn_wave`、:204-229 `spawn`。通常街は初回3体、最大7。backtownはmain:162-166でauto_spawn=false | 複製main.tscnで既存Battle.spawnにより2/10/30体を同じLevelに生成・実描画。C2イベントトリガーは未実装 |
| B 探索/戦闘状態 | **契約のみ一部あり**。sa2_flow_state.gd:10-13 STREET、:52 `enter_battle`、:63 `finish_battle`。T2はINSTANCEを接続、通常mainはFlow未接続 | T1既存37チェックPASS。ただしSTREETの状態契約テストはC2プレイアブル完成を意味しない |
| C リリィ手動 | sa2_t2_lily_manual.gd:29 setup、:39 guard_candidate、:50 attack_press、:67 dodge、:93 physics。移動/通常5攻撃/回避/guardとAllyのhit frame再利用可。T2Host:54-64でmain.player/battle.player差替え、ally=nullで二重被弾防止 | 既存guard境界テストPASS。ManualはAllyのprivate `_nearest/_physics_process/_show`と辞書へ依存。スキル入力/地形solver/汎用Leaseはなし。T2Host全体のコピー再利用は非推奨 |
| D NPC避難 | main.gd:398 `_build_crowd`で11 Sprite3D、:348-356でx往復/上下揺れ。:1683 `_bt_npc`とBT.PEOPLEは固定立ち位置 | 実描画で背景住民あり。避難対象stable ID、誘導入力、安全地点、経路、safe判定、保存なし。110体測定は背景crowd更新だけで避難AIではない |
| E ターゲット | battle.gd:269 `_attack_from`はenemies名簿だけ、Ally:143 `_nearest`も名簿のみ。enemy.gd:155以降はbattle.playerへ追従、攻撃時はplayer/allyだけ | NPC/設備が名簿にない限りダメージを受けない構造。Faction/attackable flagによる二重防御はなし。名簿汚染・仲間参照二重登録・機械外IDをT3境界で防ぐ必要。人物や設備全件をenemiesへ入れない |
| F 床/階段/遮蔽 | main.gd:518床、:614 `_slab`、:628 `_build_piece`、:1734階段はMesh。Player/Enemy/Manualは座標加算とX/Z clamp。攻撃もX/Z距離のみ、y・壁ray判定なし | scripts検索でCharacterBody/StaticBody/CollisionShape/Navigation/Area3D等の使用なし。描画階段/前景の透過/遮蔽検査は通行・攻撃遮断ではない。上下移動・救助経路の本実装はNOT TESTED |
| G 保存/再入場 | Flow v1はmode/event/座標/完了/attempt/result/会話行。T2:68-93モード別復帰、:306-329探索復旧。progress.gdは別sa2_save.json | T2.5資料の勝敗/完了記録修正は現物確認。NPC/柵/敵ID/避難flag/HPのsnapshotなし。Flow.save_toは直接WRITE、呼出側T2は戻り値無視。複数保存のtransactionなし |
| H 汎用化 | Flow.VALID_EVENTSとenter_battleのC1-06分岐、T2.EVENT_ID/2体/HP/画面座標が固定。DBはID→JSON汎用、UIも再利用可 | 会話本文はJSON分離済み。T3は小さなEncounterDefinitionで規則を外出しすべき。全T2移行や全イベントDSL化の必要性までは証明されない |
| I ゲームループ/描画 | Battle分離O(N²)、各敵apply_light O(glints)、Ally nearest/範囲判定O(N)、攻撃O(N)。反射Sprite/影/HPbarと個別material、FX複数ノード | 実描画比較はperformance.md。ソフトウェア描画のみ。敵の分離micro測定は描画frameの主因を特定するものではない |
| J T2.5残債 | 完了signal＋60秒unscaled待機は実装済み。main._load_fx/_load_ally、districtのpack取得/参照寿命、固定UI/入力参照差替え/結果時敵停止/個別イベント固定値が残る | タイムアウトはHTTP取消ではない。late callbackの世代管理、scene移動時の取消、Web低速/メモリピーク未検証。T2.5回帰合格を増量性能合格へ拡大解釈しない |

## シーン構造・素材ロード

main.tscnとsa2_t2_playable.tscnは各Node3Dルート＋script参照だけ。街・Battle・Player・Ally・Fx・UIはコード生成。build_city()は既存Levelを破棄して再生成し、leave_dungeonもbuild_cityするため、T3の「同じ街保持」へそのまま使えない。T2は演習床を追加し、Ranaを隠してAllyを手動化、勝利時に参照を戻す方式。

既存street候補はcity_block1（大通り）とbacktown_block（市場候補）。backtownは描画上の階段/上階があるが、戦闘帯は `ROOM_X=(-24,24), BELT_Z=(-2,2)`、FLAT=true。正式なC2-09の経路/機械初期位置/避難安全地点はデータとして存在しない。

District.ensureはd1/dg1/fx1/al1をWeb HTTPRequestで取得→メモリbody→一時PCK→load_resource_pack(false)。同version/cache時は省略、失敗は1回再試行。asset量に応じたpack細分、同時ensureの重複要求共有、キャンセル/HTTP deadlineはなし。Ally/Enemyはページ初使用時loadとローカル辞書cache。Godot自体も同一pathのResourceを共有するため、30体で30枚の同一atlasを毎回複製するわけではない。異種素材/別ページ増は別の負荷。

## 1件追加時の変更マップ（現状、静的追跡）

| 追加物 | コード変更/データ追加/手作業 | 再生成・配布・結合 |
|---|---|---|
| 敵の種類1 | assets/foe/foe.jsonにwalk/atk* clips・durs/hit/fps、画像。Enemy.HEIGHTにkey、make_foes.py KINDSや新generator、出現選択Battle._spawn_waveまたはDungeon._spawn_waveのリスト変更。新攻撃行動ならEnemy分岐 | アトラス/metadata生成と目視、import/PCK/Web再export。高さ・素材パス・波の種類がコードへ結合。新機械を既存兵のkindで偽装する恒久方式は避ける |
| 同時敵数1増 | 通常街battle._spawn_waveのn/cap、T2はx配列・kills>=2・HUD、Dungeonは独自spawn定義 | 同一種なら素材再生成不要、スクリプト配布再export。数の定義と勝利条件/表示が別々で手動同期が必要。T3はrequired IDsから算出を提案 |
| 画像/アニメ1 | NPC_KEYS、Lily JSON.pages/clips、foe JSON、FX._tex/FX2D._load_books/呼出名、街piece/BT配置等。全画像共通の一元カタログはなし | import必須。Lily pack_lily.py・tip解析/切抜き、街の形変更ならguide撮影/paint適合/glints再生成。export_presetsのDistrict export_filesは全件列挙、対象packと版更新/再ビルド。backtown artは本体Web excludeに入り専用packが見当たらず配布欠落を要検証 |
| 音声1 | 現sequelにogg/wav/mp3なし、AudioStreamPlayerによるゲーム音連携も検索上なし | 再利用可能なsound registryは未確認。音源import/再exportに加え最小の再生/取消/音量所有権の設計が必要。ファイルを置くだけでは鳴らない |
| NPC/避難イベント1 | 背景ならNPC_KEYSやBT.PEOPLE/STALLSに追加、_build_crowdの11固定値変更。避難は実装なし | 画像流用可。避難target ID/waypoints/safe/restore定義とcontroller追加が必要。現状はイベントごと独自コードになりやすい |
| 会話/イベント1 | 会話はdialogues/ja/ID.jsonだけ、DBはid path汎用。ただしFlow.VALID_EVENTS、enter_battleの形式判定、トリガー・Host・完了処理はコード | JSONは1〜1000行/1行600字、ID重複検証あり。export *.jsonフィルタあり。本番本文は今回追加しない。新イベントにT2Host422行をコピーすると保守費増 |
| 戦闘スキル1 | Rana skills.table+ORDER/progress slots/skill_icons、新fxならBattle.player_skillやFx。Lily lily_skills.tableに加えAlly._pick_skill/sk_cd/_skill_hit、手動側はスキル入力なし | 既存clip再利用は画像再生成不要。新clipはatlas/JSON/ヒット時刻/軌跡の調整。コメントの「辞書1件だけ」は新しい発動条件/新FX/手動入力まで含めると成立しない |

素材実在件数：foe画像9（7.94MB）、Lily画像3（18.15MB）、NPC12（0.30MB）、painted9（15.96MB）、painted_bt24（22.20MB）、vfx画像22（1.50MB）。これは圧縮ソースの容量で、GPU/展開後メモリではない。

## 技術的負債の優先度

High（T3設計で対処）：一括checkpoint不足、操作/敵/ゲート/報酬/完了所有者の分散、階段/境界の見た目と通行判定の不一致。Medium：敵profileがHEIGHT/素材path/波リストへ分散、pack export_files全件手動列挙、イベントID条件分岐、UI固定座標、同期初使用load、世代取消なし。性能最適化候補：O(N²)分離、毎敵glints走査/個別material/反射・FXoverdraw。ただしT3=2体のために近傍空間分割/全描画基盤刷新を即導入する根拠はない。

## 確認した公式根拠（2026-11-08）

Godot公式4.7.2リリース（tagと公式バイナリ版一致）と4.7系列ドキュメントを取得。パッチ専用ドキュメントではない。

- https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
- https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html ：同じpathのresource共有、初使用load、Resourceデータ定義
- https://docs.godotengine.org/en/4.7/tutorials/io/saving_games.html ：JSONの型制約と個別復元責務、親子の段階復元
- https://docs.godotengine.org/en/4.7/tutorials/performance/cpu_optimization.html ：ボトルネックを測る、関数の反復計時、profilerのserver待ち時間の限界

これらはB案や任意の保存transactionを公式が保証するという意味ではない。独立ノード/Resourceに責務分離する設計の根拠と、計測の限界を参照した。
