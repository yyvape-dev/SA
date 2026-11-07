shader_type spatial;
// 奥の地面（建物の後ろ〜遠景の板）。手前は暗く、奥ほど遠景の下端の霧の色に溶ける。
render_mode unshaded, cull_back;

global uniform float bg_dim;
uniform vec4 near_col : source_color = vec4(0.16, 0.14, 0.19, 1.0);
uniform vec4 fog_col : source_color = vec4(0.40, 0.29, 0.32, 1.0);
uniform float z_near = -8.0;
uniform float z_far = -58.0;
varying float wz;

void vertex() {
	wz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float t = clamp((z_near - wz) / (z_near - z_far), 0.0, 1.0);
	ALBEDO = mix(near_col.rgb, fog_col.rgb, pow(t, 0.7));
	ALBEDO *= bg_dim;   // 大技の暗転（specs/vfx_overhaul.md）
}
