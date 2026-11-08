extends Resource
@export var kind := "cutting_machine"
@export var height_m := 1.45
@export var base_path := "res://assets/t3/"
@export var hp := 36.0
@export var damage := 16
@export var speed := 0.9
@export var attack_speed := 1.0
@export var clips: Dictionary = {}

func validate_profile() -> String:
    if kind.is_empty() or height_m<=0 or hp<=0 or damage<=0 or speed<=0 or attack_speed<=0 or clips.size()>64 or not clips.has("walk"):
        return "invalid profile values"
    var attacks := 0
    for key in clips:
        var c=clips[key]
        if not c is Dictionary or not c.get("frames") is Array or c.frames.is_empty() or c.frames.size()>1024 or float(c.get("h",0))<=0 or not c.get("face") in [-1,1]:
            return "invalid clip"
        for frame in c.frames:
            if not frame is Array or frame.size()!=7 or not frame[0] is String or frame[0].contains(".."):
                return "invalid frame"
            var tex=load(base_path+frame[0]) as Texture2D
            if tex==null or frame[1]<0 or frame[2]<0 or frame[3]<=0 or frame[4]<=0 or frame[1]+frame[3]>tex.get_width() or frame[2]+frame[4]>tex.get_height():
                return "invalid texture rectangle"
        if str(key).begins_with("atk"):
            attacks+=1
            if not c.get("durs") is Array or c.durs.size()!=c.frames.size() or not c.get("hit") is int or c.hit<=0 or c.hit>=c.frames.size():
                return "invalid attack timing"
            var tell:=0.0
            for i in c.durs.size():
                if not (c.durs[i] is int or c.durs[i] is float) or c.durs[i]<=0:
                    return "invalid duration"
                if i<c.hit: tell+=c.durs[i]/1000.0/attack_speed
            if tell<0.35: return "unreadable telegraph"
        elif float(c.get("fps",0))<=0:
            return "invalid animation fps"
    return "" if attacks>0 else "missing attack"
