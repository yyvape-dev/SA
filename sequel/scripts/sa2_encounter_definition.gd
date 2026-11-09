extends Resource
@export var version := 1
@export var event_id := "C2-09"
@export var map_id := "backtown"
@export var machine_ids := PackedStringArray(["machine-a","machine-b"])
@export var machine_positions := PackedVector3Array([Vector3(13.5,0,0),Vector3(15.3,0,0.6)])
@export var resident_ids := PackedStringArray(["resident-a","resident-b","resident-c"])
@export var routes: Array = []
@export var profile: Resource
@export var combat_bounds := Rect2(8,-1.8,9,3.6)
@export var blockers: Array = [Rect2(16.7,-2.0,0.18,4.0)]
@export var lily_start := Vector3(11.2,0,0)
@export var safe_marker := Vector3(10.8,0,-3.6)

func validate_definition() -> String:
    if version!=1 or event_id!="C2-09" or map_id!="backtown" or machine_ids.size()!=2 or resident_ids.size()!=3 or machine_positions.size()!=2 or routes.size()!=3:
        return "invalid encounter schema or counts"
    if profile==null or not profile.has_method("validate_profile") or profile.validate_profile()!="":
        return "invalid enemy profile"
    var ids: Dictionary={}
    for id in Array(machine_ids)+Array(resident_ids):
        if id.is_empty() or ids.has(id): return "duplicate/empty stable ID"
        ids[id]=true
    if not combat_bounds.position.is_finite() or not combat_bounds.size.is_finite() or combat_bounds.size.x<=0 or combat_bounds.size.y<=0: return "invalid combat bounds"
    for rect in blockers:
        if not rect is Rect2 or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<=0 or rect.size.y<=0: return "invalid blocker"
    for p in Array(machine_positions)+[lily_start]:
        if not p.is_finite() or p.y!=0 or not combat_bounds.has_point(Vector2(p.x,p.z)): return "invalid combat position"
        for rect in blockers:
            if rect.has_point(Vector2(p.x,p.z)): return "spawn in blocker"
    for route in routes:
        if not route is PackedVector3Array or route.size()<3 or route.size()>64 or route[0].y<2 or route[-1].distance_to(safe_marker)>0.5:
            return "invalid evacuation route"
        for p in route:
            if not p.is_finite(): return "invalid route coordinate"
        var geometry=load("res://scripts/sa2_street_combat_policy.gd").new()
        for i in range(1,route.size()):
            if route[i].y>route[i-1].y+0.01 or route[i].distance_to(route[i-1])>10: return "invalid route edge"
            if minf(route[i].y,route[i-1].y)<0.3:
                for rect in blockers:
                    if geometry.entry_fraction(Vector2(route[i-1].x,route[i-1].z),Vector2(route[i].x,route[i].z),rect)>=0:
                        return "evacuation route crosses closure"
    return ""
