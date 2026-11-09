# T3 CI録画のPNG保存先修正

## 確認した原因

新規CI実行42539298815の録画ステップは `ERROR: Can't save PNG at path: '/workspace/sa2-t3-evidence/captures/t3-win.png'.` で失敗した。Actionsは`/tmp/t3-captures`を作成するが、T3_SCREENSHOTを渡していなかった。input testの環境固有fallbackがローカルworkspaceを指していた。ゲーム正常系自体の失敗ではなく、正常系の末尾のPNG保存エラーをログ検査が検出した。

## 限定修正

- Actions録画ステップへ`T3_SCREENSHOT=/tmp/t3-captures/t3-win.png`を明示しPNGもartifactに収録。
- 未設定または空のT3_SCREENSHOTはGodotの書込可能な`user://t3-win.png`に保存。
- save_pngの戻り値を検査し、指定保存先が無効ならテスト自体を失敗させる。エラーを無視しない。
- ゲームコード、保存schema、T2、正式素材、mainブランチは変更しない。

## 検証

RED証拠は[実CI失敗ログ](sa2_t3_evidence/ci-screenshot-failure.log)。GREENと新規CI結果は本ファイルの追記および実行URLで確認する。固定fps録画を性能測定として扱わない。

明示指定の実Godot正常系はPASS。`/tmp/t3-captures/t3-win.png`生成とsave_png戻り値OK、機械停止/避難/同一街帰還を確認した。ログは`sa2_t3_evidence/screenshot-explicit-green.log`。

T3_SCREENSHOTをunsetした別user領域での実Godot正常系もPASS。`user://t3-win.png`が生成され、PNGのdecode検証も両保存先で成功。ログは`sa2_t3_evidence/screenshot-default-green.log`。修正後CI対象コミットは`4466a2a597aa8960d96c19b5182d68599dbdd531`、実行は https://github.com/yyvape-dev/SA/actions/runs/42541909216 。

## 新規GitHub CI結果（2026-11-09 JST確認）

**PASS**: https://github.com/yyvape-dev/SA/actions/runs/42541909216 。対象4466a2a。回帰ステップ、pack依存検証、正常/敗北/再起動録画、MP4全フレームdecode、PNGを含むartifactアップロードが全て成功。結果JSONを`sa2_t3_evidence/ci-screenshot-fix-result.json`へ保存。

CI成果物のローカルダウンロードはAzure配信先から403で拒否されたため、その取得と独立decode/目視は未実施。CI内のdecode成功とローカルでのPNG decode/目視成功は別の証拠として扱う。本変更はテスト保存先とCI設定のみの低リスク修正であり、独立コードレビューを再実施したとは主張しない。物理端末/Webの未検証範囲は変わらない。
