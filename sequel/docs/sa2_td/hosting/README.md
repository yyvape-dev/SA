# SA2 TD — mobile test distribution

**Live test URL: https://yyvape-dev.github.io/SA2-TD/**

Published candidate903b0b9. Public HTTP/hash validation and actual desktop Chromium touch-emulation passed for all5 spots. iPhone16/Safari remains a user-run acceptance step. See evidence/ for deployment and public verification results.

This public repository hosts only the SA2 mobile test landing page and deployment tooling. The source game is pinned to [yyvape-dev/SA@903b0b9](https://github.com/yyvape-dev/SA/tree/903b0b9e2c9c91151d35f3802197fc127cae469a). Existing SA/main and its Pages configuration are not modified.

First physical target: iPhone 16. iOS/Safari version is not yet known. Desktop Chromium touch-emulation tests passed; physical-device acceptance remains **NOT TESTED** until the owner plays and reports results.

## Deployment

`pages.yml` is manually dispatched. It checks out the pinned public source, installs official Godot 4.7.2 and the single-thread Web template, exports the TD build, verifies manifest source/clean state and every resource hash, then uploads/deploys the Pages artifact. A published-build manifest is also retained as an Actions artifact.

The landing page links to `builds/903b0b9/index.html?spot=t0/explore/t1/t2/t3`. The initial source/runtime version is immutable; later source versions must use a new directory. `tools/prepare_site.py` accepts an exported build (`--build`) or the previously verified local archive (`--zip`), and refuses incorrect source IDs and file hashes.

The user has approved public hosting and created this repository. Initial Pages enablement was completed by the owner in Settings → Pages → Source: GitHub Actions. The integration receives HTTP403 when creating Pages. The official configure-pages action states that first-time enablement requires an appropriately privileged token other than the default GITHUB_TOKEN. Do not request a personal token from the user; use the owner setting instead.

Local Release upload was attempted and rejected with HTTP401 at uploads.github.com. Publication therefore builds the same verified source within Actions rather than claiming byte identity with that local ZIP. Actual public files must be compared with the manifest produced by that deployment, and browser-tested after publication. No Release is required.

## Validation and device checklist

- [Game specification and TD evidence](https://github.com/yyvape-dev/SA/tree/feat/sa2-td-mobile-spots-20261109/sequel/docs/sa2_td)
- [iPhone test checklist](https://github.com/yyvape-dev/SA/blob/feat/sa2-td-mobile-spots-20261109/sequel/docs/sa2_td/device-record.md)
- [Official custom Pages workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Official first-time enablement permission](https://github.com/actions/configure-pages/blob/v5/action.yml)

The intended public address is https://yyvape-dev.github.io/SA2-TD/ . It is confirmed live by deployment42564101383, public HTTP200 and complete resource SHA256 matching, and actual browser smoke tests. No new story, rewards, finalized art, account login or automatic telemetry submission are added.

## Current execution evidence (2026-11-09 JST)

[First deployment run](https://github.com/yyvape-dev/SA2-TD/actions/runs/42563853224): pinned source checkout, official engine/templates, Web build and full manifest validation all **PASS**. `configure-pages` **FAIL** because this repository has not yet been enabled for Pages. Upload/deploy were skipped. Full workflow is therefore not PASS. Evidence is retained under `evidence/`.

The owner selected **GitHub Actions** as Source in [SA2-TD Pages settings](https://github.com/yyvape-dev/SA2-TD/settings/pages). Publication is already authorized; after the setting is enabled, dispatch `pages.yml` again. No new approval or changes to existing SA/main are needed. Public reachability/browser/device acceptance are still NOT TESTED.

## Resolved publication and verified public build

[Deployment42564101383](https://github.com/yyvape-dev/SA2-TD/actions/runs/42564101383) passed after owner enablement. Public manifest source is903b0b9, clean Godot4.7.2. Every exported resource (including WASM/PCK) was fetched publicly and its size/SHA256 matched. WASM MIME is application/wasm. Landing mobile-width layout has5 links and no horizontal overflow.

Public Chromium/SwiftShader smoke: T0 probe survives page reload; T1 tap advances line; explore boots; T2 actual touch attacks1/dodges1; T3 entersSTREET by real touch. No browser errors. These are desktop emulation results, **not physical iPhone/Safari or Android PASS**.
