# SA2 ダンジョン・敵デザイン提案（T1〜T4）

> （2026-11-14 ユーザー決定：敵・ボスの設定画は「右向きの真横・全身・攻撃前の待機の構え」1 枚だけ。正面は作らない。ゲームは横からしか映らず、動画AIに渡すのはこの絵＝動画の最初のコマ。構えの姿勢にしておくと、待機のループ・攻撃の起点・攻撃後に戻る姿勢をこの 1 枚にそろえられる）

2026-11-14。依頼書7章への回答。**【決定】は原文を保持。以下の新しい名称・色の細分・部品内容・敵の形と攻撃数値はすべて【案】で、採用済み設定ではない。**

参照：`yyvape-dev/SA` main `d9c9f87e8ce9c435324173e66207b13d53a56a63`。依頼書・world_concept・dungeon_themesの全文、および指定参考画像4点を確認。参考画像の構図は複製しない。

## 1. 全体の決まり

【決定】横から少し見下ろす2.5D。見える高さ約4〜5m。完成イメージは約2.2:1、床を下1/3空ける。12〜14部屋／5×5、1部屋38〜58m、12〜18体・3群れ。仕組みの変更は本提案に含めない。

【決定】厚い筆致、彩度、強い明暗を持つ油彩風。雑多な小物は暗い塊へまとめ、最明部は少数。記号看板だけ。背景に人物は入れない（遠景影だけ許容）。瓦・赤提灯・暖簾・家紋なし。全面オレンジなし。赤＝敵、青＝味方、金＝物資・決着。

【案】小さな札での識別を、T1＝多色の縦看板／T2＝青緑の密集矩形と紫の裂け目／T3＝灰白の欠損と紫の弧／T4＝墨緑の低い坑道と黄緑の斜鉱脈で分ける。変更理由：T2・T3が同じ紫一色になるのを避け、色と輪郭の両方で判別するため。

## 2. 部品の接続・命名

【案】正面部品は足元0m、軒2.6m、2階床3.0m、上端5mを共通線とする。左右端は中立的な柱・岩断面で終える。端の光は弱くし、強い斜線を隣部品へ跨がせない。上端は暗い共通壁へ溶かす。左右反転は義肢の左右・機械の機構を変えるため自動前提にしない。

正面部品は1部屋4〜7個程度を並べ、隣に同じものを置かず、順番・間隔を変える。手前物は1画面1〜2本、暗くぼかし、戦闘の判読を優先。大物x1は1部屋最大1つの案。裏の列→正面→手前の奥行き順。遠景の門はT3 far1にだけ含む。

部品は**各IDごと1枚の単独絵**。地面g1だけ真上、他は歪みの少ない正面。背景は単色#FF00FF。地面は正方形の素材面が全体を埋めるため、マゼンタは外側だけ（余白を付ける場合）とし、模様内部へ混ぜない。平らな照明、映り込みなし。厳密な継ぎ目とピクセル寸法は下絵確定後に検証する。

完成画の仮名は`tN_room.png`。部品は`tN_b1.png`等。敵は右向き真横・攻撃前の待機の構えの`tN_e1.png`・`tN_boss.png`だけ（正面`_front`は作らない＝2026-11-14 ユーザー決定）。最終接尾辞は末尾の質問参照。

## 3. テーマごとの必須要素・部品

### T1 歓楽街の入口

| # | 必須要素 | 画面で読める形 |
|---|---|---|
|1|飲み屋・酒場|開いたカウンター、酒瓶棚、大型蒸留機、酒の記号|
|2|劇場・キャバレー|電球縁の入口と看板、奥へ退くビロードの幕|
|3|遊技場|歯車式の発光遊技機、当たりを表す記号|
|4|屋台の飲み食い|串、調理器、立ち飲み台。人と湯気の動画は別配置|
|5|縦長ネオン|複数段の記号看板。市場・宿は脇役|

色・光【案】：鉄紫の影／ピンク・緑・水色のネオン／酒場の奥だけ琥珀色。
形の識別：低い開口の連続と、縦に積んだ記号ネオン。
共通：床は暗く、戦闘の赤い予兆より背景発光を弱くする。

【決定】2画面の1区画に上表の少なくとも3項目。完成案では5項目を含める。既存のb1〜b4・f1〜f3・裏列・遠景・床は再利用方針。今回の新規背景部品は0枚。既存部品の欠損や接続不良を実測したという意味ではなく、依頼書の再制作不要条件に従う。新規ボス・雑魚は制作対象。

完成イメージ：`t1_room.png`。床の空白帯に装置・瓦礫・線路を置かない。開口内部の奥行きは許容するが、街全体を奥へ伸びる一本道の構図にしない。

### T2 奥の路地

| # | 必須要素 | 画面で読める形 |
|---|---|---|
|1|積層した増築|水平な2階床と渡り廊下、鉄骨の継ぎ足し。低い入口との重なり|
|2|義肢・義眼の工房|開口内の作業台、分解された義手、赤い敵発光と混同しない弱い水色検査灯|
|3|結晶・部品の露店|通りから奥の棚まで続く商いの空間。人物はゲーム側|
|4|魔界の浸出|壁と配管の隙間の紫の裂け目、太い根状の変容組織。飾りでなく建材を押し曲げる|
|5|密集した生活設備|配管、短いケーブル束、貯水槽。細部は暗い塊へまとめる|

色・光【案】：青緑に錆びた鉄／水色の技術光／開口の奥で紫が侵食。
形の識別：圧縮された矩形の増築に、縦の裂け目が食い込む。
共通：床は暗く、戦闘の赤い予兆より背景発光を弱くする。

部品一覧【案】（幅×高さm。裏列64×10mは仕様の8〜12m内。地面は1種で開始）：

| ID／ファイル名 | 部品 | 寸法の目安 | 配置・役目 |
|---|---|---|---|
|`t2_b1.png`|義肢工房|9.6×5|床の奥に横並び、足元・軒線共通|
|`t2_b2.png`|結晶と回収部品の露店|8×5|床の奥に横並び、足元・軒線共通|
|`t2_b3.png`|増築された保守小屋|9.6×5|床の奥に横並び、足元・軒線共通|
|`t2_b4.png`|侵食された揚水所|8×5|床の奥に横並び、足元・軒線共通|
|`t2_f1.png`|継ぎ足し鉄柱|0.5×5|暗くぼかした手前1〜2本|
|`t2_f2.png`|束ねた縦配管|0.8×5|暗くぼかした手前1〜2本|
|`t2_f3.png`|義眼型の検査街灯|0.6×5|暗くぼかした手前1〜2本|
|`t2_back1.png`|増築街区の影|64×10|後方の独立レイヤー|
|`t2_far1.png`|半魔界の奥路地|横長・寸法未定|後方の独立レイヤー|
|`t2_g1.png`|補修された石舗装|2.5×2.5|地面の繰り返し素材|
|`t2_x1.png`|裂けた隔壁|8×5|1部屋最大1点、壁際|

完成イメージ：`t2_room.png`。床の空白帯に装置・瓦礫・線路を置かない。開口内部の奥行きは許容するが、街全体を奥へ伸びる一本道の構図にしない。

### T3 門の手前の廃墟

| # | 必須要素 | 画面で読める形 |
|---|---|---|
|1|崩壊した街の痕跡|酒場の瓶棚や義肢工房の台座の残骸で、町が壊れたと読ませる|
|2|断たれた鉄骨|途中で切れた梁・片持ちの床。支持部のない細い橋を主役にしない|
|3|紫の亀裂|奥壁と床際に集約し、戦闘床には発光模様を焼き込まない|
|4|浮遊する瓦礫|背景側だけに小群。床の衝突物と誤認しない高さに置く|
|5|門の輪の遠景|遠景の一部として大きな弧。正面部品ごとに輪を重複させない|

色・光【案】：灰白の粉塵と黒鉄／主光は紫／赤は敵の予兆に温存。
形の識別：欠けた建物の段差と、大きく空いた空隙・輪の断片。
共通：床は暗く、戦闘の赤い予兆より背景発光を弱くする。

部品一覧【案】（幅×高さm。裏列64×10mは仕様の8〜12m内。地面は1種で開始）：

| ID／ファイル名 | 部品 | 寸法の目安 | 配置・役目 |
|---|---|---|---|
|`t3_b1.png`|崩れた酒場壁|9.6×5|床の奥に横並び、足元・軒線共通|
|`t3_b2.png`|断たれた工房|8×5|床の奥に横並び、足元・軒線共通|
|`t3_b3.png`|片持ちの階床|9.6×5|床の奥に横並び、足元・軒線共通|
|`t3_b4.png`|亀裂のある外壁|8×5|床の奥に横並び、足元・軒線共通|
|`t3_f1.png`|折れた鉄柱|0.6×5|暗くぼかした手前1〜2本|
|`t3_f2.png`|垂れた配管|0.8×5|暗くぼかした手前1〜2本|
|`t3_f3.png`|割れた梁支え|0.9×5|暗くぼかした手前1〜2本|
|`t3_back1.png`|廃墟街区の影|64×10|後方の独立レイヤー|
|`t3_far1.png`|巨大な門の弧|横長・寸法未定|後方の独立レイヤー|
|`t3_g1.png`|粉塵の石床|2.5×2.5|地面の繰り返し素材|
|`t3_x1.png`|浮遊瓦礫の残存壁|8×5|1部屋最大1点、壁際|

完成イメージ：`t3_room.png`。床の空白帯に装置・瓦礫・線路を置かない。開口内部の奥行きは許容するが、街全体を奥へ伸びる一本道の構図にしない。

### T4 地下の採掘坑

| # | 必須要素 | 画面で読める形 |
|---|---|---|
|1|資源の鉱脈|粗い母岩内の黄緑結晶、採掘痕。報酬と誤認させる金色の山は作らない|
|2|坑道の支保工|門形鉄骨、ボルト、押しつぶされた補修材。低い天井を読む形|
|3|採掘・選鉱の機械|削岩装置、破砕機、搬送樋。現代工場でなく結晶動力と魔法回路|
|4|トロッコ系統|線路は奥壁側の背景設備に集約。走れる帯を横断しない|
|5|地下の変容|岩の亀裂の紫、結晶と固着した太い根。坑内から門の影響が伝わる|

色・光【案】：墨緑の岩・黒鉄／黄緑の鉱脈光／奥の裂け目だけ紫。金色は資源の小点に限定。
形の識別：低い岩天井と斜めの鉱脈、門形の坑道支保工。
共通：床は暗く、戦闘の赤い予兆より背景発光を弱くする。

部品一覧【案】（幅×高さm。裏列64×10mは仕様の8〜12m内。地面は1種で開始）：

| ID／ファイル名 | 部品 | 寸法の目安 | 配置・役目 |
|---|---|---|---|
|`t4_b1.png`|露出した鉱脈壁|9.6×5|床の奥に横並び、足元・軒線共通|
|`t4_b2.png`|削岩機の作業所|8×5|床の奥に横並び、足元・軒線共通|
|`t4_b3.png`|破砕・選鉱所|9.6×5|床の奥に横並び、足元・軒線共通|
|`t4_b4.png`|トロッコ積出所|8×5|床の奥に横並び、足元・軒線共通|
|`t4_f1.png`|坑道支柱|0.7×5|暗くぼかした手前1〜2本|
|`t4_f2.png`|縦の換気管|0.8×5|暗くぼかした手前1〜2本|
|`t4_f3.png`|結晶検査灯の柱|0.5×5|暗くぼかした手前1〜2本|
|`t4_back1.png`|坑道支保工の列|64×10|後方の独立レイヤー|
|`t4_far1.png`|地下深部の坑道|横長・寸法未定|後方の独立レイヤー|
|`t4_g1.png`|踏み固めた坑内床|2.5×2.5|地面の繰り返し素材|
|`t4_x1.png`|大型削岩機|8×5|1部屋最大1点、壁際|

完成イメージ：`t4_room.png`。床の空白帯に装置・瓦礫・線路を置かない。開口内部の奥行きは許容するが、街全体を奥へ伸びる一本道の構図にしない。

## 4. 敵・ボスの共通仕様

以下12体はすべて【案】。雑魚8種は1.8〜2.4m、ボス4体は2.7〜4mに収めた。四足獣の高さは肩高、機械は最高点、人型は立位全高。T1は人間、T2は変容しかけの人間、T3は人間を失う形と下級悪魔、T4は生物と機械双方の侵食を描く。

攻撃の距離・予兆秒は**実装未検証の初期案**。前方＝身体前端から横方向、奥行き＝帯方向の**全幅**（±表記ではない）。自分中心の技は前方0とし直径を明記。投射物は射程と弾の奥行き幅。追尾・ダメージ・ノックバック・HP・CDは未決。床予兆・弾・衝撃波・発光変化はゲーム側で重ね、動画には焼き込まない。

動画AI共通指示（下の各clip冒頭へ付ける）：
```text
Use the approved RIGHT-FACING SIDE-VIEW full-body character reference. Locked orthographic side camera, facing screen-right throughout, full body and every tool visible with generous margins, solid uniform #FF00FF background, no floor line or cast shadow. Preserve exact anatomy, limb count, costume, tool shape, colors, scale and opaque painterly rendering. No camera motion, zoom, turn, scene, text, particles, projectiles, smoke, flashes, or added limbs. Use one continuous readable action with clear anticipation, action and recovery. In-place locomotion with stationary root for idle and walk clips; attack root travel follows the individual instruction and remains fully inside the frame. Keep a stable ground-contact baseline. Timing follows the approved telegraph and is retimed in engine; clip length and frame rate remain undecided.
```

待機・歩きは別clip。待機／歩きはループ、攻撃・被弾は待機へ戻る。倒れは最終姿勢保持（消滅させない）。当たりと映像の一致は後の実機検証が必要。

### t1_e1 徴収屋

**説明【案】**：歓楽街の店から場所代を取り立てる、ほぼ人間のごろつき。 **高さ：1.95m。**

形の固定【案】：Lean adult male racketeer, cropped dark hair, plum waistcoat over rolled sleeves, charcoal trousers, heavy boots, one chunky iron sap in right hand, tiny red magitech cuff; human anatomy, no horns, no gold or blue glow.

設定画：`t1_e1.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|鉄棒打ち|右肩へ棒を引き、前へ一歩踏んで斜めに殴る|前2.2m／全幅1.4m|0.5秒：棒を肩上へ引き、赤い短い扇形|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Take deliberate alternating steps to the right, keeping the sap low and the torso slightly hunched. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Draw the iron sap behind the right shoulder, step forward with the left foot, strike once diagonally downward, then recover with both feet grounded. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: Buckle at both knees, drop the sap hand, fall onto the right side and remain still. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t1_e2 仕込み銃の客引き

**説明【案】**：遊技場の案内役を装い、魔導式の短銃で逃げ道を塞ぐ。 **高さ：1.8m。**

形の固定【案】：Slender adult female tout, short dark bob, cropped burgundy jacket, opaque dark split skirt over fitted trousers, ankle boots, compact thick-barrel magitech pistol in right hand; one dull red glass sight, no floating decorations.

設定画：`t1_e2.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|単発射撃|腰を止めて片腕を水平に伸ばし、1発撃つ|前7m／全幅0.8m|0.7秒：銃口を固定し赤い細帯|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Walk right in short measured steps, pistol held close to the chest, elbows clearly separated from torso. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Plant both feet, extend the right pistol arm horizontally, hold the aim, fire one shot with a small sharp recoil, lower the arm. Keep the projectile and muzzle effects out of this body-motion clip. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: Stagger one step backward, lower the pistol, sink to one knee, then fall sideways and remain still. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t1_boss 遊技場の鉄腕支配人

**説明【案】**：違法遊技場の用心棒頭。人間の巨体と機械の右腕で客も店も支配する。 **高さ：2.9m。**

形の固定【案】：Massive broad adult human male bouncer, shaved head, dark burgundy sleeveless formal coat, charcoal trousers, heavy boots, oversized opaque iron RIGHT prosthetic forearm with three blunt knuckle plates and red inset core; left arm muscular human, broad simple silhouette, no crown no gold no blue.

設定画：`t1_boss.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|鉄腕横薙ぎ|腰をひねり右鉄腕を大きく横へ振る|前3.8m／全幅2.6m|0.9秒：右肘を引く／赤い扇形|
|踏み込み叩き|両脚で踏ん張り鉄拳を頭上から打ち下ろす|前4.5m／全幅1.8m|1.1秒：拳を頭上へ／赤い長方形|
|肩の突進|肩を下げ直線を走り、最後に踏み止まる|前6m／全幅2m|1.2秒：肩を下げる／赤い突進帯|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Walk right with slow heavy alternating steps; let the massive right iron fist swing slightly below the hip. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Twist the hips back, pull the heavy right prosthetic elbow behind the torso, sweep the fist forward at chest height in one broad arc, then let its weight settle. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_2: Raise the right iron fist overhead, take one forceful step right, drop the body weight into a vertical fist slam, hold the low impact pose, then rise. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_3: Lower the left shoulder, plant the rear foot, drive right in three powerful running steps, brake with a wide stance and return to guard. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The iron arm goes limp, both knees hit the ground, the torso tips forward and settles on its side. Remain still. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t2_e1 継ぎ腕の住人

**説明【案】**：変容した腕を義肢に替えた住人。今は接合部から再び侵食が進む。 **高さ：2.1m。**

形の固定【案】：Adult humanoid with wrapped head, short dark teal work apron over charcoal trousers, one large elbowed RIGHT iron prosthetic arm, thick violet organic seam at shoulder, tiny red slit eye, two normal legs, no dangling tubes.

設定画：`t2_e1.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|義腕突き|肘を畳み肩から義腕を直線に伸ばす|前2.8m／全幅1.2m|0.65秒：肘を後ろへ／赤い細長矩形|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Walk right with uneven but grounded steps; the heavy prosthetic arm lags behind the shoulder. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Fold the right prosthetic elbow, rotate the shoulder back, thrust the iron fist straight right at chest height, pause at full extension, retract without telescoping or changing arm length. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: Both legs buckle; the heavy prosthetic hand touches the ground first, followed by the torso rolling onto its side. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t2_e2 裂晶の運び手

**説明【案】**：結晶の荷を背負い続けた運び手。背と肩が一体化し、欠片を投げる。 **高さ：2.0m。**

形の固定【案】：Hunched humanoid porter with thick charcoal hood, opaque dark apron, compact broad cluster of THREE dull violet crystal plates fused to upper back, two bare sturdy arms, two legs, red fissures in crystal, solid silhouette no particles.

設定画：`t2_e2.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|裂晶投げ|肩の欠片を左手で抜き、頭越しに1個投げる|前6m／全幅1.2m|0.85秒：左肘を上げる／着地点の赤い円|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Trudge right with knees bent and the compact crystal load stable on the upper back. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Reach the left hand to the upper-back crystal cluster, draw one solid shard overhead, throw it forward to the right with a clear shoulder rotation, return to the hunched stance. Generate body motion only; projectile flight is separate. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The porter drops to both knees, curls forward and rolls sideways with the crystal load still attached. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t2_boss 縫合師

**説明【案】**：変容治療を続けた義肢技師。太い縫合組織が胴と二本の工具腕を覆っている。 **高さ：3.1m。**

形の固定【案】：Tall hunched former prosthetic surgeon, opaque charcoal leather apron, thick violet stitched organic shoulder mantle, bald masked human head with one red lens, EXACTLY TWO arms: right arm ends in broad iron clamp and left arm in short blunt surgical hammer, two thick booted legs. No tentacles no cables no smoke body.

設定画：`t2_boss.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|鉗子挟み|右鉗子を開き前へ伸ばして閉じる|前4m／全幅1.6m|0.9秒：鉗子を開く／赤い長方形|
|工具叩き|左の短槌を振り上げ前を叩く|前3m／全幅2.4m|1秒：左腕を頭上へ／赤い扇形|
|接合部放電|両工具を床につき、肩から短く放電|自分中心／直径5.2m|1.3秒：両腕を下げ肩を広げる／自分中心の赤い直径5.2m円|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Take slow rightward steps with flexed knees, carrying clamp and hammer apart from the torso. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Open the broad right clamp, pull it beside the shoulder, extend the arm right without stretching its anatomy, close the clamp once, retract. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_2: Raise the short left hammer high, brace both feet, hammer down in front, hold the compressed impact pose and recover. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_3: Plant both tool hands against the ground, arch the shoulders outward, tense the whole body, give one abrupt full-body contraction, relax back to the idle pose. Do not generate electrical effects. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The knees collapse, clamp and hammer rest on the ground, then the upper body falls sideways as one opaque solid mass. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t3_e1 壁喰い

**説明【案】**：崩れた家屋に取り残された元住人。腕と背が瓦礫に似た厚い殻へ変容した。 **高さ：2.35m。**

形の固定【案】：Former human transformed into a heavy crouched biped with dark gray masonry-like organic shoulder shell, small recessed head with red eyes, oversized blunt right forearm, two thick short legs, scraps of charcoal work clothes at waist; opaque broad silhouette.

設定画：`t3_e1.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|殻腕叩き|殻の右腕を持ち上げ短く打ち下ろす|前2.7m／全幅2m|0.8秒：右肩がせり上がる／赤い扇形|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Lumber right using alternating heavy short steps; keep both huge arms separate from the knees. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Lift the massive right shell forearm above shoulder level, lean forward, slam it down in front, recoil slowly into a crouch. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The thick legs fold, both shell arms touch down, and the creature rolls onto its side, shell remaining intact. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t3_e2 門渡りの猟犬

**説明【案】**：門を通ってくる下級悪魔。人間でない骨格と一直線の跳躍で見分ける。 **高さ：1.8m。**

形の固定【案】：Opaque stocky FOUR-legged demon hound, shoulder height 1.8m, charcoal hide with broad dull violet bony plates, wedge-shaped blunt head, short rigid tail, red eyes and mouth seams, FOUR short powerful legs, no wings no fur strands no extra limbs.

設定画：`t3_e2.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|直線跳躍|腰を落として後脚で蹴り、前脚から着地|前5.5m／全幅1.5m|0.9秒：前脚をたたみ低く伏せる／赤い直線帯|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Walk right in a clear grounded four-beat quadruped cycle, spine level, short rigid tail stable. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Crouch with hind legs compressed, push off strongly to the right in one low straight leap, stretch the torso slightly while airborne, land on front paws then hind paws, recover. Keep all four legs anatomically consistent. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The front legs buckle, the hindquarters sink, and the hound rolls onto its side with all four limbs clearly attached. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t3_boss 門前の成れ果て

**説明【案】**：門の近くで人間が大きく変容した巨体。胴に旧衣装が残り、悪魔とは区別できる。 **高さ：3.8m。**

形の固定【案】：Huge former human biped 3.8m tall, nearly headless hunched silhouette, broad crescent of opaque black-violet shell across upper back, small human face embedded at front of chest with red eyes, TWO massive blunt arms and TWO pillar legs, a single torn charcoal waistcoat remnant across chest, red-violet cracks confined to shell. No floating parts no smoke no tentacles.

設定画：`t3_boss.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|巨腕薙ぎ|右腕を後ろへ引き、地面近くを掃う|前4.8m／全幅3.2m|1.1秒：胸をひねる／赤い広い扇形|
|踏み砕き|右脚を持ち上げ前へ強く踏み下ろす|前3.5m／全幅2.4m|1.2秒：片脚を上げ静止／赤い矩形|
|門圧|身を縮めてから殻を開くように反り、圧力を放つ|自分中心／直径7m|1.5秒：背を丸めて溜める／自分中心の赤い直径7m円|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Walk right with weighty alternating pillar-leg steps and a low forward lean; keep the crescent shell rigid. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Rotate the entire torso back, pull the right arm behind the hips, sweep the heavy arm forward low above the ground, settle into a wide stance. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_2: Raise the right pillar leg high with a visible balance pause, stamp forward hard, lower the torso over the planted foot, recover. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_3: Fold both arms inward and curl the torso, hold the compressed pose, then arch backward sharply with both arms spreading wide. The shell remains one rigid object; generate no shockwave or particles. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The pillar legs give way one after the other, the huge torso falls slowly forward then to the side, the rigid back shell settles and remains still. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t4_e1 坑道用破砕機

**説明【案】**：採掘用の自走機械。侵食された動力核が赤く脈打ち、作業対象を見失う。 **高さ：2.1m。**

形の固定【案】：Squat mining automaton 2.1m tall, heavy dark iron chassis, EXACTLY TWO broad tracked tread units, front-facing short conical drill angled forward, simple opaque armor, red-violet enclosed power core, no human face, no yellow or cyan emission.

設定画：`t4_e1.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|削岩突進|削岩頭を前へ構え履帯で短く加速|前4.5m／全幅1.8m|0.9秒：前が沈み核が赤く点灯／赤い直線帯|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Move right on the two tread units at a constant slow speed; subtly rock the heavy chassis, keep drill retracted. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Tilt the front chassis slightly downward, brace the retracted drill forward, accelerate right in a short straight charge, stop firmly with a small backward chassis rock. Keep both tread units and drill geometry stable. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The chassis jolts, the drill lowers, one tread unit stalls, the machine tilts onto its side and remains motionless. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t4_e2 晶殻坑獣

**説明【案】**：坑内生物が資源結晶に侵食され、胸の圧力で結晶片を吐き出す。 **高さ：2.0m。**

形の固定【案】：Four-legged squat subterranean beast, shoulder height 2m, dark gray thick hide, THREE broad opaque violet crystal dorsal plates, short broad jaw, red eyes and throat slit, FOUR thick legs, no thin spikes no floating particles no lime emission.

設定画：`t4_e2.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|晶片噴出|胸を膨らませて顎を開き前方へ1発吐く|前7m／全幅1m|0.9秒：喉が赤く灯り頭を引く／赤い細帯|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Walk right in slow grounded quadruped steps, keep the three broad back plates rigid and count constant. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Pull the head back, expand the chest slightly, plant all four feet, open the broad jaw and thrust the head forward once as if spitting a solid shard, close the jaw and recover. Do not generate the projectile. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: The front legs fold, the jaw settles toward the ground, then the body rolls onto one side with the three crystal plates attached. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

### t4_boss 採掘母機〈深層〉

**説明【案】**：原料を掘り続けた大型機械。鉱脈と動力核が融合し、機械のまま怪物化した。 **高さ：3.9m。**

形の固定【案】：Massive squat mining machine 3.9m high, TWO broad dark iron tread units, low armored central chassis, EXACTLY TWO industrial tool arms: right broad conical drill and left square crusher hammer, THREE opaque dark violet crystal plates fused to upper engine casing, red-violet enclosed core, broad clear joints. No pilot no human face no gold lime or blue emission.

設定画：`t4_boss.png`（右向き真横・全身・攻撃前の待機の構え・#FF00FF）。正面は作らない（2026-11-14 ユーザー決定）。

| 攻撃 | 動き | 前方／奥行き | 予兆【案】 |
|---|---|---|---|
|穿孔走行|右ドリルを水平にし、直線へ走る|前7m／全幅2.4m|1.4秒：ドリルを水平固定／赤い長方形|
|圧砕槌|左角槌を上げて前方を叩く|前4.2m／全幅3m|1.3秒：左槌を高く保持／赤い矩形|
|核の過圧|工具を接地し核を強く振動させ周囲へ圧を逃がす|自分中心／直径6.4m|1.6秒：両工具を床へ／自分中心の赤い直径6.4m円|

動画AI用clip別指示（英語）：
```text
IDLE: Hold a readable right-facing side-view guard. Use subtle breathing and a small weight shift, keep the feet or treads planted. Return seamlessly to the exact starting pose.
WALK: Advance right slowly on two tread units, tool arms carried low and apart, central chassis stays level. Animate in place with a stationary root; cycle seamlessly to the first pose.
ATTACK_1: Level the right drill arm horizontally, lean the tracked chassis forward slightly, drive right in a forceful straight burst, brake and lower the drill. Tool length and tread count remain fixed. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_2: Raise the heavy left square crusher hammer, pause at the apex, slam it down in front of the chassis, compress the suspension then recover. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
ATTACK_3: Brace both tool heads against the ground, lower the chassis on its suspension, give one strong controlled mechanical shudder, lift back to idle. Keep crystal plates rigid; no generated particles or blast. Make the wind-up visibly distinct from the strike and finish in the original right-facing idle guard.
HIT: Take one short impact from screen-right. Recoil the upper body or chassis slightly left, keep all attached parts intact, regain balance and return to idle. No turn, no knockdown, no flash.
FALL: Both tool heads drop, the tread units lock, the suspension collapses and the chassis tilts onto one side, then stays inert. Do not explode or disintegrate. Keep facing right, keep the entire body visible, hold the final fallen pose. No disintegration.
```

## 5. 納品順・制作対象

1. 文章：このマークダウン1点。
2. 完成イメージ：T2 → T1 → T3 → T4、4枚（T2優先）。
3. 部品：T2 → T3 → T4、各11枚、計33枚。T1は既存再利用。各IDを単独で生成。
4. 敵設定画：T1ボス優先、その後T2、T1雑魚、T3、T4。12体×真横（攻撃前の待機の構え）＝12枚（正面は作らない。2026-11-14 ユーザー決定）。

合計61枚の画像案。これは仕上げの3D下絵への投影用素材の完了を意味しない。下絵に合わせた最終形・実寸・継ぎ目・切り抜き・Godotでの確認は次工程。GitHubやゲーム本体は今回変更しない。

## 6. 確認項目

- 札縮小時：4テーマを色と大形だけで区別できるか。
- 完成画：床下1/3が空き、水平スクロールの構図で、開口内だけに奥行きがあるか。
- 部品：1枚1部品、マゼンタ、共通足元・軒、切れない外形。床は真上・無反射。
- 敵：真横右向き・攻撃前の待機の構えか（動画の最初のコマにそのまま使える姿勢か）。手足数・装備位置・身長比が設計どおりか。赤〜紫発光のみ、輪郭で役割が読めるか。
- 未検証：厳密なタイル接続、動画AIでの維持、実機視認性、当たり判定・負荷。

## 7. 最後に確認したい点（未決のまま）

1. T2〜T4の必須要素表と12体の形・名称・攻撃を、この案で採用するか。改変したい対象はどれか。
2. （正面図`_front`は作らないと決定）完成画の`_room`、裏列・遠景の`back1`・`far1`という接尾辞でよいか。依頼書は種類を指定しているが、これらの厳密な表記は未指定。
3. 最終PNGのピクセル寸法、共通キャンバスと画素/m、マゼンタ外周余白はどうするか。3D下絵が出るまではコンセプトとして扱う。
4. T4は「地下」のどの位置にあるか。門の真下か、門へ向かう途中の坑道か。本案では地理を確定せず、影響の強い地下坑としてだけ描く。
5. 変容表現の上限：本案の太い組織・縫合・殻は許容か。露出臓器や切断表現は入れていない。
6. 動画AIの使用モデル、clip秒数・fps・ルート移動の納品形式は何か。技ごとの予兆秒は提案値であり、敵のHP・攻撃力・CD・経験値・ドロップと合わせ採用後に調整する。
7. T1既存部品の再制作は現時点で追加していない。組み合わせ検証後、必須3要素を満たさない場合だけ該当部品を特定して補う方針でよいか。
