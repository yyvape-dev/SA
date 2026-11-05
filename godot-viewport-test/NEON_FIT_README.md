# Neon environment fit test

Source: existing generated neon background and six previously extracted transparent props. **No new image generation.**

Run scene: `res://neon_fit_test.tscn` in the Godot project `godot-viewport-test/`.

## Assets still to be transferred

The GitHub connector supports UTF-8 file writing, but it does not transfer the local binary PNGs used here. Download `SA_Godot_neon_fit_pack.zip` from the conversation and copy the following to `godot-viewport-test/fit_assets/`:

- neon_bg.png
- pole.png
- bike.png
- car.png
- fence.png
- pipes.png
- barricade.png

These seven image files have **not** been added to this GitHub branch. The scene is not runnable as intended until the asset files are present.

The original `main.tscn`, `scripts/stage.gd`, and `main` branch are unchanged.

This is a placement-only prototype. Image transparency fringes, position, scale, world depth, camera clipping and actual screenshots require validation in Godot.
