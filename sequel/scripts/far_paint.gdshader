shader_type spatial;
// 遠景の一枚絵。奥行きの霧（彩度を下げ・暗くし・紫の霧を重ねる）を建物より強くかける。
render_mode unshaded, cull_back;

global uniform float bg_dim;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float fog_amt = 1.3;
uniform vec4 fog_col : source_color = vec4(0.38, 0.27, 0.40, 1.0);

void fragment() {
	vec3 col = texture(tex, UV).rgb;
	float mx = max(col.r, max(col.g, col.b));
	float hot = smoothstep(0.75, 0.95, mx);
	float f = fog_amt * (1.0 - hot * 0.4);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), clamp(f * 0.45, 0.0, 1.0)) * (1.0 - f * 0.2);
	col = mix(col, fog_col.rgb, clamp(f * 0.4, 0.0, 1.0));
	ALBEDO = col;
	ALBEDO *= bg_dim;   // 大技の暗転（specs/vfx_overhaul.md）
}
