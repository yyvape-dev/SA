shader_type spatial;
// 斬撃・光の下に敷く暗い下地（通常の合成）。明るい背景でも青い光が沈まないようにする（前作 VFX_ATK.dark と同じ考え）。
//  0 = 斬撃の帯（fx_add と同じ head・tail）  1 = 丸い影
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform int mode = 0;
uniform vec4 col_dark : source_color = vec4(0.03, 0.06, 0.19, 1.0);
uniform float head = 1.0;
uniform float fade = 1.0;
uniform float tail = 3.5;
uniform float strength = 0.45;
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	float a = 0.0;
	if (mode == 0) {
		float behind = head - UV.x;
		a = behind < 0.0 ? 0.0 : exp(-behind * tail * 0.8);
		a *= sin(3.14159 * clamp(UV.y, 0.0, 1.0)) * 0.6 + (1.0 - UV.y) * 0.4;
	} else {
		float r = length(UV - vec2(0.5)) * 2.0;
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.5);
	}
	ALBEDO = col_dark.rgb;
	ALPHA = clamp(a * strength * fade, 0.0, 1.0);
}
