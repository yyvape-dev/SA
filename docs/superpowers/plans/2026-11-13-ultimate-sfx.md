# Ultimate SE implementation
Approved: existing Power Up Charge (qubodup #172631) and Dramatic Hit (#222517), no AI generation.
1. Retrieve distributor HQ previews, convert to 48kHz mono PCM; preserve pitch and playback speed, shorten release tail with fade. Record provenance and hashes.
2. Test expected failure: successful Rana/Lily ultimate emits charge once, rejected Rana activation emits nothing, cut-end crossing emits release once independent of enemy contact. Add dedicated cinematic voice so normal hit pool cannot steal it. User SE gain and mute apply to both voices.
3. Implement hooks only at successful start and animation cut-end boundary, no timers surviving resets. Run tests and audio/options/training regressions on Godot4.7.2. Patch accepted preview pack without asset/runtime replacement, verify packed test, publish same private Site. Commit feature branch; main unchanged.
