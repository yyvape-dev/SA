extends Node3D
signal safe_arrived(id: String)
var definition: Resource
var people := {}
var moving := false
var speed := 1.15

func configure(d: Resource):
    definition=d
    for i in d.resident_ids.size():
        var person=Sprite3D.new()
        person.texture=load("res://assets/npc/"+["woman_1","man_2","work_3"][i%3]+".webp")
        person.pixel_size=1.7/person.texture.get_height()
        person.position=d.routes[i][0]+Vector3(0,0.85,0)
        person.no_depth_test=false
        person.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(person)
        var mark=Label3D.new()
        mark.text="RESIDENT %d"%(i+1);mark.font_size=30;mark.pixel_size=0.008
        mark.position.y=1.2;mark.modulate=Color(0.5,1,0.8)
        person.add_child(mark)
        people[d.resident_ids[i]]={"node":person,"route":d.routes[i],"index":0,"safe":false,"mark":mark}

func start(): moving=true
func stop(): moving=false
func reset():
    moving=false
    for value in people.values():
        value.index=0;value.safe=false
        value.node.position=value.route[0]+Vector3(0,0.85,0)
        value.mark.text="RESIDENT"

func finish_all():
    moving=false
    for value in people.values():
        value.index=value.route.size()-1;value.safe=true
        value.node.position=value.route[-1]+Vector3(0,0.85,0)
        value.mark.text="SAFE"

func _physics_process(delta: float):
    if not moving:return
    for id in people:
        var value: Dictionary=people[id]
        if value.safe:continue
        var next: Vector3=value.route[mini(value.index+1,value.route.size()-1)]+Vector3(0,0.85,0)
        value.node.position=value.node.position.move_toward(next,speed*delta)
        if value.node.position.distance_to(next)<0.005:
            value.index+=1
            if value.index>=value.route.size()-1:
                value.safe=true;value.mark.text="SAFE";safe_arrived.emit(id)

func snapshot() -> Dictionary:
    var out := {}
    for id in people:
        var v:Dictionary=people[id]
        out[id]={"position":[v.node.position.x,v.node.position.y-0.85,v.node.position.z],"index":v.index,"safe":v.safe}
    return out
