# Dungeon selection UI implementation plan

> Execute inline using superpowers:executing-plans. User authorized full implementation and preview publication.

Goal: implement A–H in specs/dungeon_select_ui.md without changing progression or party interfaces.
Architecture: keep dungeon_hud.gd state functions; extract a presentation-only DungeonSelectArt helper. Paths and hit rectangles share one layout function. Loading reuses the same map and selected entrance, with real download progress.
Tech: Godot 4.7.2 Compatibility, Web no threads, Pillow for lossless image packaging and QA previews.

Constraints: no words; numbers allowed; blue normal/friendly, red hard, red+gold expert; every action >=44px at 844×390; immediate feedback <100ms; preserve original pixels and aspect; only previews/sa2-dungeon goes to main. User confirmed gate+four themes and two future ally slots.

- [ ] Task 1: record baseline; add layout test for sizes 844×390 /1280×720, overlap and minimum targets; observe current close/go failing. Import art without resizing, compare processed/full-size originals; map <=2MB.
- [ ] Task 2: implement A–G in dungeon_select_art.gd and delegate only presentation functions from dungeon_hud.gd; preserve open_menu/choose_theme/choose/toggle_ally/go/menu_back/party_cap and main party code exactly. Add input flash and reduce transient input guard to <=50ms. Test all states/locked routes/ready and unavailable allies.
- [ ] Task 3: implement H in loading.gd, connect existing district progress signal, use selected theme art; keep startup/error semantics. Verify unknown progress not falsely shown as completion.
- [ ] Task 4: Godot captures menu_0–5 unlocked+locked, DUNGEON_TEST keys and runs; Web export to ../previews/sa2-dungeon, inspect pck membership, serve gzip and tap at 844×390. Compare with official DFO screenshot and answer five questions in report.
- [ ] Task 5: review interfaces and changed files; update HANDOFF/spec with facts/hypotheses and evidence, commit/push source feature branch; publish only preview tree to latest main with lease and confirm Pages and public URL.

Review focus: close remains reachable in all stages; wide views preserve map aspect; diff/party animations cannot desync hit areas; locked assets visibly distinguish unavailable vs unselected; real loading progress and error path remain truthful.
