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
