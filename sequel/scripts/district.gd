extends Node
## 地区 pck（2026-11-06）：地区ごとの絵（塗った部品・地面・映り込みの元）を本体の index.pck から外し、
## web/districts/<id>.pck として地区に入るときに読み込む。
##  - 版：本体の res://build_ver.json と、pck の中の res://districts/<id>_ver.json の "ver" を照らし合わせる。
##    ずれていたら（古い pck が残っていた等）ページを読み直す（同じ URL で無限に繰り返さないよう 1 回だけ）。
##  - 読み込みは load_resource_pack(..., false)：本体のファイル（project.binary 等）を上書きしない。
##  - 手元（エディタ・撮影）では絵が res:// にそのままあるので、落とさずに使う。

signal progress(ratio: float)
var last_error := ""   # 読み込めなかったとき、画面の隅に出す短い印（地区 結果 HTTPの番号）

func _download(url: String, file: String) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	http.download_file = file
	http.download_chunk_size = 4 * 1024 * 1024   # 既定の 64KB だと 1コマに 64KB しか受け取らず、遅い端末で何十秒もかかる
	var st := {"done": false, "res": [-1, 0]}
	http.request_completed.connect(func(r, code, _h, _b): st.res = [r, code]; st.done = true)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return [-2, err]
	while not st.done:
		var total := http.get_body_size()
		if total > 0:
			progress.emit(float(http.get_downloaded_bytes()) / total)
		await get_tree().process_frame
	http.queue_free()
	return st.res

static func build_ver() -> String:
	return _read_ver("res://build_ver.json")

static func _read_ver(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return str(d.get("ver", "")) if d is Dictionary else ""

## もう読み込み済み（または手元でファイルがある）か
func ensure_cached(id: String) -> bool:
	var have := _read_ver("res://districts/%s_ver.json" % id)
	return have != "" and (have == build_ver() or not OS.has_feature("web"))

## 地区 id の絵を使える状態にする。true＝使える。
func ensure(id: String) -> bool:
	var ver_path := "res://districts/%s_ver.json" % id
	var want := build_ver()
	var have := _read_ver(ver_path)
	if have != "" and have == want:
		return true
	if not OS.has_feature("web"):
		return have != ""      # 手元：ファイルがあれば使う
	var search := str(JavaScriptBridge.eval("window.location.search"))
	var url := str(JavaScriptBridge.eval("new URL('districts/%s.pck?v=%s', window.location.href).href" % [id, want.uri_encode()]))
	if search.contains("r="):
		url += "&r=" + search.get_slice("r=", 1).get_slice("&", 0)
	# 置き場所：ブラウザの保存領域（user://＝IndexedDB）には書かない。一時の場所（/tmp、メモリ上で残らない）に置く。
	# 2026-11-06 の事実：PC の Chrome で、user:// に置いた地区 pck が読めず、背景が仮の箱になった（保存領域への書き込みの失敗と推測）。
	for old in ["user://d1.pck", "user://dg1.pck"]:   # 前の版が保存領域に残した pck を消して場所を空ける
		if FileAccess.file_exists(old):
			DirAccess.remove_absolute(old)
	var file := "/tmp/sa_%s.pck" % id
	var res: Array = []
	for attempt in 2:   # 失敗したら1回だけやり直す
		res = await _download(url, file)
		if int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) == 200 and ProjectSettings.load_resource_pack(file, false):
			res = []
			break
		push_warning("district %s: 取得・読み込みに失敗 %s（%d 回目）" % [id, str(res), attempt + 1])
	if not res.is_empty():
		push_error("district %s: pck を読み込めない (%s)" % [id, str(res)])
		last_error = "%s %d %d" % [id, int(res[0]), int(res[1])]
		return false
	have = _read_ver(ver_path)
	if have != want:
		push_warning("district %s: 版がずれている（本体 %s / 地区 %s）" % [id, want, have])
		if not search.contains("r="):
			JavaScriptBridge.eval("location.replace(location.pathname + '?r=' + Date.now())")
			await get_tree().create_timer(30.0).timeout   # 読み直しを待つ
		return have != ""
	return true
