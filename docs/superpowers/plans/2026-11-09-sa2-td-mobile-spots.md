# SA2 TD mobile spots implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Native continuous execution under the already approved TD scope.

**Goal:** T0–T3をスマートフォンから個別に試せるWeb検証ビルドを作る。
**Architecture:** TD専用launcherと診断overlayで既存探索/T1.5会話/T2/T3を組み合わせる。単一スレッドCompatibility Webを実出力し、ブラウザで検証する。
**Tech Stack:** Godot 4.7.2, GDScript, Python export/serve, Chromium/Playwright.
**Spec:** story/sa2-chapter1-20261106@3d4ee9e の実装計画v4.3 TD欄、およびユーザーのT0–3 spot実機準備依頼。

## Global Constraints

main/SA1/T2 sceneとManual/正式本文/Claude指示を変更しない。T3起点f7a11c2のTD専用ブランチ。ホスティング/認証/課金設定は未承認なので公開しない。端末未接続なら実機NOT TESTED。

## Review Focus

不正spot IDは拒否。診断saveは既存saveと分離。リロードでspot/版が維持される。縦画面や小さい横画面でも戻り先を失わない。ブラウザ初回起動とpersistent user storageを実際に検証する。

### Task 1: Spot launcher and isolated diagnostics
Files: sequel/sa2_td_playable.tscn, scripts/sa2_td_launcher.gd, scripts/sa2_td_diagnostics.gd, tests/sa2_td_test.gd, project.godot.
- [ ] RED: mapping/unknown IDs/save roundtrip/diagnostic metrics test.
- [ ] GREEN: menu (T0 diagnostics, exploration, T1.5 dialogue fixture, T2, T3), return controls, build/spot/FPS/frame/load/storage reporting. No formal new text.
- [ ] Run Godot tests and existing24 suite.

### Task 2: Reproducible Web build and browser smoke
Files: tools/export_td_web.py, tools/serve_td_web.py, tests/td_browser_smoke.cjs, export_presets.cfg, docs/sa2_td/.
- [ ] Obtain official4.7.2 export templates; export complete static Web directory outside tracked web assets; manifest SHA256/build metadata.
- [ ] Actual desktop Chromium/WebGL2 boot, spot input, portrait/landscape and reload persistence. Do not equate browser emulation with physical iPhone.
- [ ] Independent review of TD code then scoped fixes/regressions.
- [ ] Commit/push TD branch, PR, build ZIP and external-review report; hosting approval only after concrete artifact ready.

Ruling: user explicitly approved TD initiation and forbids repeat approval in latest handoff, so execute now. Use existing isolated worktree on new TD branch (no extra worktree). T0 is diagnostic status, not invented story content. T1 spot exercises current integrated T1.5 fixture; it is not a full prologue.
