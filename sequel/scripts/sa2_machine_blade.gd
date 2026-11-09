extends Node3D
## Small greybox rotor: an unmistakable, rotating unmanned cutting tool.
var foe
var rotor:Node3D
func _ready():
    rotor=Node3D.new();rotor.position=Vector3(0.28,1.05,0.08);add_child(rotor)
    var mat=StandardMaterial3D.new();mat.albedo_color=Color(0.75,0.85,0.9);mat.metallic=0.75;mat.roughness=0.35
    var disc=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=0.28;cylinder.bottom_radius=0.28;cylinder.height=0.04
    disc.mesh=cylinder;disc.rotation.x=PI/2;disc.material_override=mat;rotor.add_child(disc)
    for i in 8:
        var tooth=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(0.14,0.13,0.05);tooth.mesh=box;tooth.material_override=mat
        var angle=i*TAU/8;tooth.position=Vector3(cos(angle)*0.3,sin(angle)*0.3,0);tooth.rotation.z=angle;rotor.add_child(tooth)
func _process(delta:float):
    if is_instance_valid(foe):rotor.rotation.z+=delta*(22.0 if foe.state=="atk" else 2.0)
