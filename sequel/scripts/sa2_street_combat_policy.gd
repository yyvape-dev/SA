extends RefCounted
## Opt-in street collision/target policy. Never installs itself in legacy scenes.
var bounds := Rect2(8,-1.8,9,3.6)
var blockers: Array = []
var roster := {}
var active := true

func register_actor(actor: Node3D, id: String, role: String, floor_id: String) -> bool:
    if id.is_empty() or not role in ["player","enemy"] or floor_id.is_empty():
        return false
    for entry in roster.values():
        if entry.id==id:
            return false
    roster[actor.get_instance_id()]={"id":id,"role":role,"floor":floor_id}
    return true

func unregister_actor(actor: Node3D):
    roster.erase(actor.get_instance_id())

func clear():
    roster.clear()

## Slab intersection returns earliest entry, -1 means no intersection.
func entry_fraction(from: Vector2, to: Vector2, rect: Rect2) -> float:
    var lo := 0.0
    var hi := 1.0
    var delta := to-from
    for axis in 2:
        if absf(delta[axis]) < 0.000001:
            if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
                return -1.0
        else:
            var a: float=(rect.position[axis]-from[axis])/delta[axis]
            var b: float=(rect.end[axis]-from[axis])/delta[axis]
            lo=maxf(lo,minf(a,b));hi=minf(hi,maxf(a,b))
            if lo>hi:
                return -1.0
    return lo

func resolve_motion(_actor: Node3D, from: Vector3, desired: Vector3) -> Vector3:
    var out := Vector3(clampf(desired.x,bounds.position.x,bounds.end.x),from.y,clampf(desired.z,bounds.position.y,bounds.end.y))
    var a := Vector2(from.x,from.z)
    var b := Vector2(out.x,out.z)
    var fraction := 1.0
    for rect in blockers:
        var hit := entry_fraction(a,b,rect)
        if hit>=0.0:
            fraction=minf(fraction,maxf(0.0,hit-0.001/maxf(0.001,a.distance_to(b))))
    return from.lerp(out,fraction)

func allows_damage(source: Node3D, target: Node3D, _spec: Dictionary) -> bool:
    if not active or not is_instance_valid(source) or not is_instance_valid(target):
        return false
    var a: Dictionary=roster.get(source.get_instance_id(),{})
    var b: Dictionary=roster.get(target.get_instance_id(),{})
    if a.is_empty() or b.is_empty() or a.role==b.role or a.floor!=b.floor or absf(source.position.y-target.position.y)>0.3:
        return false
    for rect in blockers:
        if entry_fraction(Vector2(source.position.x,source.position.z),Vector2(target.position.x,target.position.z),rect)>=0.0:
            return false
    return true
