// 稲妻の線（2026-11-06）。元：alanfischer/overcast-godot の shaders/bolt.gdshader（MIT License, Copyright (c) 2026 Alan Fischer）。
// 点の列に沿った帯をカメラへ向け、真ん中を白く熱く、外へ柔らかい色のにじみ。NORMAL＝その点での稲妻の向き、UV.x＝帯の左右（-1／1）。
// 変えた所：色・明るさ・消え方をスクリプトから（fade）、にじみを広め、夜の街で沈まないよう芯を強めに。
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform vec3 color : source_color = vec3(0.31, 0.72, 1.0);
uniform float width = 0.16;       // 帯の幅（m）。芯はこの真ん中の細い所
uniform float brightness = 1.0;
uniform float fade = 1.0;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 along = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - p;
	vec3 side = normalize(cross(along, to_cam) + vec3(1e-5));
	// 細くなりすぎて消えないよう、画面で 2 画素より細くしない
	float pixel = length(to_cam) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	p += side * UV.x * max(width * 0.5, pixel * 2.0);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	float a = 1.0 - abs(UV.x);
	float core = smoothstep(0.72, 0.97, a);
	float glow = a * a;
	ALBEDO = (color * (glow * 0.9 + a * 0.25) + vec3(core) * 1.6) * brightness * fade;
}
