# SA2 T3 (C2-09) — approved implementation brief
Date: 2026-11-09 JST
Status: **USER-APPROVED FOR IMPLEMENTATION on a feature branch; NOT IMPLEMENTED / NOT ACCEPTED**
Authority: this approved brief governs scope, while `reports/design.md` v2 + final M3 addendum governs technical contracts. If any conflict occurs, halt before expanding scope.

## Repository and references
- Repo: `yyvape-dev/SA`
- Implementation base: `feat/sa2-t2-sequel-integration-20261108`; reviewed SHA `ddc257067b82f0c796cdbc9c1becc46f7bc7a12e`. Re-fetch before editing and assess changed HEAD.
- Feature branch: `feat/sa2-t3-street-encounter-20261108`. Never edit/merge main.
- Documentation branch: `docs/sa2-t3-design-gate-20261108`.
- Authoritative technical report: `sequel/docs/sa2_t3_design_gate_20261108/reports/design.md`, `independent-review.md`, `survey.md`, `performance.md`, `verification.md`.
- Story references from explicit `story/sa2-chapter1-20261106` ref: `AGENTS.md`, `sequel/HANDOFF.md`, `claude/sa2_handoff_20261108.md`, `claude/sa2_vertical_slice_implementation_plan_20261108.md`, `claude/sa2_chapters1_2_integrated_script_20261108.md`, `claude/sa2_spoiler_free_gameplay_review_v2_20261108.md`. Do not change story/creator material or reveal spoilers in public-facing reports.

## Approved gameplay scope
1. Existing street/Level instance persists through explore → C2-09 combat → explore; no city rebuild for transition.
2. Manually control Lily, reusing T2 movement, normal attacks, evade and combined guard; prevent double AI/input ownership. Leave T2 Manual source unchanged.
3. Exactly two unmanned machines of the same kind, with distinct stable IDs. They are the only combat targets.
4. Exactly **three** tracked evacuees for the initial T3. Use existing rendered street to position them visibly. Evacuation moves via validated height-aware waypoints from upper route to lower safe nodes. Combat participants remain in the same lower combat floor; no new free upper-floor exploration.
5. Victory requires BOTH registered machines disabled AND all three registered evacuees safe. Order and duplicated/unknown signals must not change result.
6. Lily HP 0 means defeat; same-frame win/defeat resolves to defeat. Restore pre-combat safe checkpoint after defeat and after reopening mid-combat; do not resume attack timers.
7. On victory return to the same town; machines do not respawn; persistence is durable before victory disclosure/unlocking.
8. All people, evacuees, ordinary NPCs and facilities are non-targetable and must not suffer damage (all hit shapes, knockback, collision separation and floor/blocked segments accounted for).
9. No new rewards, experience gain, official text rewrites, finalized artwork, sound work, global state migration or broad terrain refactor. Test HUD and temporary distinguishing machine visuals are allowed.

## Required architecture and review closures
- **B:** focused street encounter/controller plus existing Battle/Ally/Enemy, street host, control lease, manual driver, movement/damage policy, evacuee route/controller, per-event definition/profiles and T3 checkpoint writer. Avoid T2-host copying, main.gd event sprawl and global DSL.
- Shared `battle.gd`, `enemy.gd` and `ally.gd` may receive **opt-in** T3 policy hooks, defaulting to legacy behavior when policy=null. Scope includes Battle `_separate` displacements for both actors (M3).
- Implement final v2 review closures **H1/H2/M1/M2/M3**: checkpointed shared HP/gauges/cooldowns and canonical transient reset; constrained swept motion before hits and per-target pre-damage permission across shapes; safe separation, pulls, enemy attacks and floor/blocked-route checks; `RESULT_PENDING → durable commit → release`; current/backup/temp valid recovery without corrupting last good checkpoint; bounded validated event, route and enemy profile schemas.
- Keep growth save separate, never award XP on machine disable. Preserve T1/T2 existing save behavior.
- Design gate review is closed at **design level only**; do not treat it as a code review or device acceptance.
- Minimum requirements include explicit resource/pack dependency validation and reasonable handling of missing assets.

## Execution contract
1. Inspect actual worktree/branch/SHA, skills and instructions before change. Load and follow all relevant available skill bodies and reference docs, including Superpowers using-superpowers, writing-plans, TDD, executing-plans/subagent-driven-development where accessible, requesting-code-review, receiving-code-review, verification-before-completion, plus game-art-animation tool-routing and quality-gate. If essential dependencies are missing, report them accurately and stop rather than inventing successful execution.
2. Write a concrete implementation plan with file scope, signatures, independent test cycles; then implement within this **already approved** scope. Avoid redundant architecture-approval requests unless a new material decision arises.
3. Test: same Level instance; control and ownership; target roster; three evacuees/two machines success in both orders; same-frame defeat precedence; invalid/duplicate IDs; sweep/barrier checks for dash, attack, knockback and pair separation; 20 retries without orphan nodes/connections; separate-process restart mid-fight and after victory; save failure/backup/corruption/schema tests; T1/T1.5/T2/T2.5 and normal street regression; resource/pack import/export.
4. Capture actual Godot 4.7.2 scenes (not generated mockups): normal sequence and failure/restart sequence. Deliver checked H.264 yuv420p faststart MP4 plus PNG. Confirm decode and inspect output. Prefer 1280×720 and horizontal phone aspect when runnable.
5. Measure T3 actual runtime, 2 machines/3 active evacuees and relevant stress cases, recording renderer/resolution/GPU. Never present llvmpipe FPS as smartphone/GPU performance; recording fixed-fps is not performance sampling. Do not reduce art quality to improve scores without approval.
6. Run independent implementation code review, resolve Critical/High or stop; document Medium and untested details. If independent agent unavailable, say so rather than presenting self-review as independent.
7. Report exact branch/SHA/PR (if possible), modified files, tests and commands, acceptance matrix PASS/FAIL/NOT TESTED, verified MP4/PNG, performance context, unresolved issues. Do not merge to main.

## Stop/escallation triggers
- Different upper-floor gameplay request, different resident count or success/failure policy, new rewards, changed story, expansive refactor, editing protected branch or T2 Manual.
- Failed safety/save invariants, breakage of existing T2 behavior, unexplained missing pack, unresolved Critical/High review issue.
- Unable to reproduce real rendering / produce verified evidence: mark NOT TESTED and do not claim production acceptance.

## Short recurring prompt
```
Implement the approved SA2 T3 (C2-09) work from GitHub branch docs/sa2-t3-design-gate-20261108, file sequel/docs/sa2_t3_design_gate_20261108/reports/implementation-brief-approved.md. Read that entire file plus its linked design v2, independent review and required project instructions/skills before changes. Work only on feat/sa2-t3-street-encounter-20261108 based on the verified T2 SHA; implement, test, independently review and capture actual Godot MP4/PNG; no main merge. If a stop condition occurs, report exact blocker rather than changing scope.
```
