# SA2 — Instructions for GPT / Codex accessing yyvape-dev/SA

This file is for **GPT and Codex when working on SA2** (`sequel/` and SA2 planning documents). **Claude is explicitly exempt from this GPT/Codex review-routing process**: Claude does not need to run Codex reviews or follow GPT-to-Codex delegation rules. Do not alter existing Claude-specific instructions in `CLAUDE.md`.

## Required handoff reading
1. `sequel/HANDOFF.md` — Godot SA2 project state and specific GPT/Codex notes near the beginning.
2. `claude/sa2_handoff_20261108.md` — SA2 chat handoff and current status.
3. `claude/sa2_vertical_slice_implementation_plan_20261108.md` — authoritative SA2 plan, especially **「ChatGPT／Codex役割分担・リスク連動レビュー規則」** and the pre-implementation approval gate.

Before acting, confirm current branch, relevant skills/tool availability and actual engine/version. Read applicable skill content, not just titles. Resolve stale handoff claims against current code and fresh evidence.

## Risk-triggered Codex reviews
- **Normal low-risk work:** Use GPT/ChatGPT for research, requirements, approach comparison, scoped edits and acceptance evidence. No blanket Codex review for trivial, local changes.
- **Mandatory pre-implementation Codex design review:** Changes spanning multiple systems; new shared APIs, saved-state structures, dialogue/data models, input architecture; designs that seem hard to maintain, difficult to reuse, manually expensive or hard to reverse (e.g. embedding large dialogue scripts in GDScript).
- **Mandatory post-implementation Codex code review:** High-risk integrations or significant bug fixes. Combine **independent code review → verified fixes → Godot regression tests / real-rendered MP4 / CI verification** into one requested task. Unresolved Critical/High issues block acceptance. Verify findings rather than assuming Codex is infallible.
- Record the review decision and rationale for each milestone. Respect user approval for any substantial design change; approved-scope bug fixes need no repeated permission.
- Do **not** claim Codex tasks were initiated from ChatGPT without a working invocation mechanism. If the user has already submitted a Codex task, do not duplicate it.

## Delivery and protection
- **Mobile user:** Provide actual H.264 MP4 footage directly in the ChatGPT conversation, not merely GitHub artifacts. If direct upload is unavailable, report the delivery gap and preserve the file/artifact reference.
- **Testing:** Godot CI and video are not iPhone/Android physical-device testing. T7 is the planned physical-device acceptance stage.
- **Branch safety:** Never modify `main`, SA1 or an approved storyline without explicit authorization. Work only on the user-authorized branch. Do not merge unrequested changes.
- **Current status:** User already assigned T2.5 independent code review → fixes → regression/video to Codex; the results have not been accepted. Do not double-submit it.

**Scope:** These operational instructions apply to SA2 GPT/Codex work. They are not a requirement for Claude and do not change SA1/Claude workflows.
