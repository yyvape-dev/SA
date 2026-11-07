---
name: sprite-animation
description: Produce, normalize and validate sprite animations, sheets and Godot exports from a fixed character master. Uses the pinned Agent Sprite Forge submodule.
---

# SA Sprite Animation workflow

1. Read `sequel/HANDOFF.md` for SA2 and existing project Skills before planning anything. Preserve original identity, head/body scale, art style, facing, and asset dimensions.
2. Ensure the submodule is present with `git submodule update --init tools/agent-sprite-forge`. Do not execute arbitrary install scripts or change dependencies without reviewing them.
3. Read `tools/agent-sprite-forge/skills/generate2dsprite/SKILL.md` and, for character motion, `tools/agent-sprite-forge/skills/video2dsprite/SKILL.md`. These depend on sibling scripts under tools/agent-sprite-forge; never copy only SKILL.md and claim a runnable install.
4. Preserve user's fixed canvas, magenta background, root location and style rules; do not use upstream default dimensions or scaling when they conflict with project rules.
5. Use deterministic frame alignment, chroma removal and contact sheets; verify identity and limb morphology visually. Run a Godot actual-render test before describing assets as approved.
6. Treat image-to-video as an optional route requiring an external provider or user-supplied footage. If not available, report that capability missing and do not fabricate an animation output.
7. No edits to main as part of this evaluation. Do not alter the original game art or existing .claude Skills.

Source: https://github.com/0x0funky/agent-sprite-forge, MIT licensed. Pinned revision: 6b3da5c444363378e20f3fce130ebecc22f343dd.

This skill is an evaluation entry point, not a claim of successful Godot/Codex execution or automatic integration with ChatGPT image generation.
