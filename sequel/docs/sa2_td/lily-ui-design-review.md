# TD Lily UI independent pre-implementation review

Reviewed 2026-11-09 UTC. Checkout: `/workspace/sa2-t3-implementation`, branch `feat/sa2-td-mobile-spots-20261109`, HEAD `a0c79e81e27d33f1e5d87d23a1957de08192230f`.

## Decision

No confirmed Critical or High design defect in the proposed approach. Proceed within the approved scope, subject to the concrete implementation invariants below. This is a static design review, not approval of an implementation or a merge. A separate post-implementation code review remains required.

The plan reuses the actual Pad drawing, hit testing and scale calculation while keeping Lily's approved two actions. Binding a passive proxy to the existing controller avoids duplicating combat behavior. TD-only installation preserves old entry points and offers a narrow rollback.

## Required implementation invariants

1. **Exactly one touch owner.** Disable T2 host `_input` processing while the TD Pad owns combat input (`sa2_t2_playable.gd:345` onward), and disable only T3 Driver `_input` while preserving its physics and keyboard processing (`sa2_street_manual_driver.gd:16-19,33-47`). Disabling the T3 Manual's physics is already deliberate; do not re-enable or call it from the proxy. The Pad does not mark touches handled. Hiding legacy Controls alone does not stop raw `_input`.
2. **Keep policy at the Driver boundary.** T3 movement only writes `driver.manual.move_in`; T3 attack/dodge call `driver.attack_press()` / `driver.dodge()`. In particular, direct `manual.dodge()` skips the Driver's floor/blocker guard filter (`sa2_street_manual_driver.gd:22-27`). The proxy must perform no physics, actor movement, animation ticks, or motion resolution.
3. **Lock and lifecycle are authoritative.** Enable Pad input only while T2 active/unlocked or T3 phase street with a valid unlocked Driver. Clear stick ID, touch positions, button ownership, pending movement, and release attack on active-to-inactive, target replacement, focus loss and teardown. A hidden Pad still has `_input`; disable it explicitly. Reacquire a fresh target after T3 retry because `Lease.release()` removes/frees the old Driver (`sa2_control_lease.gd:23-30`). T2 exploration also frees Manual and re-enables the original Pad. Do not retain stale targets or restore ownership over the host's newly selected controller. The launcher's one-second telemetry cadence is unsuitable for input ownership/lifecycle synchronization.
4. **GUIDE must stay independently usable.** Relocation must remove GUIDE from the original HBox layout before assigning its independent event-HUD layout, otherwise the Container can overwrite offsets. Keep it outside the attack/dodge enlarged hit circles, and outside the left-half stick capture region; inherited Pad `_input` runs before GUI handling and may start movement from a GUIDE touch. Verify at 844x390 and the actual iPhone viewport, including simultaneous movement plus GUIDE/attack.
5. **Filter without expanding the proxy contract.** Construct atk/dodge geometry from the base `_btns()` result while satisfying that function's accesses to `ui.battle`/`ui.main`, or use safe nulls where supported. Do not instantiate the complete base HUD for Lily: it expects Rana-specific health/ult/ally properties. Existing `_draw` only requires the player skill properties for skill buttons, so removing all skill/ult/gear entries keeps the proxy surface narrow.

These are implementation constraints already implied by plan lines 5, 8 and 12, not additional features or a redesign. Violating items 1-3 would constitute a High correctness/regression finding at code review. No claim is made that an implementation presently violates them.

## Maintainability and scaling

Static assessment: PASS for the scoped approach. One controller proxy and one existing Pad subclass do not introduce per-enemy updates or duplicate combat state. Adding a new enemy or art resource should not require editing the TD Pad; adding an approved action would require extending the explicit action allowlist/proxy and tests. Keep lifecycle binding separate from the launcher's diagnostics to avoid one-second polling and repeated signal installation. Avoid cloning base Pad drawing/input code, adding a second controller tick, or maintaining a separate copied geometry dictionary.

Runtime performance/scaling: NOT TESTED. No engine or browser execution was authorized for this review. This adapter's expected constant-size UI work is static inference, not benchmark evidence. Actual Godot version and real-rendered baseline/increased-enemy measurements must be reported by the implementation/validation owner; physical iPhone acceptance remains separate.

Correctness/runtime regressions: NOT TESTED. Required subsequent evidence: native touch integration (one movement writer and one physics tick), guard policy with blocked/different-floor foe, held touch through defeat/result-save failure/retry/exploration, target invalidation, release/focus cancellation, and browser multitouch plus original-Pad geometry screenshot comparison. Do not use direct calls to proxy methods alone as input-ownership proof.

## Sources and execution record

Read actual cloud skill text: `game-art-animation:tool-routing`, `game-art-animation:quality-gate`, `superpowers:requesting-code-review`, and its required `code-reviewer.md`. No sub-reviewers dispatched.

Read supplied story-reference copies: `/workspace/sa2-t3-audit/references/AGENTS.md`, `sequel/HANDOFF.md`, `claude/sa2_handoff_20261108.md`, `claude/sa2_vertical_slice_implementation_plan_20261108.md`. The review relies on the coordinator's supplied reference provenance; no fresh network fetch was performed.

Read plan and all six requested scripts (`touch_ui.gd`, `sa2_t2_playable.gd`, `sa2_street_manual_driver.gd`, `sa2_control_lease.gd`, `sa2_t3_hud.gd`, `sa2_td_launcher.gd`), plus `sa2_t2_lily_manual.gd`, T3 scene and actual `sa2_t3_host.gd` for lifecycle verification. A guessed path `sa2_t3_playable.gd` / `sa2_street_host.gd` did not exist; the scene resolves to `sa2_t3_host.gd`, which was then read. No required source was inaccessible.

Only shell read/search and this evidence-file write were performed. No engine/browser, source edit, commit, push, deployment or branch mutation.

Declined to judge: production skill/ult UI additions (explicitly excluded), redesign of old T2/T3 combat and save schemas (excluded), visual parity and physical-device operation (require runtime evidence, NOT TESTED), unrelated global assets/events performance (outside this narrow source design review; no benchmark claim).
