# C2-09 限定実装仕様

承認済みB案の仕様を外部レビュー用に集約する。設計の変更や追加承認を意味しない。対応する機能コードは `47b6e8869dff831d828c39c4cff9335b055099e6`。受入実行結果・未検証項目は別の実装報告を参照する。

## ゲーム挙動

- 探索→戦闘→探索で既存backtownのLevelインスタンスを維持する。別戦闘マップへの転送・街再生成をしない。
- 戦闘ではリリィを手動操作し、既存T2 Manualの移動・通常攻撃・回避・防御を流用する。AIと手動の二重更新を禁止する。探索側modalが入力を所有している間は開始を拒否する。
- 敵は同一cutting_machine profileの2基、IDはmachine-a/machine-b。初期位置は(13.5,0,0)/(15.3,0,0.6)。仮profileはHP36/攻撃16/移動0.9/攻撃倍率1/高さ1.45。正式バランス確定値ではない。予兆が見えて回避・防御できること。
- 避難住民はresident-a/b/cの3人。背景crowdとは別所有・別更新で、戦闘rosterへ登録しない。EまたはGUIDEで専用経路の移動を開始する。上層開始位置はx12.2/12.7/13.2、y2.6、z-5.9。階段上(12.7,2.6,-5.85)→下(14.05,0,-5.85)→(13.7,0,-3.6)→安全地点x10.35/10.8/11.25,y0,z-3.6へ移動する。
- リリィと敵は下層の同一戦闘帯のみ。戦闘x/z範囲Rect2(8,-1.8,9,3.6)、閉鎖境界Rect2(16.7,-2,0.18,4)。上層自由移動は追加しない。帰還後も宣言済み閉鎖を維持し、既存探索room/beltを復元する。
- 成功は登録機械2基停止 AND 登録住民3人安全到達。成立順序を問わず、重複signalは一度だけ、未知IDは無効。リリィ共有HP0は敗北で、同フレームに成功しても敗北を優先する。
- 人間・背景NPC・住民・設備・縁は攻撃対象外。通常・範囲等すべてのhit形状についてダメージ直前にroster/陣営/floor/高さ/遮断segmentを検証する。pull/knockbackやseparationでも対象外actorを巻き込まない。
- 通常/ダッシュ/攻撃中/被弾/敵移動/pull/knockback/Battle分離の両対象で移動境界を適用する。薄い閉鎖境界もsegment sweepで貫通させない。

## 状態・保存契約

EXPLORE/SAFE →（checkpoint保存成功）→ STREET →（HP0またはAND条件）→ RESULT_PENDING →（結果保存成功）→ SAFE/COMPLETE。保存失敗時は操作・戦闘更新を止めたpendingを維持し、保存再試行まで探索解除しない。開始前保存失敗では戦闘を開始しない。

専用`user://sa2_t3_progress.json`を使用し成長/T2 saveを変更しない。schema1、definition version、event/map、attempt、phase、Flow、checkpointとSHA256 envelopeを検証する。checkpointは共有HP/最大HP/ゲージ/倍率/hits/ゲージ許可、Rana/Lily位置・向き・cooldown、敵ID/profile/初期HP・位置、住民ID/経路index・位置、通行閉鎖flagを持つ。復元キーを固定allowlistに制限し任意Battleプロパティを注入させない。actor transient/target/攻撃状態/被弾/演出等は明示的に初期化する。

temp書込・flush・readback→有効currentのみbackupへ検証付き更新→tempをcurrentへrename。破損currentで正常backupを上書きしない。起動時は正常current、なければ正常backupを読み、tempを勝利として昇格させない。未知schemaは拒否する。current/backupとも無効なら有効な進行復元とは扱わない。SHA256は破損検出であり改ざん防止認証ではない。

敗北またはSTREET中断からの起動は開始前checkpointへ戻し、機械2基・住民初期経路・イベントflag・共有値を一貫させる。攻撃時刻や戦闘途中HPから再開しない。COMPLETEの正常保存から起動すると完了状態で、機械を再発生させない。

## 責務・検証・対象外

Hostが既存街とBattleを構成し、Encounterが状態/ID集合、Lease/Driverが制御所有、Policyが移動/ダメージ制約、Evacuationが住民、Definition/Profileが検証可能なデータ、Checkpoint/Snapshotが永続化/実体復元を担当する。definition/routes/profileは開始前に検証し、無効ID・重複・非有限値・不正素材/clip・境界横断経路を拒否する。新しい全ゲーム共通DSLやT2複製は作らない。

受入は同一Level、入力/AI排他、対象安全、AND/敗北優先、境界、20回再試行、別プロセス復元、保存fault/破損/schema、成長/T2非破壊、T1～T2.5/通常街回帰、Resource/JSON/画像pack同梱、実Godot動画で確認する。実測不能項目はNOT TESTEDにする。

仮機械画像・マーカー・HUDのみ追加。正式台詞・ストーリー・正式美術・音声・経験値・報酬・大規模地形改修は追加しない。T3装備メニューの変更はメモリ内だけで成長saveへ書かない。T2 Manual/シーン、main.gd、SA1、Claude指示は変更しない。主ブランチへマージしない。
