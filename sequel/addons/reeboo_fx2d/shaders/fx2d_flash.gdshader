// REEBOO Stylized 2D VFX - impact flash: a hot disc that pops and shrinks, a soft halo, and an optional four-arm plus twinkle.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms flash;
uniform float peak : hint_range(0.01, 0.9) = 0.18;
uniform float core_size : hint_range(0.0, 1.0) = 0.45;
uniform float distort : hint_range(0.0, 1.0) = 0.15;
uniform float cross_amount : hint_range(0.0, 2.0) = 0.0;
uniform float cross_width : hint_range(0.0, 0.3) = 0.07;
uniform float cross_angle : hint_range(-3.2, 3.2) = 0.0;
group_uniforms;

void vertex() {
	fx_modulate = COLOR;
}

void fragment() {
	float p0 = fx_progress();
	float alive = fx_alive(p0);
	float p = clamp(p0, 0.0, 1.0);
	float s = p < peak ? fx_ease_out(p / peak, 2.0) : pow(1.0 - (p - peak) / (1.0 - peak), 1.6);
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ang = atan(c.y, c.x) / 6.28318 + 0.5;
	float wob = (fx_noise(vec2(ang * 3.0 + seed, p * 0.5)) - 0.5) * distort;
	float R = core_size * s;
	float d = r - R * (1.0 + wob);
	float disc = fx_aa(d) * step(0.001, R);
	float heat = clamp(r / max(R, 0.001) * 0.8 + (1.0 - s) * 0.5, 0.0, 1.0);
	vec3 col = fx_ramp(fx_band(heat));
	// four-arm plus twinkle: tapered arms, always exactly four
	float ca = cos(cross_angle);
	float sa = sin(cross_angle);
	vec2 q = vec2(ca * c.x - sa * c.y, sa * c.x + ca * c.y);
	float L = 0.98 * s;
	float arm_x = abs(q.y) - cross_width * s * max(1.0 - abs(q.x) / max(L, 0.001), 0.0);
	float arm_y = abs(q.x) - cross_width * s * max(1.0 - abs(q.y) / max(L, 0.001), 0.0);
	float crs = clamp(max(fx_aa(arm_x) * step(abs(q.x), L), fx_aa(arm_y) * step(abs(q.y), L)) * cross_amount, 0.0, 1.0);
	float cov = max(disc, crs) * alive;
	col = mix(col, color_core.rgb, crs * (1.0 - disc));
	float halo = glow * exp(-r * 3.5) * s * smoothstep(1.0, 0.7, r) * alive;
	COLOR = fx_out(col, cov, color_mid.rgb, halo);
}
