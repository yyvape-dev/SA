// 塗られた下絵を、下絵を撮ったカメラから投影して箱に貼る（マットペイントの投影）。
// ref_vp＝下絵を撮ったカメラの「投影×視点」。絵の外やマゼンタの所は、箱の仮の色を出す。
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_disable;
uniform mat4 ref_vp;
uniform vec4 fallback : source_color = vec4(0.5, 0.5, 0.5, 1.0);
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
		float mag = step(0.75, p.r) * step(0.75, p.b) * (1.0 - step(0.45, p.g));
		col = mix(p.rgb, fallback.rgb, mag);
	}
	ALBEDO = col;
}
