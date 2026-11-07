# REEBOO FX2D (Stylized 2D VFX Lite)

Four 2D effects for Godot 4.4+: hit_spark, slash_arc, explosion_small, coin_pickup.

```gdscript
const HIT := preload("res://addons/reeboo_fx2d/effects/hit_spark.tscn")
var fx := ReebooFx2D.spawn(HIT, self, global_position)  # frees itself when done
fx.impact.connect(func(strength: float) -> void: print("shake the camera by ", strength))
```

MIT licensed, see LICENSE in this folder. Source and demo: https://github.com/REEBO0/godot-stylized-2d-vfx-lite
The full pack has 26 effects: https://reeboolabs.itch.io/stylized-2d-vfx-godot
