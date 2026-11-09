# SA2 T4 常設遊技場のD2実測・Godot仮配置報告 — 2026-11-09

## 対象と境界
- 上位正本: `sequel/docs/sa2_t3_design_gate_20261108/reports/sa2_handoff_20261109_t4_gamehall_relayout.md`、第8節。
- 作業: `test/sa2-t4-gamehall-relayout-20261109`（`docs/sa2-t3-design-gate-20261108` から新規分岐）。
- main / T2 / T3 の既存コードは変更なし。既存の `sequel/scripts/main.gd` と `backtown_block.gd` 自体を変更せず、別のテストスクリプトで実際のシーンを起動してから仮配置を重ねた。
- 画像生成モックは未使用。仮配置の色付きボックス・床・遊技機は**Godot 3D**。実画面PNGはGodot 4.7.2から取得。**制作済みカジノ絵ではない。**

## 実測に使った正本
- `sequel/scripts/backtown_block.gd` `segments()`、`STALLS`、`PEOPLE`、`DOORS`、`STREET_BARS`、`FG`。
- `sequel/scripts/main.gd` `_apply_cam_variant()` の D2: カメラ (x,3.2,15.3)、注視 (x,1.5,0)、縦FOV 16.8度。建物の壁 z=-6.5。歩行帯 z=-2..2。
- `sequel/specs/camera_depth.md`: 身長1.85m、D2中央約40.1%高、iPhone想定の可視横幅9.8m。
- 旧遊技屋台: x=4.3±1.2m、高3.0m。7.0mへ中央固定拡大すると x=0.8..7.8m、キャバレー(-2..5.2)と4.4m、宿(7..14.2)と0.8m重なる → **FAIL**。

## 検証配置 A — 全右側7m挿入（決定稿ではない）
- キャバレー端 x=5.2 を切点として、これより右の街のレンダリング要素を+7.0m。新カジノ x=5.20..12.20m、中心8.70m、物理幅7.00m・高4.17m・中央開口幅5.04m、内部奥行2.8m。GodotのBoxMeshとSprite3D 4人、機械・テーブルで仮配置。
- 宿は14.0..21.2m、門の路地23.0..25.2m、怪しい店25.8..32.0mへ。右側が元のプレイエリア±24mと床±30mを越えるので**街区として未実装**。
- プレビューでは旧 `stall_game` の Node3D を隠し、ステージ元コードは変更していない。
- 設置ガイドは `sequel/tools/t4_gamehall_guide.py` が Pillow を用いて決定的に生成。1536x1024 / 204.8px/m、外側マゼンタ厳密#FF00FF、建物外の床・人物なし。開口 x=0.98..6.02m、高2.86m。**完成絵ではない**。本体の幾何形状とガイド細部（山形屋根・装飾）はまだ完全同期していないので、画像制作ガイドとしての最終承認はしない。

## Godot実行と成果物
- 実Godot 4.7.2 / OpenGL3 software / Xvfb / 1688x780 PNG。
- Actions最終成功: https://github.com/yyvape-dev/SA/actions/runs/42551708166
- `sequel/tests/sa2_t4_gamehall_relayout_capture.gd`
- `sequel/captures/t4-gamehall/before_d2_x8p7.png`
- `sequel/captures/t4-gamehall/after_d2_x8p7.png`
- `sequel/captures/t4-gamehall/after_d2_x15p0.png`
- `sequel/captures/t4-gamehall/gamehall_geometry_guide.png`、同名 `.json`
- 3枚のPNGとガイドをGitHubの**T4専用ブランチ内に格納**。元のActionsログと一致する画像を実際に回収して目視した。
- 失敗履歴: 初回、`sequel/captures` は.gitignoreでGitへの証拠保存FAIL（レンダリングはPASS）。`git add -f`で修正。その後の古いランは同時作業中のpush競合でFAIL。上記最新ランは全step成功。

## 検証ゲート
| 条件 | 判定 | 根拠/制約 |
|---|---|---|
| 引き継ぎと第8節・必須資料の把握 | PASS | ハンドオフと指定ソース・スキルを取得 |
| 旧位置に7m拡大可能か | FAIL | キャバレー4.4m、宿0.8m重複 |
| D2 / 人物 / 3Dとの相対寸法 | PASS（設計値と実画面） | GodotログのD2 assertと画像3枚 |
| 旧遊技屋台を置き換えたGodot仮画面 | PASS（検証に限る） | PNG3枚をGitHub上に保存、人物と機械は実Godot描画 |
| カジノ上部が完全に見えるか | FAIL | 世界y=4.17, z=-6.51の頂点はD2投影で画面上端より約21.19px上（実ログ）。画角固定ならファサード上縁は切れる |
| 同一通り全体を適法な歩行・床・カメラ範囲に収める | FAIL / NOT TESTED | x>30まで右側が出る。床・歩行領域・端の整合は未実装 |
| 3D仮配置と新ガイドの形状完全一致 | NOT TESTED（未達） | ガイドの山形屋根は仮3Dで未再現 |
| 完成した油彩カジノ画像の貼付 | NOT TESTED | 添付の完成イメージは実ファイルとしてGitHub取込していない。勝手に生成しない |
| あらゆるカメラ位置の遮蔽・住民の動線・衝突 | NOT TESTED | 撮影点は2つ、前景全走査はまだ |
| 実スマホのfps/タッチ/保存 | NOT TESTED | GitHub ActionsのLinux Godotのみ |

## 次のT4実行に必要な是正
1. **まず同じT4隔離ブランチで** 新街区の右端・床・カメラ移動限界・NPCの座標と動線・路地/光る看板のロジックまで座標データで一貫させる。今回のMeshInstance3Dだけ移すデバッグ方法を正式実装に転用しない。
2. D2は既承認なので変更しない。建物4.17m全高を保つ場合、画面外へ切れる屋根の装飾は視認性基準で再配置するか、ガイド/CGの上部クロップを先に評価する。
3. ガイドと3D投影の正確な一致を実画面で確認した後に、原画を既存実物として参照して油彩風の完成カジノ絵を制作。旧屋台のガイド・不採用画像は再利用しない。
4. 既存T2/T3コードとmainへは反映しない。T3 CI修正と最終独立レビューは別タスク。

**本報告はT4レイアウトの一次実験であり、T4受入完了を意味しない。**
