# TD independent code review

Review: 2026-11-09 UTC. Branch `feat/sa2-td-mobile-spots-20261109`, HEAD/base `f7a11c24f16ccff164d0c66ad253cd787dc9cb1e`; reviewed uncommitted tracked and named untracked TD files. No source/index/branch changes, engine launches, browser launches, commits, pushes, hosting or publication performed. This report is the sole written artifact. The author was concurrently validating, so subsequent edits need fresh comparison.

## Guidance actually read

Read `/workspace/sa2-t3-audit/references/AGENTS.md`, story@3d4ee9e AGENTS introduction, required HANDOFF/current handoff sections and plan v4.3 relevant review/TD requirements, local TD plan and ledger. Actually loaded `superpowers:requesting-code-review` and its `code-reviewer.md`, `game-art-animation:tool-routing`, `game-art-animation:quality-gate` via skills.read; all accessible. This is the independent reviewer seat; no further reviewer delegation. Read-only shell/git tools worked. Godot/browser versions and runtime behavior were not independently executed or certified.

## Strengths

Explicit allowlist rejects unknown spot IDs before loading a scene. Probe payload has schema/type checks, bounded frame samples, dedicated file name, and T3 checkpoint filename is set before add_child/_ready. Existing main scene entry remains default, TD selected via a dedicated export feature. Local server binds loopback and no publication is attempted. Single-thread Compatibility export and nonresource JSON include filter are explicit.

## Findings

### High — TD export removes runtime painting metadata

`sequel/export_presets.cfg:229` excludes `art/guide/*`, including `art/guide/guide.json`. `sequel/scripts/main.gd:772` loads exactly that JSON into `guide_meta`; `main.gd:651` only selects the painted shader if `guide_meta.has(p.id)`. Missing file is silently tolerated, so explore, T2 and T3 can boot with plain box materials instead of existing approved city artwork. `build_ver.json` and `districts/d1_ver.json` both currently contain `20261108093657-eeaad11-g4.7.2`, so `district.gd:73` returns cached and does not recover metadata through a district download. Static deterministic dependency finding; output PCK not inspected in this review. Fix: exclude guide images/source artifacts specifically while retaining runtime JSON; add export-content checks for JSON plus representative painted texture and compare real exported rendering with source rendering.

### Medium — menu-selected spot is lost on reload

`sequel/scripts/sa2_td_launcher.gd:29,32,42-58`: menu buttons call `_launch(id)` but never update browser location; reload chooses solely the `spot` query parameter. Starting at `?spot=menu` (or plain URL), choosing T2/T3 and refreshing returns to menu. The smoke only directly visits `?spot=t0`, so its reload assertion does not exercise this path. Fix: use URL/history replacement on successful launch (preserving required version parameters) and test menu choice followed by reload, including T3 checkpoint restoration.

### Medium — browser smoke PASS does not establish its claimed touch/resume coverage

`sequel/tests/td_browser_smoke.cjs:18-36`: T2 receives no input at all; explore receives a single tap without a drag or position assertion; T1 receives two taps without asserting `dialogue_line`; T3 only asserts event start. No attack/dodge/guard, movement, existing progress restoration, return control, or clipping assertions. Portrait is only photographed. T0 console/page errors are reset by next boot and its record lacks `errors`, so the final gate can ignore them. A broken touch adapter, clipped return button or nonfunctional dialogue input can still print `TD_BROWSER_SMOKE_PASS`. Fix: assert observable position/action/dialogue deltas after real touch sequences, inspect geometry and return action after resize, collect errors for every phase including T0/portrait, and distinguish boot-only checks from input/persistence acceptance. Physical-device acceptance remains NOT TESTED regardless.

### Medium — displayed version does not identify uncommitted build contents

`sequel/tools/export_td_web.py:12-21,28` identifies every build by current committed HEAD; `--untracked-files=no` also omits all new untracked TD source when determining dirty. `sequel/scripts/sa2_td_launcher.gd:19,82` displays only SHA, ignoring dirty. In the reviewed state the entire launcher/test/tool implementation is uncommitted. Multiple materially different TD artifacts all display `f7a11c24`, preventing device reports from identifying their actual code. Fix: commit before release export or derive a deterministic content/build ID including tracked modifications and included untracked sources, carry it in manifest/runtime display/versioned artifact URL; fail release preparation if identification is ambiguous.

### Medium — T0 hides its own diagnostics initially

`sequel/scripts/sa2_td_launcher.gd:46-50` hides `status` for every spot and immediately returns for T0. Its diagnostic-only screen therefore starts empty apart from the toolbar; FPS/storage/build only appear after discovering and tapping Stats. Plan Task1 describes T0 as diagnostic status, and the comment at line47 promises compact return but Save/Stats remain. Fix: show status for T0 by default, keep identifying build/spot visible in every spot, and apply an intentional responsive overlay layout. No physical-screen layout judgment claimed.

## Save isolation: unresolved dependency, not certified safe

Dedicated probe and T3 files are statically isolated. `launcher.gd:56-58` uses unmodified explore/T2 scenes, so `main.gd:109-114` reads `Progress` default `user://sa2_save.json` (`progress.gd:4`), `main.gd:2555` writes it on XP, and `sa2_t2_playable.gd:10,66,150-152` reads/writes `user://sa2_t2_progress.json`. The export changes config/name for TD, which can isolate native app-data directories, but this review has not proven Web IndexedDB namespace separation from any existing same-origin/path deployment. Direct desktop TD source launch also lacks the export feature unless supplied. Do not call all existing saves protected based solely on the probe test. Required fix/evidence: explicitly isolate all TD-used save paths before any scene startup, or prove application-wide user-directory isolation on each supported invocation and same-origin Web reload/upgrade case with sentinel old-save byte comparisons. This is a safety acceptance blocker pending evidence; no destructive behavior was executed or asserted as observed.

## Three-axis assessment

- Correctness/regression/save non-destruction: FAIL static export and reload defects; runtime input/restore and native/Web save namespace proof NOT TESTED. Unknown IDs: static PASS; actual invalid launch UI test NOT TESTED (`sa2_td_test.gd:7` checks only mapping helper).
- Maintainability/data: PARTIAL. Existing event/dialogue APIs reused; frame metrics bounded to 300. Spot definitions are repeated in menu, allowlist, scene mapping and metrics conditionals (`launcher.gd:14,29,44,68-80`), so one new spot requires multiple edits and can silently miss telemetry. A single descriptor registry is a scoped future improvement (Low). Existing art/event addition contracts were not changed. Add-one-material analysis exposes the export wildcard problem above.
- Performance/material growth: NOT TESTED. All-resources export packages each added asset whether needed by one spot or not, so download/memory costs grow with whole-project asset volume; exporter computes each hash with `p.read_bytes()` (`export_td_web.py:27`), temporarily allocating an entire large PCK. Diagnostics duplicate/sort at most 300 samples once per second; this is bounded static cost, no benchmark claim. Require real Godot 4.7.2 baseline vs representative larger asset/enemy/event loads, frame-time distributions, memory and startup timing on target devices; software Chromium is not device performance.

## Declined to judge

- T3's internal encounter implementation and existing T3 re-review findings: separate review seat per assignment; only TD integration boundaries inspected.
- Physical iOS/Android usability, FPS, persistence and delivery reachability: no connected devices; browser/engine launch explicitly prohibited for this reviewer.
- Public hosting/authentication/billing: unapproved and not attempted; loopback server alone is not a phone-reachable delivery URL.
- Official current Godot API/export behavior beyond inspected source dependencies: no external documentation fetch/runtime API verification in this read-only review.

## Verdict

Not ready for TD acceptance. Fix the High resource omission and Medium correctness/evidence defects, resolve save namespace proof, then have author rerun export content/render/input/persistence checks. This reviewer has made no runtime PASS claim. No Critical findings identified in the reviewed scope.
