extends SceneTree
func _initialize():
    var args=OS.get_cmdline_user_args()
    if args.is_empty() or not ProjectSettings.load_resource_pack(args[0],true):quit(1);return
    var required=["res://sa2_t3_playable.tscn","res://events/C2-09.tres","res://enemies/cutting_machine.tres","res://assets/t3/machine.svg","res://assets/lily/lily.json","res://assets/lily/lily_0.webp","res://assets/lily/lily_1.webp","res://assets/rana2/rana2.json","res://assets/npc/woman_1.webp","res://assets/npc/man_2.webp","res://assets/npc/work_3.webp","res://art/painted_bt/tex_iron.png","res://scenes/sa2_c2_09_routes.tscn","res://dialogues/ja/C2-09.json"]
    for path in required:
        if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
            printerr("T3_PACK_FAIL: ",path);quit(1);return
    if load("res://events/C2-09.tres").validate_definition()!="":quit(1);return
    print("SA2_T3_PACK_PASS: T3 scene/resource/JSON/image/market dependencies")
    quit()
