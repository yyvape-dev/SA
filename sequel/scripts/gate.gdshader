shader_type spatial;
// ダンジョンの入口の光る扉：下ほど明るく、縦に流れる縞。加算。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(0.72, 0.5, 1.0, 1.0);

void fragment() {
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float y = UV.y;
	float bands = 0.75 + 0.25 * sin(y * 18.0 - TIME * 3.0);
	ALBEDO = col.rgb * (0.25 + 0.75 * UV.y) * bands * edge;
	ALPHA = 1.0;
}
