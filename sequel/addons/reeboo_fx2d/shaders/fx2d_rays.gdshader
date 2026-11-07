// REEBOO Stylized 2D VFX - speed-line burst: short dashes that shoot outward at uneven angles and lengths.
// The dashes never meet in the middle and their count and spacing are irregular, so the burst never reads as a star.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms rays;
uniform float count : hint_range(3.0, 40.0) = 15.0;
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.7;
uniform float inner_start : hint_range(0.0, 1.0) = 0.15;
uniform float inner_end : hint_range(0.0, 1.0) = 0.85;
uniform float outer_start : hint_range(0.0, 1.0) = 0.3;
uniform float outer_end : hint_range(0.0, 1.0) = 1.0;
uniform float ray_width : hint_range(0.0, 0.3) = 0.05;
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
	float a = atan(c.y, c.x) / 6.28318 + 0.5;
	float bin = floor(a * count);
	float h1 = fx_hash(bin + 1.0);
	float h2 = fx_hash(bin + 17.0);
	float centre = (bin + 0.5 + (h1 - 0.5) * 0.6) / count;
	float perp = r * (a - centre) * 6.28318;
	float lenf = mix(0.4, 1.0, h2);
	float rin = mix(inner_start, inner_end * lenf, fx_ease_out(p, 3.0));
	float rout = mix(outer_start, outer_end * lenf, fx_ease_out(min(p * 1.6, 1.0), 3.0));
	float u = clamp((r - rin) / max(rout - rin, 0.001), 0.0, 1.0);
	float w = ray_width * (1.0 - p) * mix(0.6, 1.3, h1) * 4.0 * u * (1.0 - u);
	float d = abs(perp) - w;
	float on = step(h2 * 0.999, fill_ratio) * step(rin, r) * step(r, rout);
	float cov = fx_aa(d) * on * alive;
	vec3 col = fx_ramp(fx_band(clamp((1.0 - u) * 0.6 + p * 0.6, 0.0, 1.0)));
	COLOR = fx_out(col, cov, color_mid.rgb, cov * glow * 0.3);
}
