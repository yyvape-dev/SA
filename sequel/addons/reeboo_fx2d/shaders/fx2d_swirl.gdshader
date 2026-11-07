// REEBOO Stylized 2D VFX - spiral swirl: curved arms that turn around a hot centre (magic bursts, portals, charge-ups).
// One-shot: it opens, spins and closes over its life. Looping: it stays open and spins with time.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms swirl;
uniform float arms : hint_range(1.0, 8.0) = 3.0;
uniform float twist : hint_range(-8.0, 8.0) = 3.0;
uniform float spin : hint_range(-6.0, 6.0) = 1.2;
uniform float arm_width : hint_range(0.05, 0.95) = 0.42;
uniform float inner : hint_range(0.0, 1.0) = 0.12;
uniform float outer : hint_range(0.0, 1.0) = 0.92;
uniform float open_close : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

void vertex() {
	fx_modulate = COLOR;
}

void fragment() {
	float p0 = fx_progress();
	float alive = looping ? step(delay, fx_time) : fx_alive(p0);
	float p = clamp(p0, 0.0, 1.0);
	float env = looping ? 1.0 : mix(1.0, smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.55, 1.0, p)), open_close);
	float sc = looping ? 1.0 : mix(0.55, 1.0, fx_ease_out(p, 3.0));
	vec2 c = (UV * 2.0 - 1.0) / sc;
	float r = length(c);
	float a = atan(c.y, c.x) / 6.28318;
	float s = fract(a * arms + r * twist - fx_time * spin + seed);
	float n = fx_noise(vec2(a * 2.0 + seed, r - fx_time * 0.3));
	float band_d = abs(s - 0.5) * 2.0 - arm_width * (0.75 + 0.5 * n) * env;
	float ring_d = max(inner - r, r - outer * (0.7 + 0.3 * env));
	float d = max(band_d * 0.35, ring_d);
	float cov = fx_aa(d) * alive * step(0.01, env);
	float heat = clamp(r / outer * 0.85 + (1.0 - env) * 0.4, 0.0, 1.0);
	vec3 col = fx_ramp(fx_band(heat));
	float halo = glow * smoothstep(outer, 0.0, r) * env * alive;
	COLOR = fx_out(col, cov, color_mid.rgb, halo * 0.5);
}
