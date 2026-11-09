# TD Lily controls independent code review

2026-11-09 UTC. Reviewed current uncommitted TD UI changes in `/workspace/sa2-t3-implementation`, based on HEAD `a0c79e81e27d33f1e5d87d23a1957de08192230f`. Files: new `sequel/scripts/sa2_td_lily_controls.gd`, `sequel/scripts/sa2_td_launcher.gd` diff, new `sequel/tests/sa2_td_lily_controls_test.gd`. This is a static review; no engine/browser execution, source edits, commit, push or deployment occurred.

## Assessment

No confirmed Critical or High defect. One Medium correctness issue should be fixed within the approved input-release scope before publication. Runtime validation and physical-device acceptance remain separate.

## Strengths

- `LilyPad` overrides only the action allowlist and reuses the original `_draw`, `_input`, `_apply`, geometry and expanded hit rules.
- The proxy adds no physics loop. T3 movement writes to the Driver's Manual, attack/dodge dispatch through the Driver, preserving its blocker/floor guard filter and existing motion resolution.
- Coordinator priority 110 follows existing host/HUD processing and separates input ownership from the one-second telemetry loop. It disables only raw `_input`, preserving existing keyboard handling and controller physics.
- Release checks target validity, zeros movement, disables Pad input and removes UI nodes; it rebinds newly created Drivers on retry. GUIDE leaves its Container while combat controls exist, so fixed placement is not overwritten by container layout.
- Integration tests inject actual touch events through `Input.parse_input_event`, check controller ownership, repeated T2 loss/retry cleanup, scaled component geometry and T3 guard policy. Half-height component geometry tests correctly distinguish component scaling from the project root's logical viewport.

## Findings

### Critical

None confirmed.

### High

None confirmed.

### Medium

1. **Held joystick is not cleared when application/window focus is lost.**
   - Reference: `sequel/scripts/sa2_td_lily_controls.gd:66-78,97-110`; inherited `touch_ui.gd:112-155`; test coverage `sequel/tests/sa2_td_lily_controls_test.gd:36-62`.
   - Evidence: inherited Pad only clears `stick_id` and `move_in` on an explicit matching `InputEventScreenTouch` release. The new coordinator only releases on candidate change, invalid host or exit-tree; it has no focus/application-paused notification handling. Same-target combat remains active on focus regain.
   - Trigger: hold/drag left joystick, switch browser tab/application or otherwise lose focus, and release the finger while the game cannot receive touch-end. On returning, no matching release is guaranteed.
   - Consequence: the previous nonzero Manual movement and captured finger persist, so Lily continues moving and may reject a fresh joystick capture. This is especially relevant to the mobile Web build. Static-code inference; not reproduced in a browser by this reviewer.
   - Scoped fix: add a shared transient-input reset for the TD coordinator and invoke it on focus-out/application pause notifications (and explicit cancellation as supported), clearing stick ID/positions, held buttons, move vector and attack release. Keep the acquired combat lease and raw-touch exclusion intact; merely calling `release()` would let the next process immediately reacquire and may hand ownership back unnecessarily. Add a native notification test and browser focus interruption check.

### Low

None reported.

## Three-axis evaluation

1. Correctness/regressions: static review PARTIAL due to Medium finding; runtime tests NOT TESTED by reviewer. Required runtime evidence remains original-geometry rendering, browser multitouch, GUIDE actual GUI activation without movement/attack, result/save-failure freeze, repeated T3 retry, focus interruption, and exploration restoration. Native tests supplied in source are meaningful but their execution results were not provided to this reviewer.
2. Maintainability/extensibility: static PASS for current scope. Single narrow proxy and original Pad reuse avoid copied combat/UI implementations. Enemy types, art, animation, audio and event additions do not require TD Pad edits. A future approved action requires an explicit proxy/allowlist extension. The TD bridge deliberately depends on concrete host fields; this bounded coupling is consistent with the approved scope and does not justify a broad refactor.
3. Runtime/assets/enemy scaling: NOT TESTED. The changes add constant-size UI processing and no enemy/asset/AI iteration; that is static inference, not benchmark evidence. Two `_btns()` calls per telemetry action iteration are tiny constant work and not elevated to a defect. Source edits do not add art loading or change enemy counts. Actual Godot version, baseline/increased-load frame time, memory and load measurements must be reported by the implementation owner if claimed; no pass is inferred from existing tests.

## Lifecycle and GUIDE inspection

T2 end clears Manual movement and coordinator releases after host `_process`; exploration frees Manual and restores original Pad. T3 result freezes Driver before successful save removes it; proxy validity checks handle a removed/freed Driver, and the coordinator can bind a new Driver next encounter. Existing raw-owner processing flag is restored only while that owner remains valid. GUIDE at viewport-width minus 240, y=110 is on the right and away from atk/dodge circles at the targeted landscape logical geometry; final actual viewport placement/GUI behavior requires browser evidence. `mouse_filter=IGNORE` lets ordinary GUI input pass through the overlay, while base Pad `_input` still observes touch events; putting GUIDE in the left half later would reintroduce joystick capture.

## Evidence and scope

Previously read skill text and supporting references reused: `game-art-animation:tool-routing`, `game-art-animation:quality-gate`, `superpowers:requesting-code-review`, required `code-reviewer.md`; supplied story AGENTS/HANDOFF/authoritative plan references. No reviewer subagents dispatched. Prior design review: `/workspace/sa2-td-evidence/lily-ui-design-review.md`.

Declined to judge: new Lily skills/ult (explicitly excluded), old T2/T3 combat redesign and save-schema changes (excluded), actual browser/physical-device UX and performance (execution prohibited; NOT TESTED), unrelated assets/events scaling (not modified; no performance claim).
