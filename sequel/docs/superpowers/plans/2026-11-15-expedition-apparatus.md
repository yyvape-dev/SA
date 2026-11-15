# Expedition apparatus UI implementation plan

> Execute inline with superpowers:executing-plans. User approved the generated world-design board and explicitly requested implementation.

Goal: reproduce the adopted four-screen arcane expedition apparatus as functional Godot UI.
Spec: docs/dungeon_select_mock_v2/README.md, mock_board_world_design.png, specs/dungeon_select_ui.md.
Architecture: presentation-only dungeon_select_art.gd delegates texture assets and layout; preserve protected dungeon_hud.gd progression methods and main.gd party flow. Loading reuses the same instrument, enemy, risk and chosen portraits with real district progress.
Tech: Godot4.7.2/Web, image_gen component artwork, lossless WebP exact crop/slice, existing enemy sprite frames/portraits.

Constraints: no words; blue friendly/normal, red hard, red+gold expert; >=44px at844x390; shared tap/render rectangles including shake. No resampling source art. Main publishes previews/sa2-dungeon only. Recommendation is informational, numeric values require user confirmation.

- [x] Generate instrument backing and component sheet from adopted board; preserve originals, record slices/provenance, verify lossless pixels and art bounds. Crop existing first-frame enemies without resizing into small UI resources.
- [x] Change layout/state tests first for separate map enemy slips, full window difficulty, 3 portraits+2 future mounts, distinct next/activation buttons. Observe old layout fail. Implement shared layout and textured drawing without touching protected flow methods.
- [x] Reproduce loading instrument with same entrance/enemy/risk/party; actual progress or indeterminate light, reset on retry, no false completion.
- [x] Import and run layout/state tests, native captures locked/unlocked, bot regression, Web export and844x390 touch flow. Compare actual844x390 captures to adopted mock. Review tap alignment, locked/unavailable/selected states, progress/party preservation.
- [x] Update HANDOFF/spec/results and source branch, publish only preview subtree against latestmain using fast-forward push, verify Pages+publicURL.

Review focus: thumbnails must not add district enemy atlases to main; dialogue stage no hidden map-node taps; future mounts remain44px; current/desired party count no silent changes; loading initiation/progress/end synchronize exact mission context; image crop pixels unchanged.
