extends RefCounted
## Presentation data only: no mutation of battle/skill resources.
static func meter(hp:float,maximum_hp:float,charge:float,maximum_charge:float,cost:float)->Dictionary:
 var maximum=maxf(0,maximum_charge)
 var available=clampf(charge,0,maximum)
 var marks=[]
 if maximum>0 and cost>0:
  for i in range(1,int(floor(maximum/cost))+1):marks.append(float(i)*cost/maximum)
 return {"health_fraction":clampf(hp/maximum_hp,0,1) if maximum_hp>0 else 0.0,"charge_fraction":available/maximum if maximum>0 else 0.0,"stock":int(floor(available/cost)) if cost>0 else 0,"thresholds":marks}
