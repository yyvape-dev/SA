shader_type canvas_item;
// 画面の仕上げ（UI より下の CanvasLayer）：暗い所を青紫へ寄せ（明るい所の暖色・ネオン色は残す）、四隅を少し暗くする。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.38;
uniform float grade = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float shadow = 1.0 - smoothstep(0.12, 0.55, lum);
	vec3 cool = c * vec3(0.82, 0.84, 1.18) + vec3(0.012, 0.004, 0.03);
	c = mix(c, cool, shadow * grade);
	vec2 d = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.45, 1.05, length(d)) * strength;
	c = mix(c, vec3(0.03, 0.02, 0.06), v);
	COLOR = vec4(c, 1.0);
}
