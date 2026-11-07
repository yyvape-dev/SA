// REEBOO Stylized 2D VFX - shared code for every fx2d_*.gdshader.
// Timing: ReebooFx2D writes fx_time (seconds since play) every frame. A layer is visible from `delay` for `life` seconds.
// Colour: three-band toon ramp, hot core -> mid -> edge, plus an additive halo. render_mode blend_premul_alpha lets
// one shader be normal (additive = 0, readable on light backgrounds) or fully additive (additive = 1).

group_uniforms timing;
uniform float fx_time = 0.2;
uniform float delay = 0.0;
uniform float life : hint_range(0.01, 10.0) = 0.5;
uniform bool looping = false;
group_uniforms colour;
uniform vec4 color_core : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.72, 0.25, 1.0);
uniform vec4 color_edge : source_color = vec4(0.92, 0.28, 0.12, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float glow : hint_range(0.0, 2.0) = 0.4;
uniform float additive : hint_range(0.0, 1.0) = 0.0;
uniform float bands : hint_range(1.0, 6.0) = 3.0;
uniform float seed = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
group_uniforms;

varying vec4 fx_modulate;

float fx_progress() {
	float p = (fx_time - delay) / max(life, 0.001);
	return looping ? fract(max(p, 0.0)) : p;
}

float fx_alive(float p) {
	return step(0.0, p) * step(p, 1.0) * step(delay, fx_time);
}

float fx_ease_out(float x, float k) {
	return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), k);
}

// Anti-aliased coverage of a signed distance (negative = inside).
float fx_aa(float d) {
	float w = max(fwidth(d), 0.0001);
	return clamp(0.5 - d / w, 0.0, 1.0);
}

// Toon bands with a soft step between them.
float fx_band(float t) {
	float s = clamp(t, 0.0, 0.999) * bands;
	float f = fract(s);
	float w = clamp(fwidth(s) * 1.5, 0.02, 0.5);
	return (floor(s) + smoothstep(1.0 - w, 1.0, f)) / bands;
}

vec3 fx_ramp(float t) {
	vec3 c = mix(color_core.rgb, color_mid.rgb, smoothstep(0.0, 0.5, t));
	return mix(c, color_edge.rgb, smoothstep(0.5, 1.0, t));
}

float fx_noise(vec2 uv) {
	return texture(noise_tex, uv).r;
}

float fx_hash(float n) {
	return fract(sin(n * 127.1 + seed * 31.7) * 43758.5453);
}

// Final colour: premultiplied, body + additive halo, times node modulate (tint and fade).
vec4 fx_out(vec3 body, float cov, vec3 halo_col, float halo) {
	vec3 rgb = body * cov * intensity + halo_col * halo * intensity;
	float a = cov * (1.0 - additive);
	return vec4(rgb * fx_modulate.rgb * fx_modulate.a, a * fx_modulate.a);
}
