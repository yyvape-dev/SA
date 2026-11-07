// REEBOO Stylized 2D VFX - light pillar: a column that shoots up from the bottom edge (origin at the feet), streams upward
// and narrows away (level ups, heals, power-ups).
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms pillar;
uniform float width : hint_range(0.02, 1.0) = 0.4;
uniform float rise : hint_range(0.01, 1.0) = 0.22;
uniform float scroll : hint_range(-6.0, 6.0) = 1.6;
uniform float streaks : hint_range(0.0, 1.0) = 0.5;
group_uniforms;

void vertex() {
	fx_modulate = COLOR;
}

void fragment() {
	float p0 = fx_progress();
	float alive = looping ? step(delay, fx_time) : fx_alive(p0);
	float p = clamp(p0, 0.0, 1.0);
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;
	float top = 1.0 - fx_ease_out(p / rise, 2.5);
	float narrow = looping ? 1.0 : 1.0 - smoothstep(0.45, 1.0, p);
	float w = width * narrow * mix(1.0, 0.7, 1.0 - y);
	float d = abs(x) - w;
	float n = fx_noise(vec2(x * 1.5 + seed, y * 1.2 + fx_time * scroll));
	float cut = streaks * (0.35 + 0.65 * (1.0 - y)) * mix(0.2, 1.0, clamp(abs(x) / max(w, 0.001), 0.0, 1.0));
	float vert = smoothstep(top, top + 0.3, y) * smoothstep(0.0, 0.25, y);
	float cov = fx_aa(d) * vert * smoothstep(cut - 0.06, cut + 0.06, n) * alive * step(0.002, w);
	float heat = clamp(abs(x) / max(w, 0.001) * 0.8 + (1.0 - y) * 0.35 + p * 0.2, 0.0, 1.0);
	vec3 col = fx_ramp(fx_band(heat));
	float halo = glow * exp(-max(d, 0.0) * 6.0) * vert * narrow * smoothstep(1.0, 0.8, abs(x)) * alive;
	COLOR = fx_out(col, cov, color_mid.rgb, halo * 0.45);
}
