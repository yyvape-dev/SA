# 施設06・08：納品画の最小構成設置（2026-11-09）

> 公開前の作業記録です。ユーザーがその後mainへの限定反映を承認しました。現在の反映範囲・検証は `sa2_facility_main_release_20261109.md` を参照。

## 対象と判断

ユーザーがこのチャットへ添付した1枚目＝06「飲み屋・酒場」、2枚目＝08「キャバレー」を、既存の裏町の施設枠へ設置する。室内の奥行きと人物は納品画に描かれたまま使用する。描き直し、人物分離、アニメーション、入室可能な内部MAP、追加ライト、専用シェーダーは追加しない。

変更先は `feat/sa2-t2-sequel-integration-20261108`。main・SA1・承認済み本文・T4ブランチは変更しない。この設置は現在の作業ブランチでの検証であり、Pages公開版やT4の追加フロアへの反映を意味しない。T4別フロアの仕様は変更しない。

## 実装：既存の描画分岐を再利用

`backtown_block.gd` の各施設に `art` と `art_box` を追加する。既存 `main.gd:build_backtown()` は、画像が存在すれば `_bt_quad()` で正面向きのQuadMeshを1枚生成し、同じ施設の仮正面・庇・手すり・樽等の `_bt_shack()` は生成しない。上部の暗い壁と建物本体は既存のまま。元のpartsデータも保持するので画像未読込時は従来の仮表示へ戻る。

|番号|施設ID|画像|正面のX範囲m|Y範囲m|Z|添付原寸|
|---|---|---|---|---|---|---|
|06|n1_tavern|art/painted_bt/w_bar.png|−11.4〜−4.0|0〜5|−6.51|1280×865|
|08|n2_cabaret|art/painted_bt/w_cabaret.png|−2.0〜5.2|0〜5|−6.51|1280×888|

平面の実寸は06＝7.4×5m、08＝7.2×5m。元画像に含まれる左右のキー色帯も同じ画像枠の一部として透過する。内容に合わせて勝手に拡幅・クロップしない。以前の発注目標1480×1000/1440×1000にアップスケールせず、実際の添付画像の全画素を保持する。

### 実画面で見つけた重複と対策

`_bt_extras()` は施設本体とは別に仮の看板パネル／布を生成するため、データを登録するだけでは06の看板上に黒い仮パネル、08の装飾上に白／赤の仮の布が重なる。対象を限定した条件を各2行追加した。

- 06の画像が存在する時だけ `neon_liquor_tavern` を省略。
- 08の画像が存在する時だけ `rail_cabaret` に付く仮布を省略。
- 画像未読込時には両方とも従来通り復帰する。
- 他施設の布、実際の光る看板、吊り灯り、NPC、歩行範囲、カメラ、入力処理は変更しない。

## 素材と再作成

元JPEGは `art/painted_bt_src/w_{bar,cabaret}_user_20261109.jpg` に保存。同ディレクトリの既存 `.gdignore` によりゲームへの元画像二重取り込みを避ける。出力PNGはRGBA、Godotの圧縮はLossless、size_limit=0。新規描画負荷は既存方式の画像平面2枚で、画像ごとの毎フレーム処理は追加しない。実機での速度・メモリ計測は未実施。

再作成：

```sh
python3 sequel/tools/import_facility_06_08.py
```

必要ライブラリは既存 `cut_bt.py` と同じPillow・numpy・scipy。外周左右につながる強いマゼンタ領域だけをアルファ0にする。RGBは全画素で元JPEGのデコード結果と一致することをスクリプト内で検証。色変更、再サンプリング、描き直し、内部の紫色除去はしない。元解像度は保持するが、元からJPEGにある圧縮損失を元に戻すものではない。

## 検証と証拠

エンジン：Godot 4.7.2.stable.official.ed1daf0bf、Linux Compatibility、Mesa llvmpipe。レンダリング用ローカルXorgは:100。最初の:99は既存ソケットがあっても接続できなかった。実機iPhone/Android、Web公開・Pages配信・T4への統合はNOT TESTED/NOT DEPLOYED。

自動テスト：`tests/sa2_facility_06_08_test.gd`。変更前に画像未使用／仮形状残存の4件でFAIL。実画面で発見した看板・布の重複にも個別に失敗を確認してから修正。最終版は画像の割当・実寸・座標・原寸・重複防止・既存ビジョン棟・未納品宿・画像未読込時のフォールバックを検証する。

```sh
Godot --headless --path sequel --fixed-fps 60 --script res://tests/sa2_facility_06_08_test.gd
```

追加の既存回帰テスト6本：T1進行、T1.5会話、T2手動操作、T2.5復帰、T2.5入力、素材読み込み待ち。結果は証拠フォルダの `regression-results.json` と各ログを参照。

実画面：`tests/sa2_facility_06_08_capture.gd` は通常のmain.tscnを読み込み、ui_right/up/down/leftの入力で06→08→奥→手前→06と移動する。初期位置設定以外の移動はプレイヤーの既存処理を通る。カメラを変更せずスクリーンショット4枚と連続動画を記録する。撮影用の自動入力でありiPhone実機操作とは呼ばない。

```sh
FACILITY_CAPTURE_DIR=/absolute/evidence Godot --path sequel --resolution 1280x720 --fixed-fps 30 --write-movie /absolute/evidence/facilities_raw.avi --script res://tests/sa2_facility_06_08_capture.gd
```

実行ホストでは書込可能な `XDG_DATA_HOME` / `XDG_CACHE_HOME` とX11のDISPLAYが必要。証拠の実ファイルは `/workspace/sa2-facility-install-evidence/`。ログのMOVIE_START_FRAME以降をH.264/yuv420p/faststartの `facilities_06_08.mp4` に変換する。冒頭の起動待ちだけを除き、移動途中の編集・静止画への差し替えはしない。

留意点：周囲の未納品屋台などの図形は残っている。元からある混雑NPC・動的看板で背景画の一部は隠れる。ゲーム用D2カメラは足元〜約4mを映すため、高さ5mの絵の最上部が常時全部見える構図にはしていない。この依頼で街全体の再配置やカメラ再設計は行わない。

## 最終結果

- 追加の施設テスト：PASS（失敗0件）。既存回帰テスト6本：全て終了コード0。
- Godot実レンダリング：PASS。06→08、奥／手前、08→06の入力移動4区間が全て到達。
- MP4：1280×720、30fps、8.433秒、H.264/yuv420p/limited range＋AAC、faststart。全編デコード成功、0.2秒以上の黒画面検出なし。冒頭・中間・末尾の実画面を目視確認。
- 初回editor importはサンドボックスの設定ディレクトリ／IPC制約による環境エラーを記録。書込可能なXDG_CONFIG_HOMEとローカルIPCを使った最終importは終了コード0・ERRORなし。
- 最新動画：`/workspace/sa2-facility-install-evidence/facilities_06_08.mp4`。ChatGPTで直接添付されたと主張せず、実ファイルへのリンクを提供する。
- 公開版・iPhone/Android実機・T4統合は未実施。この検証をT2.5全体や最終ゲーム品質の受入合格に読み替えない。
