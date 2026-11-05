shader_type spatial;
// キャラの絵（Sprite3D の material_override）。縦軸だけカメラへ向ける。
// 被弾の光（加算）・色の掛け算・足元を軸にした傾き（倒れる）を持つ。テクスチャはスクリプトが tex に入れる。
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D tex : source_color, filter_linear;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);   // rgb＝光の色、a＝強さ（足し算）
uniform vec4 tint = vec4(1.0);                    // 掛け算（a は透明度）
uniform float rot = 0.0;                          // 足元を軸にした傾き（ラジアン）

void vertex() {
	float c = cos(rot);
	float s = sin(rot);
	VERTEX.xy = vec2(c * VERTEX.x - s * VERTEX.y, s * VERTEX.x + c * VERTEX.y);
	// Godot の BILLBOARD_FIXED_Y と同じ
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * tint.rgb + flash.rgb * flash.a * c.a;
	ALPHA = c.a * tint.a;
}
