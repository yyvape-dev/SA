// REEBOO Stylized 2D VFX - expanding ring (shockwaves, impact rings, pickup rings).
// The band expands with an ease-out, thins with age and breaks up into pieces (noise erosion). Squash the node for ground rings.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms ring;
uniform float radius_start : hint_range(0.0, 1.0) = 0.1;
uniform float radius_end : hint_range(0.0, 1.0) = 0.85;
uniform float width_start : hint_range(0.0, 1.0) = 0.3;
uniform float width_end : hint_range(0.0, 1.0) = 0.0;
uniform float expand_power : hint_range(0.5, 8.0) = 3.0;
uniform float breakup : hint_range(0.0, 1.0) = 0.45;
uniform float noise_scale : hint_range(0.5, 8.0) = 3.0;
group_uniforms;

void vertex() {
	fx_modulate = COLOR;
}

void fragment() {
	float p0 = fx_progress();
	float alive = fx_alive(p0);
	float p = clamp(p0, 0.0, 1.0);
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ang = atan(c.y, c.x) / 6.28318 + 0.5;
	float R = mix(radius_start, radius_end, fx_ease_out(p, expand_power));
	float W = max(mix(width_start, width_end, pow(p, 0.7)), 0.0);
	float d = abs(r - R) - W * 0.5;
	float n = fx_noise(vec2(ang * noise_scale + seed, r * 0.7 - p * 0.35));
	float erode = breakup * smoothstep(0.15, 1.0, p);
	float cov = fx_aa(d) * smoothstep(erode - 0.04, erode + 0.04, n) * step(0.0005, W) * alive;
	float across = clamp((R + W * 0.5 - r) / max(W, 0.001), 0.0, 1.0);
	float heat = clamp(across * 0.75 + p * 0.55, 0.0, 1.0);
	vec3 col = fx_ramp(fx_band(heat));
	float halo = glow * exp(-max(d, 0.0) * 9.0) * (1.0 - p) * smoothstep(1.0, 0.8, r) * alive;
	COLOR = fx_out(col, cov, color_mid.rgb, halo * 0.5);
}
