shader_type canvas_item;
// 画面の仕上げ（UI より下の CanvasLayer）：暗い所を青紫へ寄せ（明るい所の暖色・ネオン色は残す）、四隅を少し暗くする。
// 2026-11-06：衝撃波の画面のゆがみ（最大4つ同時）。画面を読むのはこの1回だけ（別の層で読むと仕上げが上書きされる）。
//   元：GDQuest godot-shaders の shockwave（輪のマスクで UV をずらす、MIT）＋ godotshaders.com の Distortion（色ずれ）。
//   wave[i] = (中心 x, 中心 y〈画面 UV〉, 半径〈画面の高さに対する割合〉, 強さ)。強さ 0 で無効。fx.gd の shockwave() が毎コマ入れる。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.38;
uniform float grade = 1.0;
uniform vec4 wave[4];
uniform float wave_w = 0.06;      // 輪の太さ（画面の高さに対する割合）
uniform float aspect = 2.164;     // 画面の横÷縦（スクリプトが入れる）
// 2026-11-07（specs/vfx_recipes.md）：ダメージの周辺の赤（dmg＝被弾の瞬間、low＝体力が少ない間の脈打ち）と、画面全体の色収差（ca、中心から外へ）
uniform float dmg = 0.0;
uniform float low = 0.0;
uniform float ca = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ofs = vec2(0.0);
	float ab = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 w = wave[i];
		if (w.w <= 0.0) continue;
		vec2 d = (SCREEN_UV - w.xy) * vec2(aspect, 1.0);
		float r = length(d);
		float band = 1.0 - smoothstep(0.0, wave_w, abs(r - w.z));   // 輪の上だけ
		float push = band * w.w * (r < w.z ? -1.0 : 1.0) * 0.5 + band * w.w * 0.5;
		vec2 dir = r > 0.0001 ? d / r : vec2(0.0);
		ofs += dir * vec2(1.0 / aspect, 1.0) * push * 0.035;
		ab += band * w.w;
	}
	uv += ofs;
	vec3 c;
	if (ab > 0.001) {   // 輪の上だけ色をずらす（赤と青を外と内へ）
		vec2 cs = ofs * 0.22;   // 色ずれは控えめ（強いと虹色に見えて安っぽい）
		c = vec3(texture(screen_tex, uv + cs).r, texture(screen_tex, uv).g, texture(screen_tex, uv - cs).b);
		c += vec3(0.7, 0.85, 1.0) * min(ab, 1.0) * 0.05;   // 輪がうっすら光る（青白＝味方の技）
	} else if (ca > 0.001) {   // 中心から外へ、端ほど大きくずらす（中央はほぼずれない）
		vec2 dc = (SCREEN_UV - 0.5);
		vec2 co = dc * length(dc * vec2(aspect, 1.0)) * ca * 0.018;
		c = vec3(texture(screen_tex, uv + co).r, texture(screen_tex, uv).g, texture(screen_tex, uv - co).b);
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float shadow = 1.0 - smoothstep(0.12, 0.55, lum);
	vec3 cool = c * vec3(0.82, 0.84, 1.18) + vec3(0.012, 0.004, 0.03);
	c = mix(c, cool, shadow * grade);
	vec2 dd = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.45, 1.05, length(dd)) * strength;
	c = mix(c, vec3(0.03, 0.02, 0.06), v);
	float dr = max(dmg, low);
	if (dr > 0.001) {   // 周辺だけ暗い赤へ（中央は残す。赤＝敵の色＝痛い）
		float ring = smoothstep(0.38, 1.0, length(dd));
		c = mix(c, c * vec3(0.55, 0.12, 0.14) + vec3(0.32, 0.0, 0.03), ring * dr);
	}
	COLOR = vec4(c, 1.0);
}
