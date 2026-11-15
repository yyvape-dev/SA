# Combat HUD polish implementation plan

Goal: polish all battle gauges and skill illustrations in the approved imperial magitech visual family, while keeping gameplay, skill contents, input placement and existing expedition UI intact.
Architecture: new combat_hud_art.gd and separate icon/material resources; touch_ui.gd delegates presentation, dungeon_hud.gd delegates boss health and removes duplicate bare level/XP/weapon strip. Existing control geometry and attack/cost/cooldown/progression APIs remain unchanged.
Reference: docs/combat_hud_polish/visual_target.png, specs/skill_ui.md; user confirmed all gauges.

- [x] Generate only reusable frame/gauge/button assets and actual character skill icons. Store original sheets under .gdignore; native lossless crops; record provenance and pixel equality. Retain adopted portraits, no character redraw.
- [x] Add RED→GREEN tests for displayed health/charge/usable-stock model, active/empty/party/manual states, cost-based thresholds, missing skills; retain existing touch target geometry. Render presentation at844x390 with readable cooldown seconds and clearly distinct skills.
- [x] Implement blue player/ally HP, violet actual ultimate charge, gold ready count, compact XP/weapon/level, red boss HP. Same physical touch positions; CD ring based on actual cooldown, ready/pressed/unavailable visual states, no UI words.
- [x] Test native status fixtures, actual combat and buttons, progression bot, Web export and touch screenshots. Preserve exact gameplay methods and inspect PCK excluding raw sources.
- [ ] Push source branch, update HANDOFF/spec/results, publish only previews/sa2-dungeon/ on main, verify Pages/public URL.

Constraints:844x390 battle remains visible; existing actual targets>=44px; retain blue friendly, red enemies, gold readiness; no static fake fractions, no fixed half-charge assumption (ult_cost varies by skill level). UI illustrations preserve aspect; frame surfaces may nine-slice. main.gd and combat logic unchanged.
