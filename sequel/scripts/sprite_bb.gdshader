shader_type spatial;
// キャラ・手前の部品の絵（Sprite3D／板の material_override）。縦軸だけカメラへ向ける。
// 被弾の光（加算）・色の掛け算・足元を軸にした傾き（倒れる）。テクスチャはスクリプトが tex に入れる。
// 2026-11-05：その場の光（看板・灯り）で輪郭の片側を細く光らせる縁取り・体を少し染める・手前の部品のぼかし。
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D tex : source_color, filter_linear;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);   // rgb＝光の色、a＝強さ（足し算）
uniform vec4 tint = vec4(1.0);                    // 掛け算（a は透明度）
uniform float rot = 0.0;                          // 足元を軸にした傾き（ラジアン）
uniform vec4 light_col = vec4(1.0, 1.0, 1.0, 0.0);// その場の光の色（a＝体を染める量）
uniform vec4 rim_col = vec4(1.0, 1.0, 1.0, 0.0);  // 縁取りの色（a＝強さ）
uniform float rim_dir = 1.0;                      // 光の来る側（UV の x の向き。左右反転はスクリプトで考慮済み）
uniform float rim_px = 4.0;                       // 縁取りの太さ（テクスチャの画素）
uniform float blur = 0.0;                         // ぼかし（テクスチャの画素。手前の部品だけ）

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
	vec2 ts = 1.0 / vec2(textureSize(tex, 0));
	vec4 c = texture(tex, UV);
	if (blur > 0.0) {
		vec4 acc = c;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			acc += texture(tex, UV + vec2(cos(a), sin(a)) * ts * blur);
		}
		c = acc / 9.0;
	}
	vec3 col = c.rgb * tint.rgb;
	col *= mix(vec3(1.0), light_col.rgb, light_col.a);   // 色味だけ寄せる（明るくはしない）
	if (rim_col.a > 0.0) {
		float nb = texture(tex, UV + vec2(rim_dir * rim_px * ts.x, 0.0)).a;
		float edge = step(0.6, c.a) * (1.0 - smoothstep(0.0, 0.5, nb));   // 光の側の輪郭だけ
		col += rim_col.rgb * rim_col.a * edge;
	}
	ALBEDO = col + flash.rgb * flash.a * c.a;
	ALPHA = c.a * tint.a;
}
