shader_type canvas_item;
// 焼く専用（tools/bake_ranka_finale.gd）。ゲームでは使わない（iPhone の Safari で自前のシェーダーが動かないことがあるため、焼いた絵をめくるだけにする）。
// 白黒の素材（RGB＝明るさ、A＝形）に：中心から外へ現れる（reveal）・外と暗い所から侵食で消える（life）・明るさ→色の帯（grad、寿命で冷める）・HDR の倍率（gain）。
render_mode blend_add;
uniform sampler2D grad : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float life = 0.0;         // 0→1
uniform float erode_from = 0.2;   // この進みから侵食を始める
uniform float erode_soft = 0.12;
uniform float reveal = 1.0;       // 0→1：中心からの半径（UV の中心から角まで＝1）で現れる
uniform float reveal_soft = 0.18;
uniform float cool = 0.45;        // 寿命で色の帯を暗い側へ
uniform float gain = 1.0;
uniform float noise_amt = 0.4;
uniform float seed = 0.0;
uniform float alpha = 1.0;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = max(t.r, max(t.g, t.b));
	float r = length(UV - 0.5) / 0.7071;
	float rev = 1.0 - smoothstep(reveal - reveal_soft, reveal, r);
	float n = texture(noise_tex, UV * 2.3 + vec2(seed * 0.37, seed * 0.71)).r;
	float val = lum * (1.0 - noise_amt) + n * noise_amt - r * 0.25;   // 外ほど先に消える
	float th = clamp((life - erode_from) / max(1.0 - erode_from, 0.001), 0.0, 1.0);
	float keep = smoothstep(th - erode_soft, th + erode_soft, val);
	vec4 g = texture(grad, vec2(clamp(1.0 - lum + life * cool, 0.0, 1.0), 0.5));
	float m = t.a * rev * keep * g.a * alpha;
	COLOR = vec4(g.rgb * gain * m, 1.0);
}
