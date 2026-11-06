# Lana idle micro-motion test (non-destructive)

- Open `lana_idle.tscn` as the current scene. This is independent of `main.tscn`; **the existing greybox is unchanged**.
- Required original 941 x 1672 image: `res://fit_assets/lana_idle_original.png`. This binary file is **not in this branch**. Download it from the separately provided test ZIP or add your own source image at the same path.
- Plays a subtle 2.4s loop (breathing, wind on hair tips, raised hand motion). Feet and sword are nearly fixed.
- UV warp of original pixels; not AI frame redrawing, not bone-rigging or cutout part replacement.
- To capture 24 **actual Godot frames** (with an available Godot runtime): `CAPTURE_IDLE=1 godot --path godot-viewport-test --scene res://lana_idle.tscn`
- Compare the texture with shader material `strength=0` against `strength=1` before deciding whether the asset tolerates pixel deformation.
- Current limitation: shader UV interpolation can stretch sleeve/hair boundaries during wider animation; robust arm movement still needs accurate mechanical cutouts and a 2D skeleton.
- **Not runtime-validated in the assistant environment**: Godot executable was unavailable there.
