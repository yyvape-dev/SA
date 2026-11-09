# Independent T3 design review — v1

Read-only review of design.md v1 against detached source HEAD ddc257067b82f0c796cdbc9c1becc46f7bc7a12e, supplied story-branch AGENTS/HANDOFF/implementation-plan references. No product changes; no implementation acceptance. Applied requesting-code-review, receiving-code-review, quality-gate and tool-routing guidance; using-superpowers explicitly exempts dispatched subagents. No further delegation.

Decision: **B is a reasonable scoped direction, but design approval is blocked by H1/H2 below.** No Critical issue identified. Findings are static design/code inference, not reproduced T3 defects (T3 does not exist).

## H1 — High: rollback contract omits shared combat state

Location: design.md:34,64–66; scripts/battle.gd:43–53,386–399; scripts/sa2_t2_lily_manual.gd:29–37.

The proposed checkpoint lists actor position/facing and enemy initial states, but health belongs to Battle, not Lily. Damage sets battle.hp to zero and increases ult/hits_taken. Creating a fresh Manual only resets Lily state/cd/inv; it does not restore battle.hp, ult, ally_ult, gain flags, freeze/cine/camera state, or Lily's attack/skill transients. The promise to return to a safe checkpoint therefore lacks an explicit contract capable of producing a living, clean retry. A lease of references/process/visibility is insufficient.

Scoped correction: define a bounded combat-state snapshot/reset table before approval: fields restored from the checkpoint versus reset to canonical exploration values versus deliberately retained. Include shared HP and actor state, knockback, attack targets/hit progress, skill/ultimate/camera ownership and cooldown/gauge policy. Define identical normalization for live failure and restart, and stage/validate restoration before deleting the only live state. Extend retry tests to compare HP/gauges/actor transients, not only node counts/position. This does not require global state refactoring or saving live attack timers.

## H2 — High: movement/attack safety is promised without a realizable ownership boundary

Location: design.md:39,41,54,74; scripts/sa2_t2_lily_manual.gd:87–118; scripts/ally.gd:245–273; scripts/battle.gd:254–285; scripts/enemy.gd:177–195,214–218.

Manual directly writes positions for move/dodge and delegates all non-move frames to Ally, which can move and execute damage within the same callback. Enemy writes movement independently; Battle applies pulls inside damage processing. A later Host clamp can correct the final picture after an attack already hit through a boundary. Existing attacks compare x/z only, including the only-target shape; there is no floor or obstruction test. Listed shared changes cover profiles only, while existing Manual is expressly immutable. Thus merely adding a Lease does not establish the promised all-movement and attack boundary.

Scoped correction: explicitly choose the T3-only adapter/driver and opt-in combat policy boundary, with deterministic order: resolve constrained movement before damage, and validate permitted encounter target/same combat floor/approved blocker policy immediately before damage. An unchanged T2 Manual may be driven through a wrapper, but document how its within-callback movement and hit callbacks are intercepted. Alternatively narrow the initial geometry to a provably unobstructed lower-floor combat strip and remove unsupported attack-blocking promises. Enumerate approved shared hooks and default legacy behavior; do not silently expand into T2 edits. Non-targets staying outside Battle.enemies is sound, but floor/obstruction safety is a separate invariant.

## M1 — Medium: victory persistence failure has no defined recoverable state

Location: design.md:36,60,62,66; scripts/sa2_flow_state.gd:98–104.

Start-save failure is specified; result-save failure is not. Atomic replacement prevents a partial file, but does not define whether a failed victory commit unlocks exploration/dialogue, leaves a retryable frozen result, or is retried once on restart. Flow.save_to itself directly truncates its target and must not be used for the outer envelope. “One commit” and “live unchanged on failure” also need distinction between durable state and the already-mutated battlefield.

Scoped correction: introduce a result-pending barrier: freeze the candidate result, serialize one validated envelope to a T3-specific explicit path, verify write/flush/close/replace errors and backup promotion order, publish completion/unlock only after success. On failure preserve the last durable checkpoint and expose retry without re-running rewards/transitions. State crash recovery for temp/backup and require validated phase/result/Flow combinations. Keep growth save separate as already proposed; Host must override the existing kill handler (main.gd:2540–2555) so mechanical kills never call progress.save().

## M2 — Medium: scalability evidence and data contracts must stay bounded

Location: design.md:37–39,79,85; scripts/battle.gd:229–245; scripts/enemy.gd:104–106; main.gd:310–355.

Profiles and event Resources reduce duplicated configuration, but “same type event is data only” remains conditional: there is no bounded schema for route nodes/edges, entity ID uniqueness, blocked segments, clip timing requirements, or supported event action vocabulary. Enemy resources still rely on existing AI/attack structures; an arbitrary new behavior/ability requires code. Per-frame enemy separation is pairwise; backgrounds/crowd/lighting continue per-frame scans. These are static scaling risks, not measured proof of a current bottleneck.

Scoped correction: document minimum schema and load-time validation, supported profile/route behaviors, and explicitly state that new AI/actions require scoped code/review. Retain lazy event selection rather than loading every event each frame; preload the encounter's required textures before checkpoint and share immutable resources. No global cache, DSL, spatial partition or pooling rewrite is justified solely by this review.

measurements.json was present and contains real-rendered X11 llvmpipe runs under Godot 4.7.2, e.g. current3_r1: 26 frames, mean 235.07ms/p95 269.15ms, target2_r1: 33 frames, mean 184.17ms/p95 209.78ms. This is an existing-engine software-renderer diagnostic, not T3 acceptance or phone performance. Short/noisy samples cannot establish a portable enemy cap or that O(N²) dominates. I have not independently rerun or fully audited the in-progress benchmark harness; final benchmark summaries remain unverified here. “Same load scenario” should link final harness, baseline, exact counts and repeat conditions; unique asset residency/load and active event/NPC costs must be distinguished from parsing fixtures or background crowd duplication.

## Coverage and exclusions

- Correctness/regressions: reviewed input/lease ownership, combat roster safety, geography limitation, success conjunction, rollback, growth-save isolation and durable result semantics. H1/H2 unresolved; implementation tests NOT TESTED.
- Maintainability/extensibility: B avoids copying the T2 host and avoids a global migration; composition is appropriate. Private Ally/Manual coupling and minimum schema require the bounded contracts above.
- Performance/scalability: inspected static hot paths and sampled raw measurement records. Final harness/results verification, T3 render workload, hardware GPU and mobile/Web persistence/performance NOT TESTED.
- Excluded: story prose/spoilers, new dialogue writing, art production, audio, global AI/save/input refactoring, new reward specification, full mid-attack resume, free upper-floor player navigation, physical-device certification, implementation, commits, merges and deployment.

## Conditions for re-review

Revise H1/H2 and M1 into explicit design contracts, identify legacy-safe hook scope, finalize the benchmark report without device or T3 claims, then request independent re-evaluation. User still must choose the NPC-only upper/lower waypoint scope, NPC count/placement and failure policy, authorized branch/shared-change boundary. These are acknowledged scope decisions, not hidden defects. B can proceed to implementation planning only after those approval conditions and High findings are resolved; this review grants no implementation authorization.

# v2 re-evaluation

Reviewed the explicitly superseding design.md:95–141 against the same source HEAD and final performance.md, spike/bench.gd, both Python runners and all 33 raw measurement rows. The runtime benchmark script matches spike/bench.gd; main/Battle/Enemy/Ally/TouchUI/Manual script bytes match the source checkout. No benchmark rerun or product implementation was performed by this reviewer.

- **H1 CLOSED at design level:** design.md:103–107 now distinguishes shared HP/gauges/multipliers/cooldowns from canonical transient reset, validates hp>0, stages restoration and orders setup before cooldown application. Live/restart share a restoration path. Actual field mapping and tests remain implementation obligations, not verified behavior.
- **H2 CLOSED at design level:** design.md:111–121 explicitly authorizes optional shared Ally/Enemy hooks, T3Driver ownership, swept motion resolution and pre-damage policy across every shape/enemy attack; policy=null preserves legacy. These hook positions align with existing Ally dash-before-hit and Enemy move-before-warn structure. Skill/ult exclusion is explicit and limits the integration scope. One omitted displacement path is recorded below as a scoped Medium clarification.
- **M1 CLOSED at design level:** design.md:127–131 now separates pending candidate from durable completion, forbids Flow.save_to for the envelope, retains current/backup recovery and disallows adopting temp completion. Persistence failure and Web limitations are explicit. Exact backup copy/rotation/error handling still needs implementation planning and crash tests.
- **M2 CLOSED at design level:** design.md:135–141 bounds event vocabulary, route graph and profile validation and distinguishes fixture costs from active controllers/evacuation AI. New AI/skills require code/review; no generic DSL or speculative optimization is required.

## M3 — Medium clarification: route separation displacement through policy too

Location: design.md:119–120; scripts/battle.gd:229–245. `_separate` independently moves both a.position.x and b.position.x. The v2 hook list covers enemy walk/stun, attack sources, pulls and knockback, but does not explicitly cover this Battle-owned displacement. Normalizing the endpoint at the next attack cannot prove that separation did not cross a thin blocked boundary. Add the same optional resolve_motion hook to each pairwise separation displacement, preserving original arithmetic when policy=null. This is a small completion of the already-approved boundary design, not a new shared subsystem. Include close enemy pairs at a forbidden boundary in the movement test matrix.

## Benchmark evidence audit

Verified 21 city + 12 backtown rows, 3 repeats per case, all exit_code=0. Recomputed mean-frame medians and frame totals match performance.md for all 11 cases. Harness uses wall-clock 2s warmup/6s sampling, no fixed-fps argument, real rendering through opengl3/X11; sampled RSS is external process polling. Extra assets are sorted distinct image paths retained by textures/Sprite nodes; event counts use distinct fixture IDs and retain DB results. NPC count grows background crowd, not evacuation agents. Report names those limitations correctly.

The harness sets hp=1e9 while locking Rana and disabling actor physics, so this is a sentinel natural-enemy workload, not normal combat balance/controls. Six-second windows give few samples under llvmpipe; the report appropriately avoids statistical precision, hardware/mobile inference, T3 acceptance, and identifying the pairwise microbenchmark as the frame bottleneck. The benchmark is adequate as a bounded existing-engine diagnostic, not a final performance gate. Pending Level-hidden ablation is excluded from this verdict; no unobserved ablation conclusion is endorsed.

## v2 verdict

**No unresolved Critical/High design findings. B v2 is ready to present for user design approval, with M3's explicit separation hook clarification carried into the design/implementation plan.** This is not authorization to implement and does not mean T3 or mobile performance passes. User decisions remain NPC-only upper/lower route scope, NPC count/placement/failure policy, branch/shared-change scope (now including Ally and policy hooks), and target device/performance criteria. All earlier product/story/branch exclusions remain in force. Implementation must undergo regression, real-render, save-failure/restart and representative T3 load validation before acceptance.

### M3 closure and final design verdict

Re-read the final design addendum: it explicitly resolves both `_separate` actor displacements with `(before, desired)` through the optional policy, retains policy=null legacy behavior and adds the thin-fence separation test. **M3 CLOSED at design level. All review findings are closed at design level; B v2 is ready for user design approval.** T3 implementation, regression evidence, persistence fault tests, real T3 load and device/Web acceptance remain NOT TESTED. User choices and implementation authorization listed above remain outstanding.
