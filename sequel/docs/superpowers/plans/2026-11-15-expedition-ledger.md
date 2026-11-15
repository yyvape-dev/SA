# Execution ledger: 2026-11-15-expedition-apparatus.md

- User approved world-design mock and implementation. Existing isolated feature branch is used; main source stays unchanged.
- Art: 3 source sheets generated; 23 native-resolution runtime crops; exact lossless pixel comparison passed. Raw sheets have .gdignore; original enemy/bust crops preserve pixels. Runtime frames fit aspect; blank paper/cloth/glass borders use nine-slice only.
- Layout: new test observed RED (missing enemy badges, active hidden map nodes). GREEN at844x390 and1280x720 including transition frames, all targets44+, nonoverlap, shared shake bounds. HUD input added enemy-slip hit route only.
- State: locked/unavailable/future/party-cap/back and same-event enemy-slip tap+feedback pass. Loading snapshots theme,difficulty,chosen array and uses actual district progress with retry reset.
- Review important1: retained menu_stage gave stale mission during town-floor transition. Reproduced RED town-context assertion; fixed using existing main.town_floor_busy guard without modifying main.gd; state suite GREEN.
- Review important2: reviewer suspected raw PNG export. Existing .gdignore does exclude them: previous exported PCK contains no art/ui_source paths. Final export will independently verify new sheets too; no startup payload claim until manifest inspected.
- Unresolved user data: recommendation4/10/18/26 was explicitly described as mock data; async question sent. RECOMMENDED remains0 (hidden) until reply, never a progression gate.
- Full original bot: DUNGEON DONE, final run log in /workspace/ui-evidence/apparatus/dungeon-test.log. Native unlockedmenu0–5 completed, party lily+ranka. Locked capture running.
