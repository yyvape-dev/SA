# T4 市場背景：既存構造に対する不足素材・制作契約（2026-11-09）
Status: asset gap VERIFIED IN SOURCE; visual assets NOT YET GENERATED / engine integration NOT TESTED.
Reference code: `sequel/scripts/backtown_block.gd` on `feat/sa2-t2-sequel-integration-20261108` (T2 HEAD `ddc2570` used for survey). This is T4 art planning, not permission to modify T3 Codex implementation.

## Decision
Do NOT reinvent background/parallax/layer structure. Existing backtown geometry, world-coordinate segments, stages, existing rendered material assets and foreground are retained. Produce only presently missing painted **front-facing shop blockout art** and one missing arcade stall. No new street panorama, ground texture, banner, sign, alley, foreground occluder or layer schematic until actual in-engine evidence of a gap.

Existing assets verified by GitHub directory listing:
- `sequel/art/painted_bt/`: 24 production PNG incl. 4 material textures `tex_brick/iron/plaster/boards`, `stall_food/crystal/parts`, `back_alley_1/2`, signs, pendants and foreground.
- `sequel/art/painted_bt_src/`: corresponding high-resolution source art for existing finished items.
- `sequel/assets/ground/cobble.png`, `slab.png` exist.
- `sequel/art/guide_bt/` contains flat-color shape guides and `guide.json`, including the five missing subjects.

## Exactly 5 missing art slots — no new layer work
| Asset | Source geometry / guide | Existing code | Target source canvas | Priority | Status |
|---|---|---|---|---|---|
| `w_bar_shack_low` | `art/guide_bt/w_bar_shack_low.png` | `backtown_block.gd` wall `n1_tavern`, x=-11.4..-4.0 | 1536×1024 | P0 | MISSING painted source |
| `w_cabaret_low` | `art/guide_bt/w_cabaret_low.png` | wall `n2_cabaret`, x=-2.0..5.2 | 1536×1024 | P0 | MISSING |
| `w_brothel_low` | `art/guide_bt/w_brothel_low.png` | wall `n3_brothel`, x=7.0..14.2 | 1536×1024 | P0 | MISSING |
| `w_shady_low` | `art/guide_bt/w_shady_low.png` | wall `n4_shady`, x=18.8..25.0 | 1536×1024 | P0 | MISSING |
| `stall_game` | `art/guide_bt/stall_game.png` | `STALLS` x=4.3, w=2.4m,h=3.0m; art="" and marked not ordered | 1024×1536 | P0 | MISSING |

Canvas values are from `guide_bt/guide.json` under `v2` and `v2_w_bar_shack_low`; they are guide/source canvases, not guarantees that the final clipped output uses these pixel dimensions. Exact crop and in-engine display are controlled by established `tools/cut_bt.py` / `art/painted_bt/cut.json` pipeline.

## Production instructions
1. Use the corresponding **original flat-color guide as the geometry reference** for each shop; do not repaint a derivative as new geometry. Strictly preserve openings, roof/post/counter edges, proportions, level, street-facing framing and door/stair positions. For `stall_game`, preserve the stall's 1024×1536 guide silhouette and separate foreground/interior as required by the existing cut pipeline.
2. Art: dark, crowded magically powered pleasure-quarter market; hand-painted digital-oil brush texture, deep violet shadows, weathered iron/bronze, restrained cyan/pink/green magic-tech light, warm amber deep open shop interiors. NOT clean modern bar, not photorealistic, not anime cel illustration. No legible sign text, no paper lantern dependency. Keep standing walkway readable, roofs/awnings consistent with adjacent blockouts.
3. These are separate wall/stall **assets**, not a whole-scene concept art collage. Preserve image coordinates and transparent/cutout conventions used by the neighboring originals. Do not hallucinate new building geometry or alter existing existing 3D segments.
4. Put the generated originals beside established `painted_bt_src` naming and pass them through existing trim/atlas/cut workflow to `painted_bt`; inspect actual code before changing mappings. Image model output dimensions, alpha and registration must be checked deterministically with Python/Pillow.
5. Test at native game scale in actual Godot backtown scene; screenshot before/after from matching viewpoint, record whether image clips/height/lighting/occlusion/collisions align. No generated concept art is proof of Godot fit.
6. Art delivered to the user for review first, before implementation branch asset replacement. When integration is approved, use a separate T4 branch and keep T3 implementer informed. Never modify `main` or unapproved story/T2 script.

## UI/T6 is distinct
Existing `sequel/scripts/touch_ui.gd` and `dungeon_hud.gd` provide controls, HP, skills and battle information. T3 Codex implementation is currently responsible for temporary 3 evacuee / 2 machine status display; final T6 skin/legibility redesign is later, after the first T3 in-engine footage. Do not redesign or change T3 logic in this T4 art task.

## Validation matrix
- Current geometry and missing slot identifiers: VERIFIED FROM SOURCE
- Source image artwork for five slots: NOT PRODUCED
- Godot screenshot/photo-real acceptance: NOT TESTED
- Mobile visual/interaction acceptance: NOT TESTED
