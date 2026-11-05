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
uniform float fog_amt = 0.0;
uniform vec4 fog_col : source_color = vec4(0.38, 0.27, 0.40, 1.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	float hot = smoothstep(0.72, 0.95, mx) * smoothstep(0.15, 0.4, sat);
	col = mix(col * dim, col * (1.0 + glow_boost), hot);
	float f = fog_amt * (1.0 - hot * 0.5);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), clamp(f * 0.55, 0.0, 1.0)) * (1.0 - f * 0.3);
	col = mix(col, fog_col.rgb, clamp(f * 0.42, 0.0, 1.0));
	ALBEDO = col;
}
