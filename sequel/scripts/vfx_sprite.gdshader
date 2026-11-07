shader_type canvas_item;
// エフェクトの素材の共通シェーダー（2026-11-07、specs/vfx_overhaul.md の F）。「置いて薄くするだけ」をやめる。
// 素材は白黒（明るさ＝芯、透明度＝形）。色はここで付ける。2D の層（fx2d、黒地に加算）で使うので blend_add。
//   1) アルファ侵食：寿命 p でしきい値を上げ、smoothstep で縁を柔らかく食う。明るさ（芯ほど残る）×ゆっくり流れるノイズで、毎回崩れ方が変わる。
//   2) グラデーションマップ：明るさ → 色の帯（小さい GradientTexture1D、左＝芯の白 → 右＝外の暗い色）。寿命で帯を暗い側へずらす（冷める）。
//   3) 大きさ：出は 2〜3 コマで 0→1.15（ease-out）、そのあとゆっくり（スクリプト・粒子の曲線）。速い物は進む向きに伸ばす（stretch）。
//   4) 弧のマスク（arc=1）：三日月を丸ごと出さず、弧に沿って先端が走り、尾から侵食で消える。
// 寿命 p：粒子は INSTANCE_CUSTOM.y（particles=1）、単発は life（スクリプトが毎コマ入れる）。
// iPhone（Safari）で動かない書き方を避ける（事実：REEBO の自前シェーダーは iPhone で白い四角になった。原因は特定できていない）：
//   fwidth・pow の負の底・原点での atan・ループ・bool の uniform・#include を使わない。iPhone の実機では未確認。
render_mode blend_add, unshaded;

uniform sampler2D grad : source_color, filter_linear, repeat_disable;   // 色の帯
uniform sampler2D noise_tex : filter_linear, repeat_enable;             // 流れるノイズ（fx.noise_tex）
uniform float particles = 0.0;      // 1＝粒子（寿命は INSTANCE_CUSTOM.y）
uniform float life = 0.0;           // 単発の寿命の進み 0→1
uniform float raw = 1.3;            // 明るさの倍率（芯を 1 より上に＝glow）
uniform float cool = 0.35;          // 寿命で帯を暗い側へずらす量
uniform float erode_from = 0.25;    // この進みから侵食を始める
uniform float erode_soft = 0.12;    // 侵食の縁の柔らかさ
uniform float noise_amt = 0.45;     // 侵食に混ぜるノイズの量
uniform float noise_scale = 1.6;
uniform float seed = 0.0;
uniform float stretch = 0.0;        // 速い物を進む向き（絵の縦）に伸ばす量（出の速い時ほど長い）
uniform float arc = 0.0;            // 1＝弧のマスク（三日月）
uniform float arc_a0 = 0.157;       // 弧の始まりと終わり（ラジアン、絵の中心から見た角度。slash_02＝9°〜171°）
uniform float arc_a1 = 2.985;
uniform float alpha = 1.0;

varying float v_p;
varying float v_seed;

void vertex() {
	v_p = mix(life, INSTANCE_CUSTOM.y, particles);
	v_seed = seed + INSTANCE_CUSTOM.x * 3.7 * particles;
	float sp = max(1.0 - v_p, 0.0);
	VERTEX.y *= 1.0 + stretch * sp * sp;   // 出の速い時ほど伸び、減速で丸く戻る
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = max(t.r, max(t.g, t.b));
	float p = clamp(v_p, 0.0, 1.0);
	float shape = t.a * (0.35 + 0.65 * lum);
	// 4) 弧のマスク：絵の中心から見た角度を、弧の始まり 0 → 終わり 1 に直す。先端（head）は出だしで走り切り、尾（tail）は後半に追いかけて消す
	if (arc > 0.5) {
		vec2 c = UV - 0.5;
		float r2 = dot(c, c);
		float ang = atan(c.y, c.x + 0.00001);   // 原点での atan(0,0) を避ける
		float s = clamp((ang - arc_a0) / (arc_a1 - arc_a0), 0.0, 1.0);
		float k = clamp(p / 0.35, 0.0, 1.0);
		float head = 0.25 + 0.75 * (1.0 - (1.0 - k) * (1.0 - k));   // 最初のコマから弧の 1/4 は見せる
		float tail = clamp((p - 0.3) / 0.7, 0.0, 1.0);
		float m = smoothstep(head + 0.02, head - 0.06, s) * smoothstep(tail - 0.02, tail + 0.12, s);
		float hot = smoothstep(head - 0.18, head, s) * (1.0 - tail);   // 先端は白く熱い
		shape *= m;
		lum = min(1.0, lum + hot * 0.5);
	}
	// 1) アルファ侵食：芯（明るい所）ほど遅くまで残る。ノイズはゆっくり流れ、粒ごとに違う
	float n = texture(noise_tex, UV * noise_scale + vec2(v_seed * 0.37, v_seed * 0.71) + vec2(TIME * 0.05, -TIME * 0.08)).r;
	float val = lum * (1.0 - noise_amt) + n * noise_amt;
	float th = clamp((p - erode_from) / max(1.0 - erode_from, 0.001), 0.0, 1.0);
	float keep = smoothstep(th - erode_soft, th + erode_soft, val);
	// 2) グラデーションマップ：芯（明るい）＝帯の左、外（暗い）＝右。寿命で右へ（冷める）
	float u = clamp(1.0 - lum + p * cool, 0.0, 1.0);
	vec4 g = texture(grad, vec2(u, 0.5));
	float a = shape * keep * g.a * alpha * COLOR.a;
	COLOR = vec4(g.rgb * raw * COLOR.rgb, a);   // blend_add は色×a を足す
}
