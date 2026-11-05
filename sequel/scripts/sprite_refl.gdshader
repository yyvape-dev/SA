shader_type spatial;
// 濡れた路面に映るキャラの逆さの姿。足元から下へ、離れるほど薄く、少し揺れる。地面に隠れないよう深度は見ない。
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D tex : source_color, filter_linear;
uniform float strength = 0.36;
uniform float len = 1.7;      // これだけ下まで映る（m）
uniform vec4 tint = vec4(1.0);
varying float hy;

void vertex() {
	hy = VERTEX.y;
	VERTEX.y = -VERTEX.y;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 ts = 1.0 / vec2(textureSize(tex, 0));
	vec2 uv = UV + vec2(sin(hy * 9.0 + TIME * 2.6) * 3.0 * ts.x, 0.0);
	vec4 c = texture(tex, uv);
	float fade = 1.0 - clamp(hy / len, 0.0, 1.0);
	ALBEDO = c.rgb * tint.rgb * 0.8;
	ALPHA = c.a * tint.a * strength * fade * fade;
}
