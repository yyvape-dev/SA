shader_type spatial;
// 濡れた路面の映り込み（光の筋）。地面に寝かせた板に、看板・灯りの色を縦に伸ばして足す（加算）。
// UV.y＝建物の根元 0 → 手前 1。石の目地（暗い所）は映りにくく、石の上は映る。
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform vec4 col : source_color = vec4(1.0);
uniform float power = 1.0;
uniform sampler2D stone : filter_linear_mipmap, repeat_enable;
uniform float tile = 2.5;       // 下の石畳の 1 枚の大きさ（m）
uniform float z0 = -6.0;        // 筋の始まり（建物の根元）の奥行き
varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 本物の映り込みと同じく、光の真下からカメラの足元へ向かう線に沿わせる → 画面ではほぼ縦の筋になり、カメラが動くとずれる
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float f = clamp((w.z - z0) / max(0.1, cam.z - z0), 0.0, 1.0);
	float dx = (cam.x - MODEL_MATRIX[3].x) * f;
	VERTEX.x += dx;
	wpos = w + vec3(dx, 0.0, 0.0);
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = pow(across, 1.6);
	float along = smoothstep(0.0, 0.06, UV.y) * exp(-UV.y * 1.6);
	// 縦の揺らぎ（水たまりのムラ）
	float rip = 0.65 + 0.35 * sin(wpos.z * 7.0 + sin(wpos.x * 3.1) * 2.0);
	float lum = dot(texture(stone, wpos.xz / tile).rgb, vec3(0.333));
	float wet = smoothstep(0.10, 0.30, lum);
	ALBEDO = col.rgb * power * across * along * rip * (0.35 + 0.65 * wet);
}
