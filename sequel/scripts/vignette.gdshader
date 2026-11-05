shader_type canvas_item;
// 画面の四隅を少し暗くする
uniform float strength = 0.38;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.45, 1.05, length(d));
	COLOR = vec4(0.03, 0.02, 0.06, v * strength);
}
