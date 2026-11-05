shader_type spatial;
// 建物の足元の薄い暗がり（地面に寝かせた板）。UV.y＝壁際 0 → 手前 1 で薄れ、左右の端もぼかす。
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float strength = 0.45;

void fragment() {
	float a = pow(1.0 - UV.y, 1.8);
	a *= smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.9, UV.x);
	ALBEDO = vec3(0.02, 0.015, 0.03);
	ALPHA = strength * a;
}
