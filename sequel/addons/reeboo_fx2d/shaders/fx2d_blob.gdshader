// REEBOO Stylized 2D VFX - noise blob: fireballs, smoke clouds, gas and dust. It grows fast, cools from a hot core to the
// edge colour and erodes into pieces as it ages (the erosion threshold rises with age). drift moves the noise upward.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://addons/reeboo_fx2d/shaders/fx2d_common.gdshaderinc"

group_uniforms blob;
uniform float size_start : hint_range(0.0, 1.0) = 0.25;
uniform float size_end : hint_range(0.0, 1.0) = 0.85;
uniform float grow_power : hint_range(0.5, 8.0) = 3.5;
uniform float distort : hint_range(0.0, 1.5) = 0.45;
uniform float noise_scale : hint_range(0.2, 6.0) = 1.4;
uniform float erosion_start : hint_range(0.0, 1.0) = 0.0;
uniform float erosion_end : hint_range(0.0, 1.0) = 0.95;
uniform float drift : hint_range(-2.0, 2.0) = 0.35;
uniform float cool_speed : hint_range(0.0, 3.0) = 1.2;
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
	float S = max(mix(size_start, size_end, fx_ease_out(p, grow_power)), 0.001);
	float n1 = fx_noise(c * noise_scale * 0.5 + vec2(seed, seed * 0.37) + vec2(0.0, p * drift));
	float n2 = fx_noise(c * noise_scale * 1.3 + vec2(seed * 1.7, 0.21) + vec2(0.0, p * drift * 1.6));
	float dens = 1.0 - r / S + (n1 - 0.5) * distort + (n2 - 0.5) * distort * 0.5;
	float ero = mix(erosion_start, erosion_end, smoothstep(0.0, 1.0, p));
	float cov = fx_aa((ero - dens) * 0.25) * smoothstep(1.0, 0.92, r) * alive;
	float heat = clamp(1.0 - dens + p * cool_speed - 0.15, 0.0, 1.0);
	vec3 col = fx_ramp(fx_band(heat));
	float halo = glow * smoothstep(S * 1.25, 0.0, r) * (1.0 - p) * (1.0 - p) * alive;
	COLOR = fx_out(col, cov, color_mid.rgb, halo * 0.5);
}
