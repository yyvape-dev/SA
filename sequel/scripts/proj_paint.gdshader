// 塗られた下絵を、下絵を撮ったカメラから投影して箱に貼る（マットペイントの投影）。
// ref_vp＝下絵を撮ったカメラの「投影×視点」。絵の外やマゼンタの所は、箱の仮の色を出す。
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_disable;
uniform mat4 ref_vp;
uniform vec4 fallback : source_color = vec4(0.5, 0.5, 0.5, 1.0);
// true＝絵の透明度で背景を見分ける（import_paint.py が外周のマゼンタだけを透明にした絵）。false＝色で見分ける（古い絵）
uniform bool alpha_mask = false;
// 奥行きと明るさ（2026-11-05）：面を dim 倍に暗くし、明るく色のある所（ネオン・灯り）だけは暗くせず少し持ち上げる。
// fog_amt：奥ほど大きく（b0 ＞ 建物）。彩度を下げ、暗くし、紫の霧を重ねる。明るい所は霧を少し透かす。
uniform float dim = 1.0;
uniform float glow_boost = 0.0;
// 夜（2026-11-05 その2）：光る画素（明るく彩度の高いネオン・灯り、とても明るい窓）は残し、それ以外を dim 倍に。
// flicker＝1 の部品は、ネオンの色（ピンク・水色）の光る画素のうち、区画ごとに一部だけ時々消える（明滅）。
uniform float flicker = 0.0;
uniform float fog_amt = 0.0;
uniform vec4 fog_col : source_color = vec4(0.38, 0.27, 0.40, 1.0);
// ofs＝部品の置き場所のずれ（使い回し用）。絵は「下絵を撮った位置」から投影するので、ずらした分を引いて元の位置で計算する。
uniform vec3 ofs = vec3(0.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - ofs;
}

void fragment() {
	vec4 c = ref_vp * vec4(wpos, 1.0);
	vec2 uv = c.xy / c.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	vec3 col = fallback.rgb;
	if (c.w > 0.0 && uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		vec4 p = texture(paint, uv);
		// マゼンタ（背景の名残）は使わない
		float mag = alpha_mask ? 1.0 - step(0.5, p.a) : step(0.75, p.r) * step(0.75, p.b) * (1.0 - step(0.45, p.g));
		col = mix(p.rgb, fallback.rgb, mag);
	}
	float mx = max(col.r, max(col.g, col.b));
	float sat = mx - min(col.r, min(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	float srel = (mx - mn) / max(mx, 0.001);
	float hot = max(smoothstep(0.6, 0.85, mx) * smoothstep(0.25, 0.5, srel), smoothstep(0.9, 0.99, mx));
	if (flicker > 0.0) {
		float neon = hot * max(step(col.g + 0.15, min(col.r, col.b)), step(col.r + 0.2, min(col.g, col.b)));
		vec2 cell = floor(uv * vec2(9.0, 7.0));
		float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		float n = fract(sin(floor(TIME * 11.0 + h * 50.0) * 12.9898 + h * 78.233) * 43758.5453);
		float off = step(h, 0.3) * step(0.82, n) * neon * flicker;
		col *= 1.0 - off * 0.8;
	}
	col = mix(col * dim, col * (1.0 + glow_boost), hot);
	float f = fog_amt * (1.0 - hot * 0.5);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), clamp(f * 0.55, 0.0, 1.0)) * (1.0 - f * 0.3);
	col = mix(col, fog_col.rgb, clamp(f * 0.42, 0.0, 1.0));
	ALBEDO = col;
}
