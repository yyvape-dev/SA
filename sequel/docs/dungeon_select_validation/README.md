# 検証の再現

Godot 4.7.2を `godot` として使う。Webテンプレートも4.7.2。リポジトリ直下で:

```sh
godot --headless --path sequel --script res://tests/dungeon_select_layout_test.gd
godot --headless --path sequel --script res://tests/dungeon_select_state_test.gd
DUNGEON_TEST=1 timeout 900 godot --headless --disable-render-loop --path sequel --fixed-fps 60
WEB_OUT=../previews/sa2-dungeon python3 -I sequel/tools/export_web.py
python3 -I sequel/tools/serve_gzip.py previews/sa2-dungeon
```

ネイティブ撮影は仕様書6節のCAPTURE_MENU。開放あり／なしを別々に保存する。

今回のbotログは、同じmain.tscnを起動する監視ラッパー `bot_monitor.gd.txt` を /tmp/bot_monitor.gd にコピーし、上のbotコマンドへ `--script /tmp/bot_monitor.gd` を加えて取得した。監視は10秒ごとの出力だけでbotの挙動を変更しない。300秒制限の初回実行は時間切れ。

Web検証はChromium、844×390、タッチ有効。門からT2→ハード→ランカ選択→入場。dg1リクエストを18秒保留して待機画面を確認し、通信を再開してdg1/dg_t2のload_resource_pack成功まで待つ。

`capture-locked.log` の終了時解放警告は既知の観測事項。原因は未確定。iPhone実機は未検証。
