# 施設11・15設置とスマホ配信準備（2026-11-09）

> 公開前の作業記録です。ユーザーがその後mainへの限定反映を承認しました。現在の反映範囲・検証は `sa2_facility_main_release_20261109.md` を参照。

## 変更の目的・範囲

チャット添付の1枚目を11「娼館風の宿」、2枚目を15「怪しい店」へ設置。06・08と同じ、絵をQuadMeshへ貼る既存方式を再利用。室内の奥行き・階段は絵の中の表現であり、内部MAP・通行可能な階段・追加演出は作らない。元画像の解像度・RGBを変えず、左右の外周と連結した強いマゼンタだけを透明にする。

作業先は `feat/sa2-t2-sequel-integration-20261108`。main・T4・SA1・物語本文・Pages設定への変更は未実施。ユーザーの過去の「T2作業ブランチ以外への書き込み・マージは禁止」があるため、main公開は明示確認待ち。今回の「mainか？」には、APIで確認した現在の配信元を回答する。

|番号|ID|画像|画像原寸|正面X範囲m|Y範囲m|Z|
|---|---|---|---|---|---|---|
|11|n3_brothel|w_brothel.png|1280×888|7〜14.2|0〜5|−6.51|
|15|n4_shady|w_shady.png|1240×1000|18.8〜25|0〜5|−6.51|

## ファイルと処理

- `scripts/backtown_block.gd`：施設ごとのart/art_boxを登録。既存のparts/boxes/rails/stairsデータは欠損時のフォールバックとして保持。
- `scripts/main.gd:_bt_extras()`：納品画像がある時だけ11の仮の女性看板パネルと11/15の仮布を省く。実際の灯り・看板・NPC・別施設の屋台は維持。
- `art/painted_bt_src/w_{brothel,shady}_user_20261109.jpg`：元画像を保存。既存.gdignoreによりゲームへ二重取り込みしない。
- `tools/import_facility_11_15.py`：再作成用。Pillow/numpy/scipyを使用。全画素RGBの一致をassertし、リサイズなしでRGBA PNGを生成。
- `tests/sa2_facility_11_15_test.gd`：11/15の画像割当・原寸・配置・形状重複防止・画像がない時の復帰を検証。
- `tests/sa2_facility_06_08_test.gd`：11は未納品ではなくなったため、既存の「宿は仮形状」の期待値を「宿の納品画像を維持」へ更新。テスト削除・失敗抑制ではない。
- `tests/sa2_facility_11_15_capture.gd`：実際のui_right/up/down/left入力で11→15→奥→手前→11の連続撮影。
- CI：既存ワークフローへ4施設の配置／フォールバックテストを追加。

## Webで画像を使えるようにする最小変更

元のWeb exporterは `art/painted_bt/*` を本体から除外するが、別パックにも入れていなかった。nativeで見えてもWebには届かない構成だった。

既存DISTRICTSに `bt1` を追加し、`art/painted_bt/*.png` をまとめる。裏町の生成直前に `await district.ensure("bt1")` を実行。画像は裏町に入る時だけ取得し、通常の街ではbt1を要求しない。取得失敗時はloading.error_textを表示して構築を中断し、未配信素材を仮形状で成功扱いにしない。通常の地区分割／バージョン照合は既存方式を使用。

`export_web.py` のsubprocessをcheck=Trueにし、欠損パックを検出したら失敗させる。検証用の `WEB_PACK_ONLY=1` では、既存の同一4.7.2 Webランタイム（JS/WASM）を再利用してPCKのみ再生成。既存web/への上書きは禁止し、別のWEB_OUTを必須にする。HTMLのmainPackバージョン・fileSizesも更新する。新たなテンプレート1.28GBのダウンロードは行っていない。通常のフルexport経路は残す。

再作成例：

```sh
python3 sequel/tools/import_facility_11_15.py
GODOT_BIN=/path/to/Godot WEB_PACK_ONLY=1 WEB_OUT=/absolute/preview python3 -I sequel/tools/export_web.py
```

## mainへ反映する場合の境界

GitHub Pages APIの読み取り結果：build_type=legacy、source.branch=main、source.path=/。公開URLは https://yyvape-dev.github.io/SA/ 、裏町は `sequel/web/?town=back`。

T2ブランチ全体をmainへマージしてはいけない。mainの読み取りスナップショット `db1d8333dab5c6c9f86a00531be1ea64743aa7af` に、4施設分の画像・3ファイルのソース差分・bt1バージョンファイルだけを適用した独立ビルドを作成した。T2固有の会話／演習コードやLily読み込み待ち修正はこのmain基準ビルドに混ぜない。main自体のチェックアウト・commit・pushはまだしていない。

main基準ソース：`/workspace/sa2-main-art-stage/sequel/`
main基準Web完成物：`/workspace/sa2-main-mobile-preview-20261109/`
T2基準Web確認物：`/workspace/sa2-mobile-preview-20261109/`（これをそのままmainへ配布しない）

公開する場合はmain基準のソース差分と画像を反映し、同じビルドのHTML/PCK・全district PCK・対応バージョンJSONを揃える。バージョンが異なるPCKを混ぜない。JS/WASMはmain既存ランタイムと同じなので再生成・品質変更はない。公開後のPages successと実際のURLからの取得確認は、承認後の工程である。

## 証拠・制限

`/workspace/sa2-facility-11-15-evidence/` に原寸画像QA・失敗先行テストログ・成功ログ・連続MP4・Web取得ログを保存。

Godot 4.7.2 Linux実描画、11/15の往復・前後入力、施設テスト2本＋既存回帰6本は成功。WebはLinux Chromiumで844×390・touch対応コンテキストを使い、起動・bt1取得・描画を確認する。これはiPhone/Android実機の確認とは呼ばない。main基準ビルドの最終結果は同フォルダのmain-native-results.json / main-web/web-result.jsonを参照。

周囲の未納品屋台の図形は残る。特に15の左側には納品済みの部品屋台14が手前に重なる。今回の作業では他施設の移設・削除・カメラ再設計はしていない。追加bt1パックは約23MBであり、実機回線での待ち時間は未計測。ゲーム品質全体の受入・T2.5全体の完了を主張しない。

## main基準ビルドの最終確認

- 基準mainのSHAはAPIとfetchで一致。mainに書き込まず非gitスナップショットへ差分適用。
- main基準の施設テスト2本：終了コード0。
- Linux Chromium（844×390、touch対応）：起動成功、bt1.pckをHTTP200で取得、右端までの入力と描画を目視確認。JS pageerrorなし。実機ではない。
- パック目録：4施設のimport資源がbt1に存在。index.pckには裏町画像とT2 playableが存在しない。bt1に元JPEGの重複なし。
- main既存のindex.js/index.wasmと完成ビルドの同ファイルはSHA-256一致。Webエンジン4.7.2はブラウザconsoleでも確認。
- 完成ビルドの識別子：20261109110455-db1d833-art-20261109-g4.7.2。bt1は約23MB。
- 起動時のfavicon 404はブラウザの任意アイコン要求であり、PCKは全てHTTP200。
- 設置動画：`/workspace/sa2-facility-11-15-evidence/facilities_11_15.mp4`（H.264/yuv420p、1280×720、約9.07秒）。
- 配信設定・main・公開URLは未変更。公開承認後は最新mainとの差分再確認、限定反映、Pages成功、公開URLからのパック取得確認を行う。
