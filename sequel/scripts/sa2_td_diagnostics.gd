extends RefCounted
var path:='user://sa2_td_probe.json'
var samples:Array[float]=[]
func sample(delta:float):
    if delta>0:samples.append(delta*1000.0)
    if samples.size()>300:samples.pop_front()
func report()->Dictionary:
    if samples.is_empty():return {'mean_ms':0.0,'p95_ms':0.0,'frames':0}
    var ordered=samples.duplicate();ordered.sort()
    var total:=0.0
    for value in samples:total+=value
    return {'mean_ms':total/samples.size(),'p95_ms':ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)],'frames':samples.size()}
func write_probe(token:String)->bool:
    var f=FileAccess.open(path,FileAccess.WRITE)
    if f==null:return false
    f.store_string(JSON.stringify({'schema':1,'token':token}));f.flush();f.close()
    return read_probe().get('token','')==token
func read_probe()->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var parser=JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path))!=OK:return {}
    var data=parser.data
    if not data is Dictionary or data.get('schema')!=1 or not data.get('token') is String:return {}
    return data
