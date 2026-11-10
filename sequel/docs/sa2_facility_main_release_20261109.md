# 4施設の画像・裏町Web配信のmain限定反映（2026-11-09）

> これは4施設公開時点の記録です。その後の遊技場・入口・壁仕上げは [最新の統合記録](sa2_world_integration_release_20261109.md) を参照してください。

## 承認と反映範囲

ユーザーが「今回の4施設と必要な配信修正に限りmainへ反映」に「よい」「続きを」と回答。以前のmain書込禁止は今回の範囲に限り解除された。基準mainは `db1d8333dab5c6c9f86a00531be1ea64743aa7af`。T2ブランチのmerge/cherry-pickは行わず、main基準スナップショットへ画像差分だけを適用した。

- 06 飲み屋・酒場：7.4×5m、w_bar.png、元画像1280×865。
- 08 キャバレー：7.2×5m、w_cabaret.png、元画像1280×888。
- 11 娼館風の宿：7.2×5m、w_brothel.png、元画像1280×888。
- 15 怪しい店：6.2×5m、w_shady.png、元画像1240×1000。

いずれも既存QuadMesh方式の平面1枚。擬似的な奥行き・階段・人物は絵の一部で、内部MAPや動くキャラを追加していない。画像のリサイズ・描き直し・品質劣化を伴う再圧縮は行わず、JPEGデコード後のRGBを保持し外周に連結した強いマゼンタだけを透明にした。元JPEGはpainted_bt_src/.gdignore内に保存。

main.gdの変更は、裏町を構築する前のbt1取得と、画像に重なる仮の看板パネル／仮布を画像がある時だけ省く条件のみ。未読込時は従来の仮形状を維持する。通常の街・歩行範囲・カメラ・入力・戦闘・SA1・物語本文は変更しない。T2の会話／演習や素材待ち修正、T4の別フロア／カジノは今回の反映に含めない。

## Webビルドと再作成

公開先： https://yyvape-dev.github.io/SA/sequel/web/?town=back

GitHub Pagesはlegacy、mainのルートを配信する。既存Web書き出しではpainted_btを本体から除外したまま地区にも入れていなかったため、DISTRICTSへbt1を追加した。通常の街ではbt1を要求せず、裏町へ入る時だけ約23MBの画像パックを取得する。圧縮・画素数を落としていないので、実機回線での取得待ち時間は別途確認が必要。

ビルド識別子：`20261109110455-db1d833-art-20261109-g4.7.2`。

既存mainのGodot 4.7.2 Webランタイム（index.js/index.wasm）をSHA-256一致のまま再利用し、PCKだけを再生成した。HTMLのmainPack・fileSizes、全district PCKとソースのバージョンJSONを同じ版へ揃えた。本体index.pckに裏町画像・T2 playableはなく、bt1に4施設のimport資源があることを目録確認済み。

```sh
python3 sequel/tools/import_facility_06_08.py
python3 sequel/tools/import_facility_11_15.py
# 既存の同一エンジンWebランタイムを使って、別フォルダへPCKを再生成：
GODOT_BIN=/path/to/Godot WEB_PACK_ONLY=1 WEB_OUT=/absolute/preview python3 -I sequel/tools/export_web.py
# 通常のフル書き出しは従来通り（対応export templatesが必要）：
GODOT_BIN=/path/to/Godot python3 -I sequel/tools/export_web.py
```

WEB_PACK_ONLYでは既存web/への直接上書きを禁止する。エンジン更新時に古いJS/WASMを混用しない。subprocessの失敗・パックの欠損は失敗として返す。

## 検証の区別

- 先行するT2作業ブランチのCI：Run `42606786256` success。これはmain固有のCIとは呼ばない。
- 実際のmain反映用ソース：Godot 4.7.2でimport、施設テスト06/08と11/15を実行。配置・原寸・他施設保持・重複防止・欠損時フォールバックを確認。
- main基準ビルド：Linux Chromium、844×390・touch対応コンテキストでWeb起動、bt1 HTTP200、入力移動、描画を確認。通常の街の起動でbt1を要求しないことも実際の通信で確認。
- Linux Godot実描画の連続MP4：`/workspace/sa2-facility-11-15-evidence/facilities_11_15.mp4`。H.264/yuv420p、1280×720、約9.07秒。
- 公開処理の結果・コミットSHA・Pages Run ID・公開URLの取得記録は実行ホストの `/workspace/sa2-main-release-evidence/` に保存する。
- iPhone/Androidの物理実機は未確認。スマホ寸法のLinuxブラウザを実機確認と呼ばない。

既存の手前の屋台・看板・NPCは残るため、背景画の一部は隠れる。特に15の手前には部品屋台14が重なる。周囲の未納品施設の図形も残る。街全体の配置変更・最終受入・T2.5全体の完了を意味しない。
