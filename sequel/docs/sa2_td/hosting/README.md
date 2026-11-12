# SA2 TD — mobile test distribution

**Live test URL: https://yyvape-dev.github.io/SA2-TD/**

Published candidate1bd34b8; original903b0b9 is retained. Public HTTP/hash validation and actual desktop Chromium touch-emulation passed for all5 spots. iPhone16/Safari remains a user-run acceptance step. See evidence/ for deployment and public verification results.

This public repository hosts only the SA2 mobile test landing page and deployment tooling. The source game is pinned to [yyvape-dev/SA@1bd34b8](https://github.com/yyvape-dev/SA/tree/1bd34b84811cc255a98bb4b268e4525005d834c6). Existing SA/main and its Pages configuration are not modified.

First physical target: iPhone 16. iOS/Safari version is not yet known. Desktop Chromium touch-emulation tests passed; physical-device acceptance remains **NOT TESTED** until the owner plays and reports results.

## Deployment

`pages.yml` is manually dispatched. It checks out the pinned public source, installs official Godot 4.7.2 and the single-thread Web template, exports the TD build, verifies manifest source/clean state and every resource hash, then uploads/deploys the Pages artifact. A published-build manifest is also retained as an Actions artifact.

The landing page links to `builds/1bd34b8/index.html?spot=t0/explore/t1/t2/t3`, and preserves the original903 version separately. The initial source/runtime version is immutable; later source versions must use a new directory. `tools/prepare_site.py` accepts an exported build (`--build`), refuses incorrect source IDs/file hashes, and preserves the original903 resources using the trusted original manifest.

The user has approved public hosting and created this repository. Initial Pages enablement was completed by the owner in Settings → Pages → Source: GitHub Actions. The integration receives HTTP403 when creating Pages. The official configure-pages action states that first-time enablement requires an appropriately privileged token other than the default GITHUB_TOKEN. Do not request a personal token from the user; use the owner setting instead.

Local Release upload was attempted and rejected with HTTP401 at uploads.github.com. Publication therefore builds the same verified source within Actions rather than claiming byte identity with that local ZIP. Actual public files must be compared with the manifest produced by that deployment, and browser-tested after publication. No Release is required.

## Validation and device checklist

- [Game specification and TD evidence](https://github.com/yyvape-dev/SA/tree/feat/sa2-td-mobile-spots-20261109/sequel/docs/sa2_td)
- [iPhone test checklist](https://github.com/yyvape-dev/SA/blob/feat/sa2-td-mobile-spots-20261109/sequel/docs/sa2_td/device-record.md)
- [Official custom Pages workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Official first-time enablement permission](https://github.com/actions/configure-pages/blob/v5/action.yml)

The intended public address is https://yyvape-dev.github.io/SA2-TD/ . It is confirmed live by current deployment42567816201 (original deployment42564101383), public HTTP200 and complete resource SHA256 matching, and actual browser smoke tests. No new story, rewards, finalized art, account login or automatic telemetry submission are added.

## Current execution evidence (2026-11-09 JST)

[First deployment run](https://github.com/yyvape-dev/SA2-TD/actions/runs/42563853224): pinned source checkout, official engine/templates, Web build and full manifest validation all **PASS**. `configure-pages` **FAIL** because this repository has not yet been enabled for Pages. Upload/deploy were skipped. Full workflow is therefore not PASS. Evidence is retained under `evidence/`.

The owner selected **GitHub Actions** as Source in [SA2-TD Pages settings](https://github.com/yyvape-dev/SA2-TD/settings/pages). Publication is already authorized; after the setting is enabled, dispatch `pages.yml` again. No new approval or changes to existing SA/main are needed. Public reachability/browser/device acceptance are still NOT TESTED.

## Resolved publication and verified public build

[Deployment42564101383](https://github.com/yyvape-dev/SA2-TD/actions/runs/42564101383) passed after owner enablement. Public manifest source is903b0b9, clean Godot4.7.2. Every exported resource (including WASM/PCK) was fetched publicly and its size/SHA256 matched. WASM MIME is application/wasm. Landing mobile-width layout has5 links and no horizontal overflow.

Public Chromium/SwiftShader smoke: T0 probe survives page reload; T1 tap advances line; explore boots; T2 actual touch attacks1/dodges1; T3 entersSTREET by real touch. No browser errors. These are desktop emulation results, **not physical iPhone/Safari or Android PASS**.

## Lily control-panel update

Next/current candidate: `1bd34b84811cc255a98bb4b268e4525005d834c6`, version directory `1bd34b8`. Lily T2/T3 now reuse the existing TouchUI Pad's circular attack/dodge buttons, joystick rendering, hit areas and scaling. Combat logic and approved actions remain unchanged. GUIDE stays in a separate right-side event area.

The user reported that the first903 build worked on iPhone16; OS/browser version and per-spot details were not provided. This is a user-reported basic smoke PASS, not full save/victory/performance acceptance. The same user requested this UI correction. New1bd UI physical acceptance is pending.

The deployment mirrors every old903 resource from the live site and verifies against the original trusted manifest before publishing both version directories. If any old file differs, deployment stops. `prepare_site.py --build ... --out ... --preserve-url https://yyvape-dev.github.io/SA2-TD/` is the current supported path; the obsolete local ZIP upload route is no longer needed. Public HTTP checking validates both the new version and unchanged903 bytes.

### Published and verified1bd update

[Deployment42567816201](https://github.com/yyvape-dev/SA2-TD/actions/runs/42567816201) **PASS**. Current root links use1bd34b8. All public files matched the actual deployment manifest; every original903 resource was fetched and still matched its original bytes/SHA256. Evidence: `evidence/public-http-1bd34b8.json`.

Public Chromium smoke PASS: T0 storage reload, T1 dialogue, explore, T2 circular-panel touch attack/dodge/joystick, DOM blur release, T3 circular-panel start/GUIDE evacuation. Headless tab operations emitted no blur/visibility events, so the focus contract was verified by explicit DOM blur delivery; actual iPhone app switching remains unverified. Native UI test100 assertions PASS, including20 retries each forT2/T3 and restored GUIDE parent/single signal. Original24 regressions and candidate CI42567396614 PASS (that CI had the earlier60-assertion harness;100 is the expanded local harness).

The user reported basic903 operation on iPhone16 as good and requested this UI correction. **Physical acceptance of1bd UI is pending user recheck.** No new abilities/rewards or combat rules were added. Existing normal TouchUI rendering/hit testing is inherited, without modifying T2 Manual/scenes or T3 combat logic.
