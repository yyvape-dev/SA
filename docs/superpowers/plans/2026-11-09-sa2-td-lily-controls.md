# TD Lily controls parity fix

User request: only Lily combat operation panel must match existing battle UI/UX; reproduction allowed. Native inline execution, authorized UI correction and already-authorized TD publication. No new design approval needed for matching existing panel.

Scope: new sa2_td_lily_controls.gd (TD-only coordinator/Pad subclass/proxy), TD launcher binding + telemetry, meaningful headless/touch/browser tests. Existing touch_ui.gd reused without edits. Existing T2 scene/Manual/host, T3 combat/flow/checkpoint unchanged. No Rana skills added to Lily: existing approved normal attack/dodge+guard only; action buttons use identical base Pad geometry/art/hit rules, joystick radius normalized by viewport height.

1. RED: native contract/integration test missing adapter; later compare visible buttons against base Pad atk/dodge; touch movement/attack/dodge & raw-input ownership; release/retry cleanup.
2. GREEN: subclass original TouchUI._Pad, filter buttons to atk/dodge, retain original _draw/_input/_apply. Node3D proxy forwards to T2 Manual or T3 Driver (keep floor/guard policy). Coordinator turns off only old touch path while active, hides old rectangular buttons, restores ownership/clears held input when done. T3 GUIDE moves to event HUD outside attack area. Existing skill/ult actions not introduced.
3. Independent pre-implementation review for ownership/lifecycle; one separate code review after implementation. Fix verified findings; no blanket redesign.
4. Real Godot native touch tests, old24 regressions, Web browser gestures/multitouch/release and screenshots against original geometry. Rebuild a clean pinned new SHA; keep old903 build URL/files untouched; hosting workflow adds new version and updates landing. Verify public hashes and actual browser; physical acceptance of new UI needs user check.

Review focus: T2 host rawtouch vs Pad double update; T3 Driver must keep sole physics and policy; lock/result/retry release state; GUIDE overlap; only TD affected.

Device feedback: user reports iPhone16 general operation works on903. Record as user-reported basic smoke PASS, not all per-item save/victory/performance acceptance. Latest user UI issue is an explicit remaining defect in old UI903.
