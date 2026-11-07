// REEBOO Stylized 2D VFX - slash: a crescent arc (or a straight thrust) whose head sweeps ahead of a tail that catches up.
// Thick and hot at the leading edge, thin and stringy at the tail. Rotate or flip the node to aim it.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms slash;
uniform float straight : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.1, 1.0) = 0.78;
uniform float thickness : hint_range(0.01, 0.8) = 0.26;
uniform float arc_start : hint_range(-3.14, 3.14) = -2.2;
uniform float arc_end : hint_range(-3.14, 3.14) = 1.0;
uniform float head_speed : hint_range(1.0, 6.0) = 2.4;
uniform float streaks : hint_range(0.0, 1.0) = 0.55;
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
	float s = (atan(c.y, c.x) - arc_start) / (arc_end - arc_start);
	if (straight > 0.5) {
		s = UV.x;
		r = radius - (c.y + thickness) * 0.5;
	}
	float head = fx_ease_out(p * head_speed, 2.2);
	float tail = smoothstep(0.08, 1.0, p);
	float u = (s - tail) / max(head - tail, 0.001);
	float inside_arc = step(0.0, u) * step(u, 1.0);
	float prof = sin(3.14159 * pow(clamp(u, 0.0, 1.0), 1.7));
	float w = thickness * prof * (1.0 - 0.45 * p);
	float d = max(r - radius, (radius - w) - r);
	float across = clamp((radius - r) / max(w, 0.001), 0.0, 1.0);
	float n = fx_noise(vec2(s * 5.0 - p * 1.5 + seed, across * 0.6));
	float erode = streaks * pow(1.0 - clamp(u, 0.0, 1.0), 1.5) * (0.3 + 0.7 * across) + smoothstep(0.55, 1.0, p) * 0.7 * (0.4 + 0.6 * across);
	float cov = fx_aa(d) * inside_arc * smoothstep(erode - 0.05, erode + 0.05, n) * alive;
	float heat = clamp(across * 0.7 + (1.0 - u) * 0.45 + p * 0.25, 0.0, 1.0);
	vec3 col = fx_ramp(fx_band(heat));
	float halo = glow * exp(-abs(r - radius + w * 0.5) * 10.0) * inside_arc * prof * (1.0 - p) * alive;
	COLOR = fx_out(col, cov, color_mid.rgb, halo * 0.6);
}
