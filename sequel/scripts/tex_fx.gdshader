shader_type spatial;
// 絵を貼った板のエフェクト（2026-11-07、specs/vfx_overhaul.md の 3）。Kenney の粒の絵（形＝透明度、明るさ＝明暗）を使う。
// 2D の層（fx2d）は常に敵の手前に出るので、敵より奥・足元に出るべき効果（床の渦・割れ目の焦げ・撃破の煙と焦げ跡）はこちら。
// 加算（光）と普通の合成（煙・焦げ）を1つの式で：blend_premul_alpha、加算は a=0。
// floor_mode：1＝床に寝かせる（板は FACE_Y で作る）、0＝カメラへ向く（縦の板）。spin＝絵の回転（ラジアン）。
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 col : source_color = vec4(1.0);
uniform float raw = 1.0;          // 光らせる倍率（1 を超えると 3D の glow の閾値を越える）
uniform float additive = 1.0;     // 1＝加算、0＝普通の合成
uniform float spin = 0.0;
uniform float alpha = 1.0;        // 全体の濃さ（時間で変える）
uniform float floor_mode = 0.0;
// 2026-11-07（F）：vfx_sprite.gdshader と同じ「侵食＋グラデーションマップ」。life＝寿命の進み（スクリプトが入れる）
uniform sampler2D grad : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float life = 0.0;
uniform float cool = 0.35;
uniform float erode_from = 0.3;
uniform float erode_soft = 0.12;
uniform float noise_amt = 0.45;
uniform float seed = 0.0;
global uniform float bg_dim;

void vertex() {
	if (floor_mode < 0.5) {   // 縦の板：Godot の BILLBOARD_FIXED_Y と同じ
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)) * length(MODEL_MATRIX[0].xyz), 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 c = UV - 0.5;
	float cs = cos(spin);
	float sn = sin(spin);
	vec2 uv = vec2(cs * c.x - sn * c.y, sn * c.x + cs * c.y) + 0.5;
	vec4 t = texture(tex, uv);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float lum = max(t.r, max(t.g, t.b));
	float n = texture(noise_tex, uv * 1.6 + vec2(seed * 0.37, seed * 0.71) + vec2(TIME * 0.05, -TIME * 0.08)).r;
	float val = lum * (1.0 - noise_amt) + n * noise_amt;
	float th = clamp((life - erode_from) / max(1.0 - erode_from, 0.001), 0.0, 1.0);
	float keep = smoothstep(th - erode_soft, th + erode_soft, val);   // 芯ほど遅くまで残る
	vec4 g = texture(grad, vec2(clamp(1.0 - lum + life * cool, 0.0, 1.0), 0.5));
	float m = t.a * (0.35 + 0.65 * lum) * inside * keep * g.a * alpha * col.a;
	vec3 rgb = g.rgb * col.rgb * raw;
	ALBEDO = rgb * m;
	ALPHA = m * (1.0 - additive);
}
