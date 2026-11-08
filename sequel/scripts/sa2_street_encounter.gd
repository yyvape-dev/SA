extends RefCounted
const Flow = preload("res://scripts/sa2_flow_state.gd")
signal phase_changed
var definition: Resource
var store: RefCounted
var phase := "explore"
var candidate := ""
var stopped := {}
var safe := {}
var checkpoint := {}
var attempt := 0
var flow = Flow.new()

func begin(cp: Dictionary) -> bool:
    if not phase in ["explore","safe"] or not store.valid_checkpoint(cp): return false
    var next=Flow.new()
    next.attempts=flow.attempts.duplicate(true)
    next.begin_dialogue(definition.event_id,Vector3.ZERO)
    next.finish_dialogue()
    next.enter_battle(definition.event_id,Vector3.ZERO)
    var payload=_payload("street",cp,next,attempt+1)
    if not store.save_payload(payload): return false
    flow=next;checkpoint=cp.duplicate(true);attempt+=1
    stopped.clear();safe.clear();candidate="";phase="street"
    phase_changed.emit()
    return true

func record_stopped(id: String) -> bool:
    if phase!="street" or not definition.machine_ids.has(id) or stopped.has(id): return false
    stopped[id]=true
    return true

func record_safe(id: String) -> bool:
    if phase!="street" or not definition.resident_ids.has(id) or safe.has(id): return false
    safe[id]=true
    return true

func evaluate(hp: float):
    if phase!="street": return
    if hp<=0: candidate="lose"
    elif stopped.size()==definition.machine_ids.size() and safe.size()==definition.resident_ids.size(): candidate="win"
    else: return
    phase="result_pending"
    phase_changed.emit()

func _payload(next_phase: String, cp: Dictionary, next_flow, count: int) -> Dictionary:
    return {"schema":1,"definition_version":definition.version,"event_id":definition.event_id,"map_id":definition.map_id,"phase":next_phase,"attempt":count,"checkpoint":cp.duplicate(true),"flow":next_flow.to_dict()}

func commit_result() -> bool:
    if phase!="result_pending": return false
    var next=Flow.new()
    next.restore(flow.to_dict())
    next.finish_battle(candidate=="win")
    next.return_to_explore()
    var next_phase="complete" if candidate=="win" else "safe"
    if not store.save_payload(_payload(next_phase,checkpoint,next,attempt)): return false
    flow=next;phase=next_phase
    phase_changed.emit()
    return true

func restore_payload(payload: Dictionary) -> bool:
    if not store.valid_payload(payload): return false
    checkpoint=payload.checkpoint.duplicate(true);attempt=int(payload.attempt)
    flow.restore(payload.flow)
    phase=payload.phase
    # Interrupted combat returns to the pre-battle checkpoint, never live enemy HP.
    if phase=="street":
        flow.finish_battle(false);flow.return_to_explore();phase="safe"
    candidate="";stopped.clear();safe.clear()
    if phase=="complete":
        for id in definition.machine_ids:stopped[id]=true
        for id in definition.resident_ids:safe[id]=true
    phase_changed.emit()
    return true
