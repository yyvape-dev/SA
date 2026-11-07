shader_type canvas_item;
// 粒子の混ぜ撒き（2026-11-07、specs/vfx_recipes.md）。burst2d.gd の GPUParticles2D／CPUParticles2D に付ける。
// シートは 4×4（assets/fx/burst_sheet.png）：明るさ＝芯（白く残す）、透明度＝形。色は粒ごと（COLOR＝金・紅・桃・シアンのどれか）。
// 加算と普通の重ねを1つの式で：blend_premul_alpha で、加算は a=0 を出す（result = src.rgb + dst × (1 − a)）。
render_mode blend_premul_alpha;
uniform int h_frames = 4;
uniform int v_frames = 4;
uniform float additive : hint_range(0.0, 1.0) = 1.0;   // 1＝加算（光の粒）、0＝普通の重ね（花びら）
uniform float flutter : hint_range(0.0, 1.0) = 0.0;    // 花びら：横幅の伸縮（裏返る感じ）
uniform float core : hint_range(0.0, 1.0) = 1.0;       // 芯の白さ
uniform float hdr = 1.0;                               // 明るさの倍率（glow の確認用）

void vertex() {
	float hf = float(h_frames);
	float vf = float(v_frames);
	// 花びら：粒ごとに位相をずらして横幅を伸び縮み（INSTANCE_CUSTOM.x＝出たときの角度を種に使う）
	float fl = abs(sin(TIME * 7.0 + INSTANCE_CUSTOM.x * 5.3 + INSTANCE_CUSTOM.y * 3.0));
	VERTEX.x *= mix(1.0, 0.15 + 0.85 * fl, flutter);
	// 4×4 のどのマスか：INSTANCE_CUSTOM.z（anim_offset をランダムにして選ぶ。CanvasItemMaterial の particles_anim と同じ計算）
	VERTEX.xy /= vec2(hf, vf);
	float total = hf * vf;
	float frame = clamp(floor(INSTANCE_CUSTOM.z * total), 0.0, total - 1.0);
	UV /= vec2(hf, vf);
	UV += vec2(mod(frame, hf) / hf, floor((frame + 0.5) / hf) / vf);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float a = t.a * COLOR.a;
	vec3 c = mix(COLOR.rgb, vec3(1.0), smoothstep(0.55, 0.95, t.r) * core) * hdr;
	COLOR = vec4(c * a, a * (1.0 - additive));
}
