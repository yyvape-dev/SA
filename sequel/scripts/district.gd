extends Node
## 地区 pck（2026-11-06）：地区ごとの絵（塗った部品・地面・映り込みの元）を本体の index.pck から外し、
## web/districts/<id>.pck として地区に入るときに読み込む。
##  - 版：本体の res://build_ver.json と、pck の中の res://districts/<id>_ver.json の "ver" を照らし合わせる。
##    ずれていたら（古い pck が残っていた等）ページを読み直す（同じ URL で無限に繰り返さないよう 1 回だけ）。
##  - 読み込みは load_resource_pack(..., false)：本体のファイル（project.binary 等）を上書きしない。
##  - 手元（エディタ・撮影）では絵が res:// にそのままあるので、落とさずに使う。

signal progress(ratio: float)

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
	var http := HTTPRequest.new()
	add_child(http)
	var file := "user://%s.pck" % id
	http.download_file = file
	http.download_chunk_size = 4 * 1024 * 1024   # 既定の 64KB だと 1コマに 64KB しか受け取らず、遅い端末で何十秒もかかる
	var st := {"done": false, "res": []}
	http.request_completed.connect(func(r, code, _h, _b): st.res = [r, code]; st.done = true)
	http.request(url)
	while not st.done:
		var total := http.get_body_size()
		if total > 0:
			progress.emit(float(http.get_downloaded_bytes()) / total)
		await get_tree().process_frame
	var res: Array = st.res
	http.queue_free()
	if not ProjectSettings.load_resource_pack(file, false):
		push_error("district %s: pck を読み込めない (%s)" % [id, str(res)])
		return false
	have = _read_ver(ver_path)
	if have != want:
		push_warning("district %s: 版がずれている（本体 %s / 地区 %s）" % [id, want, have])
		if not search.contains("r="):
			JavaScriptBridge.eval("location.replace(location.pathname + '?r=' + Date.now())")
			await get_tree().create_timer(30.0).timeout   # 読み直しを待つ
		return have != ""
	return true
