# Audio options implementation plan
Goal: top-right translucent speaker opens BGM/SE sliders and mute; persist per device.
Approved design: small non-modal panel, independent BGM/SE, one mute toggle, close button. Godot UI; preserve music region/ducking and cue balance. Defaults retain existing audio levels.
Task 1: Add failing Godot behavior test for independent gains, mute restoration and ConfigFile persistence. Implement in combat_audio.gd and sound_options.gd; suppress gameplay touch while panel is open or icon is touched.
Task 2: Run audio/music and options tests including packed data; inspect actual render at 1280x720 and mobile aspect. Preserve accepted assets and runtime startup sequence when patching existing preview pack. Commit on feat/sa2-audio-options-20261112; publish existing private T6 Site.
Checks: zero volume silence, mute/unmute retains sliders, dialogue duck preserves gain, active voices update, repeated creation has one panel, outside touch blocked, saved values restored after restart. iPhone subjective acceptance remains separate.

Execution: tasks 1–2 implemented inline. New behavior test first failed on missing settings_path, then passed. Independent review found legacy T5 touch and dialogue advance bypasses; legacy input reproduction failed before correction and passed afterward. Transparent shield additionally prevents underlying GUI button clicks. Full 25-test suite green; source and packed options tested. Native author inspected rendered image; independent reviewer confirmed anchoring and readability. Main untouched.
