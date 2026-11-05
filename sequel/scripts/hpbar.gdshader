shader_type spatial;
// 敵の頭上の体力（赤＝敵）。常にカメラへ向け、ほかの物に隠れない。
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

uniform float ratio = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 px = UV;
	float border = step(px.x, 0.02) + step(0.98, px.x) + step(px.y, 0.12) + step(0.88, px.y);
	vec3 c = px.x < ratio ? vec3(0.92, 0.16, 0.18) : vec3(0.12, 0.05, 0.07);
	ALBEDO = border > 0.0 ? vec3(0.02) : c;
}
