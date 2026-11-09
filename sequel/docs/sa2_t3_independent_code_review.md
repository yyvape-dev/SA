# Independent SA2 T3 whole-branch review

Reviewed revision: `5ff6195`, base `ddc257067b82f0c796cdbc9c1becc46f7bc7a12e`, branch `feat/sa2-t3-street-encounter-20261108`. Source/index/branch were not modified. This report reviews the locked commit; subsequent author fixes and benchmark harness changes require their own verification.

Read actual audit AGENTS, the three required handoff/plan references, approved design v2 and independent design review, implementation plan and progress ledger. Applied requesting-code-review/code-reviewer, receiving-code-review, quality-gate and tool-routing guidance. No further agents dispatched. Read all added implementation components, shared diffs, test scripts, packaging/CI and relevant inherited Main/Player/Ally/Enemy/TouchUI/DungeonHud/Flow paths. Reviewed supplied regression raw JSON/logs; no engine was launched by this reviewer while the author ran performance measurements.

## Assessment

**With fixes; not ready for final acceptance at reviewed revision.** No Critical finding. One High and four Medium findings below. All defect mechanisms below are static source inference unless explicitly identified as supplied measured evidence. The author must reproduce the findings, implement scoped fixes, run meaningful regressions, and report results; this review does not claim those steps have already happened.

Strengths: scoped composition preserves the existing Level and unchanged T2 Manual; null policy retains original shared calculations. Both separation displacements and within-attack dash are hooked before damage. Machine IDs and safe IDs are independently deduplicated, HP0 is evaluated before the success conjunction, and the pending barrier freezes combat before publishing durable completion. The writer verifies staged files, preserves a validated backup and never promotes temporary completion. T3 kill handling avoids inherited reward writes. Supplied logs show the existing 20 regression/input/restart cases passing, including real natural enemy damage, route completion, and 20 stable-node retries; these are useful evidence but omit the cases below.

## H1 — High: existing skill-slot menu can retain ownership when the encounter starts

Location: `sequel/scripts/sa2_t3_host.gd:83`, `sequel/scripts/sa2_control_lease.gd:9` (inherited causal paths: `sequel/scripts/dungeon_hud.gd:88`, `:97`, `:140`).

Trigger: before starting, use the existing exploration gear to open skill slots, then press SPACE. `DungeonHud.open_slots()` locks Rana and sets `battle.process_mode=PROCESS_MODE_DISABLED`. Its `_input` branch does not consume SPACE; the T3 host checks only readiness/save/phase and starts while this modal still owns input. The lease neither captures nor neutralizes the inherited modal/process mode. `battle.set_physics_process(true)` cannot override inherited `PROCESS_MODE_DISABLED`, so machines cannot run normally. Subsequently K is consumed by the old modal and `close_slots()` assigns `main.player.locked=false` after `main.player` has become Lily, which has no `locked` property; that errors before restoring Battle's process mode. The original locked Rana state is also what the lease saves for restoration.

Impact: reachable mixed exploration/touch/keyboard sequence disables enemy simulation and produces a script error, breaks guard input, and can return locked exploration controls. The approved input lease contract requires exclusive ownership.

Scoped fix: reject start while the inherited slots/menu/result modal owns input, or explicitly close/suspend the modal while Rana still owns it before capture. Do not replace legacy global input architecture. Capture/restore process ownership if the lease permits entry from nondefault process modes. Add an actual gear-touch→SPACE→K regression; verify no battle starts through the modal, no error occurs, then close normally and complete a normal start/return.

Evidence: static call/event path, not reviewer-run reproduction. Author notified to reproduce after benchmarks.

## M1 — Medium: the persistent closed fence loses collision on exploration return

Location: `sequel/scripts/sa2_t3_host.gd:79`, `:140` and `sequel/scripts/sa2_control_lease.gd:27`.

Trigger: after loss or victory, return to Rana exploration and move/dodge across x=16.7..16.88 at z=0. `_clear_combat()` removes the only motion policy while the fence remains drawn and `passage_closed=true` remains saved. Rana's original room bounds allow movement across this x range; Player has no T3 fence hook. On fresh completed-save load the policy is never installed at all. Battle's lower combat bounds also remain changed after live combat because the lease does not restore them, unlike fresh restart; Lily's restored companion physics therefore sees different world bounds live versus after restart.

Impact: the saved/announced closed boundary is visual only in exploration, and postbattle world limits differ between live restoration and restart. This does not request free upper-floor movement or new passage restrictions; it enforces the existing T3 declared fence and restores existing exploration state.

Scoped fix: preserve a T3 exploration constraint for the declared closed fence using the host/adapter boundary, with swept Rana movement including dodge, and save/restore Battle's previous room/belt bounds. Keep the combat damage roster disabled in exploration and do not change legacy Player behavior globally. Test both live win/loss return and a fresh completed-save process, crossing from both directions; compare Battle bounds with prebattle values.

Evidence: static source inference. Author informed; no new engine run by reviewer.

## M2 — Medium: checkpoint validation accepts arbitrary Battle property restoration

Location: `sequel/scripts/sa2_street_checkpoint.gd:34` and `sequel/scripts/sa2_street_snapshot.gd:41`.

Trigger: add `checkpoint.battle.auto_spawn=true` to an otherwise valid payload and save through `save_payload()` (which computes a valid checksum). Validation checks required fields but never rejects extra Battle keys. Restore iterates every supplied key and calls `host.battle.set(key,value)`. Thus the loaded checkpoint can enable normal automatic enemy spawning after `_ready` has disabled it; extra `player`/`combat_policy` fields can also target ownership properties outside the snapshot schema. A checksum detects accidental byte corruption; it does not replace schema validation of a checksummed envelope.

Impact: malformed/unknown checkpoint fields can mutate live state outside the approved restore contract, including reintroducing ordinary enemies into this slice. Current writer output does not normally produce these keys; this is an explicit malformed-data/recovery contract gap, not a claim of naturally occurring checksum bypass.

Scoped fix: require the exact supported Battle key set in validation and iterate the fixed allowlist in restoration. Reject invalid/extra fields before live mutation; also retain existing required-ID and phase checks. Add checksummed malformed-envelope tests for extra `auto_spawn`, `player` and `combat_policy`, asserting rejection plus unchanged live state and last-good files.

Evidence: static source inference; author notified with concrete fixture.

## M3 — Medium: route data validation accepts crossing the declared closure

Location: `sequel/scripts/sa2_encounter_definition.gd:31`.

Trigger: insert a lower-floor waypoint `Vector3(16.8,0,0)` immediately before a shipped route's safe endpoint. Heights remain nonincreasing, all segment distances remain below 10, the safe endpoint stays correct, so `validate_definition()` accepts it. Evacuation then walks directly into/across the x=16.7..16.88 closed fence. No route edge is checked against blockers, although approved design v2 explicitly requires closed-region intersection rejection before starting.

Impact: editing route data can silently violate safe geography instead of failing closed. Shipped three routes do not intersect that blocker; this is a concrete validation and future data-editing gap, not an observed shipped-route collision.

Scoped fix: check relevant lower-floor route segments against declared closure geometry with the existing segment/slab logic, accounting explicitly for the dedicated upper-to-lower connection. Add invalid route fixtures entering a blocker and tunneling through it; keep all three approved routes accepted. No generic navigation graph or DSL is needed.

Evidence: static geometry/code inference; author notified.

## M4 — Medium: the current asset performance case measures reused textures, not increased residency/load

Location: `sequel/tests/sa2_t3_perf.gd:39` (locked revision), inherited `sequel/scripts/main.gd:1630`.

Trigger/evidence: `extras` loads the first sorted images from `art/painted_bt`; these 24 names are already referenced by the existing backtown scene and its retained `_bt_art` texture cache. The supplied in-progress real X11/llvmpipe `performance.json` has identical `texture_bytes=489347168` for `t3-2` and `asset24` repeat 1. Additional sprites/draw calls exist, but the test does not establish an increase in distinct nonresident texture residency or resource load time.

Impact: labeling this as asset-volume/load scaling would overstate what was measured. Existing frame results remain valid for extra visible sprite instances with resident textures. This is a benchmark-contract issue, not evidence of a production memory leak or a device performance limit.

Scoped fix: retain and relabel this case as resident-texture sprite growth; add a separate case selecting previously uncached image resources, record before/after cache state and texture bytes/counts, or mark unique asset residency/load scaling NOT TESTED. Keep completed evidence; no reason to rerun unaffected cases. Author has acknowledged and is preparing the separate nonresident case.

## Three-axis coverage

1. **Correctness/regressions: FAIL at reviewed revision** pending H1/M1/M2/M3 verification and fixes. Reviewed HP/gauges/cooldown restoration, actor safe normalization, exclusive Manual/AI ticking, all current movement/damage hooks, both success orders, failure-first tie, ordinary reward exclusion and save current/backup/temp ordering. Supplied tests PASS for their covered cases; write-fault tests currently force the first writer failure, and do not separately demonstrate backup-write/backup-rename/final-rename failure boundaries. Expand failure injection at those actual disk boundaries before claiming exhaustive persistence-fault acceptance. RESULT_PENDING intentionally remains a frozen live barrier; a crash while its save fails returns to the prior durable STREET checkpoint, matching design v2 rather than promoting temporary victory.

2. **Maintainability/extensibility: CONDITIONAL PASS with bounded limitations.** A same-AI machine appearance/animation/HP/speed can be supplied via one profile plus textures. New AI/abilities still require Enemy/Ally code and review; profile Resources do not make arbitrary behavior data-only. Host reads machine IDs/positions/routes from the definition, but event ID/counts, start assets, blade attachment, labels, fence mesh geometry and HUD totals remain C2-specific code/defaults. Another event is not a new `.tres` alone: Definition.validate_definition, host preload/visual choices, HUD totals and Flow's event whitelist require explicit work. This is acceptable for the approved single encounter if documented honestly. Route validation gap M3 should be fixed before relying on data-only geometry edits. No large dialogue text is embedded; formal dialogue/audio/art and new quest semantics remain deferred. New textures use existing Godot resource caching; dynamic profile validation loads references but does not retain a complete separate prewarm manifest for arbitrary future multichannel profiles, so future asset-prewarm claims need verification.

3. **Performance/scaling: PARTIALLY MEASURED; final acceptance NOT TESTED by this reviewer.** Reviewed the committed real-engine harness plus the author's in-flight corrected harness (extra machines now attach the shipped blade visuals), runner and partial raw X11/llvmpipe rows. These use wall-clock 2s warmup/6s collection with no fixed-fps recording, Godot 4.7.2, 1280×720, opengl3/software rendering. At inspection repeat 1 reported roughly 188.8/213.8/274.9ms means for 2/10/30 machines and 3 residents; the trend is measured software-renderer diagnostic evidence, not a mobile limit or acceptance threshold. Samples are short and final repeats were still underway. `_separate` is statically O(N²), each machine adds individual blade meshes/process callbacks, background/crowd/light scans continue each frame, and evacuation performs O(active residents) updates. These are identifiable candidate costs; no profiler attribution proves which dominates frame time. Extra-NPC case uses active evacuation controllers, which is relevant; dialogue/quest/event-volume growth is absent from this T3 harness and must be marked NOT TESTED here (earlier audit fixture measurements do not establish active T3 event-controller scaling). M4 limits existing asset conclusions. Hardware GPU, browser/Web persistence and physical iOS/Android runtime remain NOT TESTED; no target was invented.

## Declined to judge / exclusions

- Story prose, formal dialogue/cursors, final art, music/audio and reward/XP design: explicitly deferred or forbidden in approved T3 scope.
- Free player navigation to upper floors and a general navigation graph: approved dedicated NPC routes are the limit.
- Resuming midattack/live enemy HP after crash: approved behavior rolls back to the safe checkpoint.
- Global input/save/AI rewrites, spatial partitioning, pooling, arbitrary new ability systems: not required by the current approved encounter and not justified solely by static scaling concerns.
- Acceptance on physical devices, browser IndexedDB durability, hardware-GPU caps: require separate target environments; not inferred from llvmpipe/headless runs.
- Final author fixes, final benchmark repetitions/nonresident asset case, final exported product execution, final MP4 delivery and remote CI/PR state: still in progress at this locked-review stage; no completion claim is made.

Author should reproduce/close findings with exact changed revision and evidence. Unresolved High blocks acceptance.

## Author closure after review (not a second independent review)

H1 reproduced and fixed by modal start rejection and process-mode restoration. M1 fixed by persistent swept exploration policy and restored Battle bounds. M2 fixed by exact checkpoint key allowlists and explicit restore mapping. M3 fixed by preflight route/closure segment validation. M4 corrected by separating resident24 from nine verified nonresident resources and recording cache state/bytes. All have author regression evidence in the final 24-scenario suite. Four disk fault stages, growth-save byte preservation, finite profile validation, and loss-state reset were additionally verified. Independent reviewer did not rerun or review these final fixes; original findings above remain the historical locked-revision assessment. No known unresolved Critical/High/Medium remains after author verification.
