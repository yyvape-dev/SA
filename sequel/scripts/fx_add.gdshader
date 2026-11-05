shader_type spatial;
// エフェクトの共通（加算・光らない面）。mode で形を切り替える。
//  0 = 斬撃の帯（UV.x＝弧の始め→終わり、UV.y＝外の縁 0 → 内 1。head まで描き、後ろは尾を引いて消える）
//  1 = 丸い光（中心が白、外へ色）
//  2 = 頂点色そのまま（火花の筋）
//  3 = 床の予兆（四角の縁が濃く、中が薄い。fill＝溜まり具合）
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform int mode = 0;
uniform vec4 col_glow : source_color = vec4(0.27, 0.57, 1.0, 1.0);
uniform vec4 col_main : source_color = vec4(0.53, 0.76, 1.0, 1.0);
uniform vec4 col_core : source_color = vec4(1.0);
uniform float head = 1.0;     // 0〜1.3：斬撃の先端の位置
uniform float fade = 1.0;     // 全体の明るさ
uniform float tail = 3.5;     // 尾の短さ
uniform float fill = 0.0;
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec3 c = vec3(0.0);
	if (mode == 0) {
		float u = UV.x;
		float v = UV.y;
		float behind = head - u;
		float a = behind < 0.0 ? 0.0 : exp(-behind * tail);
		a *= smoothstep(0.0, 0.04, behind + 0.04);   // 先端を少しだけ柔らかく
		float core = exp(-v * 7.0);
		float mainc = exp(-v * 2.2);
		float glow = (1.0 - v);
		c = col_core.rgb * core * 1.4 + col_main.rgb * mainc * 1.1 + col_glow.rgb * glow * 0.7;
		c *= a;
	} else if (mode == 1) {
		float r = length(UV - vec2(0.5)) * 2.0;
		float k = clamp(1.0 - r, 0.0, 1.0);
		c = col_core.rgb * pow(k, 6.0) * 1.3 + col_main.rgb * pow(k, 2.5) * 0.7 + col_glow.rgb * k * 0.35;
	} else if (mode == 2) {
		c = COLOR.rgb * COLOR.a;
	} else {
		vec2 d = abs(UV - vec2(0.5)) * 2.0;
		float edge = smoothstep(0.86, 1.0, max(d.x, d.y));
		float inner = step(d.x, fill) * 0.35;
		c = col_main.rgb * (edge * 0.9 + 0.12 + inner);
	}
	ALBEDO = c * fade;
}
