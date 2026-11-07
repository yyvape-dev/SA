shader_type spatial;
// 通りを横切る提灯（絵を使わず形を描く）。縦軸だけカメラへ向け、上の吊り元を軸に揺れる。中が明るく、横の骨が入る。
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;

global uniform float bg_dim;
uniform vec4 col_in : source_color = vec4(1.0, 0.72, 0.36, 1.0);
uniform vec4 col_out : source_color = vec4(0.92, 0.12, 0.08, 1.0);
uniform float bright = 1.25;

void vertex() {
	float ph = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 0.9;
	float a = sin(TIME * 1.4 + ph) * 0.12;
	vec2 v = VERTEX.xy - vec2(0.0, 0.5);
	VERTEX.xy = vec2(cos(a) * v.x - sin(a) * v.y, sin(a) * v.x + cos(a) * v.y) + vec2(0.0, 0.5);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = pow(p.x / 0.82, 2.0) + pow(p.y / 0.74, 2.0);
	float body = 1.0 - smoothstep(0.9, 1.0, d);
	float cap = step(0.74, abs(p.y)) * step(abs(p.x), 0.42) * step(abs(p.y), 0.92);
	float rib = 0.82 + 0.18 * cos(p.y * 26.0);
	vec3 c = mix(col_out.rgb, col_in.rgb, pow(clamp(1.0 - d, 0.0, 1.0), 1.5)) * rib * bright;
	ALBEDO = mix(c, vec3(0.05, 0.03, 0.02), cap);
	ALBEDO *= bg_dim;   // 大技の暗転（specs/vfx_overhaul.md）
	ALPHA = max(body, cap);
}
