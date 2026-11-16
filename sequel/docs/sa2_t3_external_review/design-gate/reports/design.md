# SA2 T3 C2-09 設計ゲート案 v2（独立レビュー反映・承認待ち）

2026-11-08 UTC。ネタバレなし。本書は実装済みの説明ではない。T3本実装なし。末尾v2追補を含めて独立レビュー完了、全指摘は設計レベルで解消。共有変更の承認範囲にはBattle/EnemyだけでなくAllyのopt-in移動hookも含む。

## 結論・承認対象

推奨は **B：街中イベント専用コントローラ＋既存Battle**。戦闘・リリィアニメ・JSON会話を流用し、避難、開始前チェックポイント、二重成功条件、操作の借用と返却を専用の小さな部品に置く。T2プレイアブル422行の複製、main 2555行へのイベント別分岐追加、全ゲームの状態基盤置換は避ける。

起点は `feat/sa2-t2-sequel-integration-20261108` / `ddc257067b82f0c796cdbc9c1becc46f7bc7a12e`。提案する実装ブランチ名は `feat/sa2-t3-street-encounter-20261108`（未作成、承認対象）。既存T2シーン、T2スクリプト、mainブランチ、SA1、正式本文、Claude指示は変更対象外。共有Battle/Enemyへの下記の後方互換変更は承認対象に含む。

## A/B/C 比較（静的評価。工数は見積り）

| 観点 | A 既存を最小拡張 | B 専用制御＋既存戦闘【推奨】 | C 全状態を共通データ駆動へ整理 |
|---|---|---|---|
| 流用 | Battle/Ally/街/UI/Flowを流用、T2派生コードに責務集中 | 同じ中核を流用。新規は避難・保存・所有権。行数比率は未算定 | 描画・戦闘資産流用、状態/呼出元の移行が大きい |
| ノード | Main派生の巨大なT3ルートにイベント処理 | Main派生Host + StreetEncounter + Evacuation + 操作アダプタ | 共通World/State/Encounter/Actionレジストリへ既存シーンも移行 |
| 状態/保存 | 早いが分岐・復旧手順がT2/T3別々に増加 | イベント単位snapshot、遷移を一箇所で検証。中程度 | 新schema移行とT1/T2/成長保存の整合が高難度 |
| NPC安全 | 個別チェック漏れを防ぐ責任がHostに混在 | 戦闘名簿と避難名簿を分離。境界で機械IDを検証 | faction/権限共通化は可能、全呼出元の移行リスク |
| 追加コスト | 各イベントでコード/分岐増、敵/素材既存制約も残る | 同じ型のイベントは定義と経路を追加。新動作のみコード | 移行後は低下するが最初に汎用DSL等を設計する負担 |
| 性能 | 同じ描画・O(N²)分離。Aというだけで速くならない | 同じ中核負荷。イベント全件を毎frame走査しない設計 | データ駆動化だけで描画・分離コストは消えない |
| テスト | 全Main起動に依存しやすい | 成功条件/保存/避難/入力所有権を個別検証＋実結合 | schemaと全旧シーン移行の広い回帰が必要 |
| 初期/保守費 | 小→反復時に高 | 中→同型追加は低〜中 | 大→移行完了後は低〜中、型増加で再設計もあり得る |
| T4〜T7 | 素材/HUD/会話追加がT3本体に蓄積 | 素材manifest、会話ID、HUD signalを独立接続 | 将来の自由度は高いがT4〜T7を基盤移行に従属させる |
| 撤退 | 最初は容易、保存分岐増で難化 | 専用シーンを外せる。共有APIはopt-in既定値維持 | 保存/入力形式が広域変更され最も難しい |

Aは調査スパイクには適するが、住民・保存・演出の専用実装複製が次のイベントで増えるため不採用。Cは既存Battleの中核を捨てる根拠がなく、T3のために既存T2を移行する費用と回帰が大きいため不採用。Bにも小さなデータ定義を採用するが、これは全体共通化Cを行う意味ではない。

## ファイルと責務（提案、未作成）

| 対象 | 内容 |
|---|---|
| 追加 `sequel/sa2_t3_playable.tscn`, `scripts/sa2_t3_host.gd` | main.gdを継承し、既存街を保持。通常auto_spawn/ゲート/報酬をT3モードで明示管理し、開始時参照を保持するHost |
| 追加 `scripts/sa2_street_encounter.gd` | 一つのイベントの遷移・登録機械ID・成功条件・一度だけのcommit。会話本文は保持しない |
| 追加 `scripts/sa2_control_lease.gd` | Rana/Ally/Manual/camera/UI/cutinの参照・process・可視・入力状態を取得/返却。指IDと押下状態もリセット |
| 追加 `scripts/sa2_evacuation.gd`, `scenes/sa2_evacuee.tscn` | 永続ID付き避難対象と経路進捗。背景crowdはそのまま別名簿。安全到達signal、経路停止/再開/restore |
| 追加 `scripts/sa2_street_checkpoint.gd` | v1 envelopeの読込検証、一時ファイル→置換、前回正常版保持、失敗時はlive状態を変えない。Flowは内包して既存v1を温存 |
| 追加 `scripts/sa2_encounter_definition.gd`, `events/C2-09.tres` | encounter ID、map ID、機械2体stable IDとprofile/位置、避難対象/安全点/経路、会話ID、禁止領域/承認済み結果フラグ。必須ID・参照を開始前検証 |
| 追加 `scripts/sa2_enemy_profile.gd`, `enemies/cutting_machine.tres` | 表示高さ、atlasルート/clip、速度/HP/攻撃予兆の定義。1機種を2基共有。正式美術はT4 |
| 変更候補 `scripts/battle.gd::spawn`, `scripts/enemy.gd::setup/height/_ready/_show/_tex` | optional profile経由で新機種の高さ/clip/pathを供給。未指定は既存の辞書・HEIGHT・素材パスと完全同じ。敵数増加の全面最適化は別ゲート |
| 追加 `scenes/sa2_c2_09_routes.tscn` | 既存街へのMarker3D/経路/禁止領域の重ね合わせ。街本体の作り直しはしない |
| 既存 `scripts/sa2_t2_lily_manual.gd` | setup/attack/dodge/guard/既存Ally callbackを再利用、改変しない。外側のLeaseで毎回生成し解放する |
| 既存 `scripts/sa2_flow_state.gd` | STREET定義/遷移を内包して再利用。T3用payloadは外側で管理。既存T1/T2保存の自動上書き・移行はしない |
| 既存 `scripts/sa2_dialogue_database.gd`, UI scene | JSON会話を参照。正式台詞接続/改稿はT5。テスト台詞はJSON fixtureのみ |
| 変更候補 `export_presets.cfg`、T3専用CI、追加tests | 機械/イベント/必要街素材の依存をpackへ同梱。T2 workflowの置換はしない |

上記は設計上の候補であり、最終的なAPI署名・行差分を確定した実装計画ではない。承認後のwriting-plans工程で署名・テストを固定する。

## シーン保持と地形の制約

Hostの子は既存Level、Battle、Player、Fx、TouchUI、Hudに、Encounter/ControlLease/Evacuationを追加する。探索→戦闘→探索でLevelのinstance IDを変えず、build_city/build_backtown/leave_dungeonを呼ばない。正常な探索はランダム敵湧き停止、事件後も停止。以前の自動湧きを無条件復旧しない。

既存の市場候補はbacktownだが、階段は描画Meshだけで上下移動/経路判定はない。**C2-09の上層→安全階段→下層の接続は不足**。最小案は避難NPC専用の高さ付きwaypointと接続・通行許可、リリィと機械は同一の下層戦闘帯で戦わせる。上下階を自由に歩ける探索システムは今回の提案に含めない。この限定で要件を満たすかユーザー判断が必要。歩ける上層自体がT3受入に必要なら、地形移動設計を別途行うまで停止する。

経路と戦闘帯は画面上の床・階段・閉鎖路と一致させる。設備は非ターゲットだが、通り抜け防止の禁止矩形/通行segmentは別責務。突進・回避・ノックバックを含む全移動後に帯/禁止領域への補正を適用する。高さの違う床への攻撃を許さない。見た目だけの遮蔽を攻撃遮断済みと呼ばない。

## 状態・成功・失敗・再起動案

`EXPLORE → PREPARE（入力停止、素材・定義検証）→ DIALOGUE → SAFE_CHECKPOINT → STREET → RESULT → POST_DIALOGUE → EXPLORE`。

PREPARE/SAVE失敗では敵を発生させず、探索に留めて再試行可能なエラーとする。SAFE_CHECKPOINTはNPCが動き出す前に一括取得し、保存成功後のみ戦闘開始。Flowのdialogue_finished→EXPLOREからSTREETへの間はEncounterだけが遷移所有者になる。

成功は `required_machine_ids全て停止 AND required_evacuee_ids全てsafe`。kill数加算だけに依存せずID集合で重複signalを無視。機械停止だけ/NPC避難だけでは継続。結果確定時は敵・入力・誘導更新を停止し、勝敗を同frameに二重commitしない。勝敗同時発生は失敗優先を提案（受入条件に含めて承認）。防御は既存T2の回避兼用guardを流用、ホールド防御の追加は行わない。

保存envelope案はschema_version、map/encounter/definition_version、phase、Flow辞書、checkpoint、committed_result。checkpointには操作主体/両actor位置・向き、イベント管理敵のID/初期状態、避難対象ID/位置/waypoint/safe、関連柵/閉鎖路/イベントフラグを含む。タイマー・warn・FX・入力指ID・ノード参照は保存せず、世代tokenで古い完了通知を破棄する。

失敗は全イベント所有物を停止/片付け、敵名簿から除去、checkpointを検証して一括復元、操作を返却し安全地点へ戻す。再挑戦は明示入力で新attemptへ（T2の自動即再開は流用しない）。再起動中のSTREETは同じ安全checkpointへ戻す提案で、途中HP/攻撃時刻を継続しない。RESULTの勝利は完了/封鎖状態/避難safeを同じpayloadでcommitし、再起動・再入場でも敵再湧きなし。事後会話のカーソルと開始前会話を区別する。

成長 `sa2_save.json` は別契約のまま。T3機械停止は通常gain_expへ流さず、T3から成長saveを書かない（報酬仕様は今回追加しない）。これで失敗巻戻し時の経験値重複を防ぐ。既存T2ファイルは読込/上書きしない。

## 受入テスト案（実装後に実施、現状NOT TESTED）

1. 同一Level ID、同一背景/座標で探索→開始。二重トリガー/ロード遅延中操作/ゲート遷移を遮断。機械だけ2 stable IDがBattle.enemiesへ入る。
2. リリィ手動移動/通常攻撃/自然な予兆/回避/guardをキーボードとViewportタッチ経路から確認。Rana/Ally AIの二重更新や二重被弾なし。戻った後に通常Rana・Lily AIとUIが動く。
3. 住民・人間・設備・縁へ通常/円/帯/only攻撃を向け、対象HP/状態不変、追尾/ロック不可を確認。別階への攻撃・閉鎖路通過・階段からの脱落なし。
4. 機械先/避難先の両順序、同frame、重複kill/safe、無効ID、最後のNPC経路停止を試す。両条件成立のみ成功。必要人数0を誤ったauto成功として許可しない。
5. リリィ敗北、最後の停止と敗北が同frame、誘導中失敗、再挑戦20回。敵/NPC/柵/flags/操作/FX/タイマーをsnapshotと比較。ノード/接続/メモリの増え続けがない。
6. PREPARE、checkpoint直後、STREET、敗北RESULT、勝利RESULT、事後会話、探索完了でプロセス終了→別プロセス起動。進行/封鎖/二重湧き/カーソルを確認。破損/旧version/未知ID/書込失敗/途中ファイルを検証し最後の正常saveを保持。
7. 既存T1/T1.5/T2/T2.5/素材待機/通常街/ダンジョンの回帰。T3 branchのGodot import/エクスポートJSON・profiles・font同梱確認。Web IndexedDB・低速pack・実機は別判定。
8. 本報告と同じ負荷シナリオで再測定。性能目標値は端末/配布方式とともに合意するまで独断で設定しない。

## 素材流用・必要追加

流用：Lily idle/walk/run/hit/5攻撃atlasとJSON、Rana探索、既存街/路面/看板/前景/既存NPC12枚、BattleのHP・warn・FX・既存会話Control。背景NPCの画像を避難対象にも流用できるが行動/IDは新規。

追加最小限：機械1種の識別可能な外観/回転刃予兆/停止状態（同種2基）、避難対象の識別と安全地点/経路marker、危険境界/柵と当たり判定データ、誘導開始・避難数・機械停止数・再試行のHUD。NPC人数と場所は未確定。正式背景はT4、正式会話/演出はT5、音/仕上げHUDはT6。既存プロジェクト内にogg/wav/mp3は見つからず、音響流用は未確認。大立ち絵・新規大量素材の発注はしない。

## Godot実画面検証と停止条件

Godot 4.7.2、同じ街を連続撮影し、開始前→誘導→自然な機械攻撃→リリィ回避/攻撃→2条件→事後探索、別takeで失敗/再起動を示す。1280×720に加えスマホ横比率で、床接地・階段・遮蔽/予兆・NPCと機械の識別を確認する。Movie Maker固定fpsは演出証拠専用、実fps測定は固定fps/録画なし。必要動画はH.264 yuv420p faststart MP4、全デコード・実画面目視後にファイル納品。端末GPUとllvmpipeの結果は分ける。

停止：方式/branch/共有変更/受入基準の承認なし、上層移動の要求が限定案と異なる、NPC人数/安全閾値が未定のまま本番確定しそうになる、save破損/混在復旧、非対象へのdamage、既存T2回帰、Critical/High未解決、素材pack欠落。今回の設計完了をT3実装完了と扱わない。

未決事項は、限定経路方式の可否、避難対象数/配置、安全失敗閾値（HP0以外を必要とするか）、実装ブランチ/共有変更範囲、実機性能目標。推奨既定案はNPC経路が完了するまで戦闘状態を維持し、HP0のみ失敗、再起動は開始前へ戻すこと。正式本文や事件後通行規制は変更しない。

## v2：独立レビュー後の具体化（v1より優先）

### H1対応：共有戦闘状態と復元分類

保存は位置だけでなく次の明示的分類を持つ。取得は戦闘前の安全状態に限定し、取得中にenemy/actor/避難更新を止める。

| 分類 | 対象と復旧方針 |
|---|---|
| checkpointから復元 | Battle.hp/hp_max、ult/ally_ult、ult_gain/ally_ult_gain、hits_taken、atk_mul/foe_hp_mul/foe_dmg_mul、両actor位置/向き、Rana skill_cdとLily sk_cd、関連イベント/NPC/柵/通行フラグ、camera/操作参照の所有者。安全checkpointのhp>0を検証 |
| 正規安全値へreset | freeze/shake/combo/combo_t/cine/cam_zoom/cam_focus/bg_dim/dim_hold/chroma、actor.state=move、clip=idle、t/hit_i/ev_i=0、inv/flash/kb/kx/knockback=0、target=null、sk_id/sk/atk等一時辞書、dash/ghost/charged/ult進行、Manual dodge_left/move_in、UI stick/pressed/finger状態。残像/warn/FX/旧敵ノードと接続を解放 |
| 別の永続所有者 | growth saveは読取のみ、報酬は追加せずT3撃破ではsave/add_expしない。Flow.attemptsは再挑戦確定時のみ+1、途中失敗の同一復旧を二度行って増加させない |

安全値へのresetは「戦闘中そのまま再開」ではなく、開始前安全状態へ戻す契約。新Manual.setupはactor.cd/invを上書きするので、準備時はsetupを先に行い、checkpoint由来のcooldownを最後に適用する。再起動・live失敗とも同じrestore関数を通す。restore前にpayloadの型/範囲/必須ID/phase整合/HPを検証し、一時状態として構築できてからliveへ反映する。勝利の探索復帰も戦闘一時値をresetし、完了snapshotのactor位置/住民safe/封鎖を適用する。HP/ゲージの扱いはcheckpoint値へ戻す案を承認対象に含め、独断で新報酬や全回復仕様を足さない。

### H2対応：入力/移動/攻撃の具体的な境界

**追加候補 `scripts/sa2_street_combat_policy.gd` と `scripts/sa2_street_manual_driver.gd`、共有 `ally.gd` のopt-in hookを変更範囲へ追加する。** T2 Manualのソースは無変更。敵・味方の全移動を後からHostでclampするだけの案は撤回する。

T3 policyのインターフェース案：`resolve_motion(actor, previous_position, desired_position) -> Vector3`、`allows_damage(source, target, attack_spec) -> bool`、`constrain_current(actor) -> void`。非T3はpolicy=nullで従来動作のまま。resolve_motionは開始点から目標へのsegmentを許可通路矩形/禁止矩形と照合して最初の境界までに止め、瞬間移動で柵を越えない。戦闘actorは同一の下層combat floor IDに登録し、別floorへのdamageは拒否。T3では攻撃経路が閉鎖境界/承認された遮断物を横切る場合もdamageを拒否。NPCをdamage対象名簿に登録すること自体を拒否する。

適用順序：

1. LeaseはManual自身のphysicsを停止し、T3Driverだけが毎tick入力→Manual._physics_processを1回呼ぶ。移動/回避時は呼出前位置を保持し、返却直後にresolve_motion、座標と歩行表現を整合させる。攻撃/hurt時はManualからAllyへ処理が委譲される。
2. 共有AllyのT3用optional motion hookは、攻撃 `_atk_extras` 内のdash移動直後かつ `_hit_new`/legacy hit callback前にresolve_motionし、hurtノックバック直後も適用。T3ではskill/ultを起動しないので、この版のhookは通常攻撃/hurtに範囲を限定。将来手動skill追加は別レビュー。policy未指定で通常Ally/T2の順序・結果を変えない。
3. 共有Enemyはwalk/stun移動後、`_start_atk`/warn生成前に同じoptional motion hookを適用。敵攻撃解決前にも現在位置を正規化する。profile変更だけではこの責務を満たさないため明示的な共有変更として承認対象にする。
4. 共有Battleは `_attack_from` の入口でsourceを正規化し、各対象の `take_hit` 直前にallows_damage。`only`/circle/bandを含め全shapeがこのgateを通る。pull/kbの移動先もpolicyで解決。`enemy_hits_player`もplayer/敵位置と対象許可を再検証。EnemyからAllyへの直接hurt分岐はT3でbattle.ally=nullとし、登録playerのLilyへ一本化。通常Ally向けの分岐は既定のまま。
5. Collider的な画面遮蔽と、攻撃遮断を行う幾何境界は別データ。見た目の全propを障害にするのではなく、C2の通路/柵に必要な境界だけ定義する。受入ではdash/押戻し/敵ノックバック/only攻撃/別階の同x-zを狙い、hit前に拒否されたことを検証する。

同じ街の全域自由移動を新設する提案ではない。既存街を維持し、NPC高さ付き避難routeと下層戦闘帯の許可範囲だけを実装する候補。実際の座標とgeometryの適合は承認後の小規模実画面確認で決める。上階をリリィが自由に歩く要望へ変わる場合は停止する。

### M1対応：保存成功まで結果確定を公開しない

`STREET → RESULT_PENDING → RESULT_DURABLE → POST_DIALOGUE/EXPLORE`を明示。RESULT_PENDINGで戦闘と誘導を凍結し、candidate結果と完了後snapshotを一度構成する。保存先案 `user://sa2_t3_progress.json`（tempとbackupは同じdirectory）。Flow.save_toは使用せず、T3 envelope全体を専用writerで保存する。

writerはopen/write/flush/get_error/close後の読戻し検証、backup維持、rename/replaceの返値を確認。現行ファイルを破壊してから代替を検証する順序は禁止。最終置換前の失敗ではdurable checkpointを維持し、結果保存の再試行UIだけを許可する。成功演出後の会話/探索解除/完了公開はdurable化後。同じcandidateの再試行でkill/報酬/会話遷移を再実行しない。保存が失敗したまま終了すれば、次起動は最後の正常checkpointから復旧する。

起動時はcurrentをschema/phase/Flow/定義ID整合まで検証し、有効currentを優先。無効/欠落なら有効backupへ復帰。tempだけを新しい完了として採用せず、破損したcurrentを即新規ゲームで上書きしない。書込不能なら以前の保存を保持して通知、開始もcommitもしない。Webのflush/renameがIndexedDBへどの時点で永続化されるかは実装後のブラウザ強制終了試験で検証し、OSレベルの原子性だけでWeb耐障害性PASSにしない。

### M2対応：限定されたデータ契約と増量の限界

EncounterDefinitionはschema/definition version、map ID、イベントID、機械stable IDs/profile/初期transform、evacuee IDsとroute ID、safe marker IDs、dialogue IDs、完了flagの許可リストのみ。条件語彙は「指定機械停止AND指定住民safe」に限定し、任意スクリプト実行/汎用DSLは導入しない。

Routeはnode ID/Vector3/floor ID、安全node、隣接edge（from/to、開通条件flag）から構成。ID重複/未知edge/node参照/到達不能safe/閉鎖領域交差/required人数0を開始前検証。上限はメモリと入力検証の防御的制限として実装計画で明示し、完成ゲームの敵/NPC上限と混同しない。

EnemyProfileは既存AIと互換なwalk/atk* clip、各frameのatlas rect、walk fps、攻撃durs/hit index、height/path、HP/speed/damage/reach/lane。必須clip/正の時間/有効rect/対応ページ/予兆時間を検証し、全required textureを開始前にload確認。未知のAI/スキル/移動方式はResource追加だけでは動かずコードとレビューが必要。

イベントはIDで選択した1件だけロード。背景crowd負荷と避難AI、JSON検証とactive event処理、同一atlas共有と異なる素材resident量を別に測る。今回の既存コード測定はT3 controllerや避難AIの性能保証ではない。配布packの手動列挙は残るため、T3で必要依存の検証と欠落テストまでを実装範囲とし、全素材pack自動生成器は追加しない。

### 工数の扱い（未実装の概算）

1名・既存Godotに習熟・素材制作と実機待ちを除き、T3接続/避難経路/保存/回帰までの概算はA=4〜7人日、B=6〜10人日、C=15〜25人日。見積りの根拠はAでも未実装の避難/復元/geometryが必要、Bは追加で責務分離/型検証/opt-in hooks、Cは既存T1/T2/入力/保存の移行と回帰を伴うこと。実測工数や確約日程ではない。上層自由移動・正式素材・Web保存の不具合対応で範囲が変われば再見積りする。長期費用はイベント種類が未確定なので数値化せず比較表の相対評価に留める。

追補：Battle._separateの敵ペアa/bへの直接位置加算も移動policyの対象とする。各個体の加算前位置と分離後desiredをresolve_motionへ渡し、segment境界を横切る押し出しを拒否する。damage直前のconstrain_currentだけに頼らない。policy=nullは従来と同じ位置加算。分離中に薄い柵を挟んだ2体を押しても越境しないテストを受入へ追加する。
