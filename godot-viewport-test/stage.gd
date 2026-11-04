extends Node3D
var cam: Camera3D
var player: Sprite3D
var base_x := 0.0
var capture_i := 0

func _ready() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#66758b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#b2b5c3")
    env.ambient_light_energy = 0.85
    env_node.environment = env
    add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-25,0)
    sun.light_energy = 1.2
    sun.light_color = Color("#ffdda8")
    sun.shadow_enabled = true
    add_child(sun)
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("#968f8a")
    floor_mat.albedo_texture = _stone_texture()
    floor_mat.uv1_scale = Vector3(12,1,3)
    var wall_mat := StandardMaterial3D.new()
    wall_mat.albedo_color = Color("#757989")
    var trim_mat := StandardMaterial3D.new()
    trim_mat.albedo_color = Color("#504758")
    var gold_mat := StandardMaterial3D.new()
    gold_mat.albedo_color = Color("#ba985b")
    _block("Perspective floor",Vector3(0,-0.25,0),Vector3(60,0.5,11),floor_mat)
    for x in range(-14,15):
        _block("rear wall",Vector3(float(x)*2,1.8,-6),Vector3(1.94,3.6,0.7),wall_mat)
    for x in [-22.0,-12.0,-2.0,8.0,18.0,28.0]:
        _pillar(x,-4.6,wall_mat,trim_mat,gold_mat)
    for x in [-9.0,12.0]:
        _pillar(x,3.65,wall_mat,trim_mat,gold_mat)
    for x in [-22.0,22.0]:
        _block("turret",Vector3(x,3.1,-8),Vector3(4,6.2,3.6),wall_mat)
    var sprite := Sprite3D.new()
    sprite.name="Original character image"
    sprite.pixel_size=0.00215*607.0/100.0
    sprite.position=Vector3(-1.2,1.6,0.7)
    sprite.shaded=false
    sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
    var b64 := FileAccess.get_file_as_string("res://character.b64").strip_edges()
    var packed := Marshalls.base64_to_raw(b64)
    var img := Image.new()
    var err := img.load_png_from_buffer(packed)
    print("CHARACTER_TEXTURE_LOAD=",err," ",img.get_width(),"x",img.get_height())
    if err==OK:
        sprite.texture=ImageTexture.create_from_image(img)
    add_child(sprite)
    player=sprite
    cam=Camera3D.new()
    cam.fov=45.0
    cam.position=Vector3(-1.2,6.8,17.0)
    add_child(cam)
    cam.look_at(Vector3(-1.2,1.25,-0.8),Vector3.UP)
    cam.current=true
    if OS.has_environment("CAPTURE_STAGE"):
        _capture()

func _block(label:String,p:Vector3,dimensions:Vector3,material:Material)->void:
    var m:=MeshInstance3D.new()
    m.name=label
    var mesh:=BoxMesh.new()
    mesh.size=dimensions
    m.mesh=mesh
    m.material_override=material
    m.position=p
    add_child(m)

func _pillar(x:float,z:float,m:Material,t:Material,g:Material)->void:
    _block("footing",Vector3(x,0.3,z),Vector3(1.5,0.6,1.5),t)
    _block("column",Vector3(x,3.0,z),Vector3(0.9,5.0,0.9),m)
    _block("capital",Vector3(x,5.6,z),Vector3(1.6,0.35,1.6),g)

func _stone_texture()->Texture2D:
    var im:=Image.create(256,256,false,Image.FORMAT_RGB8)
    for y in range(256):
        for x in range(256):
            var joint := x%64<3 or y%64<3
            var grain := float((x*31+y*17+(x*y)%47)%29)/255.0
            var base := Color("#58545a") if joint else Color(0.56+grain,0.54+grain,0.52+grain)
            im.set_pixel(x,y,base)
    return ImageTexture.create_from_image(im)

func _capture()->void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
    for i in range(3):
        player.position=Vector3(-1.2+float(i)*2.0,1.6,2.8-float(i)*2.4)
        cam.position.x=player.position.x
        for j in range(30):
            await get_tree().process_frame
        await RenderingServer.frame_post_draw
        var picture:=get_viewport().get_texture().get_image()
        var path:=ProjectSettings.globalize_path("res://captures/actual_%02d.png" % i)
        var error:=picture.save_png(path)
        print("ACTUAL_GODOT_CAPTURE=",path," ERROR=",error)
    get_tree().quit()
