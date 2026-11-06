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
uniform float core_gain = 1.3;   // mode 1 の中心の白の強さ
uniform bool billboard = false;
// 2026-11-06：流れる模様（mode 0）。元：godotshaders.com「Slash Shader」（ノイズで UV をゆがめる・明滅・溶けて消える）。
uniform sampler2D noise : filter_linear, repeat_enable;   // 継ぎ目の無いノイズ（fx.gd が FastNoiseLite で作る）
uniform float n_amt = 0.0;    // 0＝従来の帯、1＝模様入り
uniform float seed = 0.0;     // 帯ごとに模様をずらす

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
		vec2 nuv = vec2(u * 2.2 - head * 0.9 + seed, v * 0.6 + seed * 0.37);
		float nz = texture(noise, nuv).r;
		float nz2 = texture(noise, nuv * vec2(3.0, 1.4) + vec2(head * 0.5, 0.0)).r;
		v = clamp(v + (nz - 0.5) * 0.45 * n_amt, 0.0, 1.0);   // 縁が波打つ
		float behind = head - u;
		float a = behind < 0.0 ? 0.0 : exp(-behind * tail);
		a *= smoothstep(0.0, 0.04, behind + 0.04);   // 先端を少しだけ柔らかく
		float core = exp(-v * 7.0);
		float mainc = exp(-v * 2.2);
		float glow = (1.0 - v);
		c = col_core.rgb * core * 1.4 + col_main.rgb * mainc * 1.1 + col_glow.rgb * glow * 0.7;
		c *= a;
		if (n_amt > 0.0) {
			// 筋（刃の流れに沿った明暗）と、終わりに模様に沿って溶ける
			float streak = 0.35 + 1.35 * smoothstep(0.3, 0.75, nz2);   // 刃の流れに沿った明暗（強め）
			float dis = smoothstep(1.0 - fade - 0.12, 1.0 - fade + 0.12, nz * 0.85 + 0.15 * (1.0 - v));
			float edge = dis * (1.0 - smoothstep(1.0 - fade, 1.0 - fade + 0.25, nz)) * step(fade, 0.98);
			c = mix(c, c * streak * dis + col_core.rgb * edge * a * 0.6, n_amt);
		}
	} else if (mode == 1) {
		float r = length(UV - vec2(0.5)) * 2.0;
		float k = clamp(1.0 - r, 0.0, 1.0);
		c = col_core.rgb * pow(k, 6.0) * core_gain + col_main.rgb * pow(k, 2.5) * 0.7 + col_glow.rgb * k * 0.35;
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
