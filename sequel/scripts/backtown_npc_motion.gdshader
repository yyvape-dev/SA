shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 tint = vec4(1.0);
global uniform float bg_dim;

// Region center and soft radii in UV. The gesture is an offset plus a
// rotation around the joint in image space, keeping the approved sprite.
uniform vec4 region;
uniform vec2 joint;
uniform vec2 travel;
uniform float turn;
uniform float period = 3.0;
uniform float phase_offset;
uniform float sway;
uniform float aspect = 0.5;
const float GESTURE_MARGIN = 1.16;

void vertex() {
	VERTEX.xy *= GESTURE_MARGIN;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	float phase = fract(TIME / period + phase_offset);
	float gesture = smoothstep(0.12, 0.36, phase) * (1.0 - smoothstep(0.52, 0.84, phase));
	// Undo the padded quad scale in image space; the idle art stays the same size.
	vec2 uv = (UV - 0.5) * GESTURE_MARGIN + 0.5;
	float torso = sin(phase * TAU) * sway * (1.0 - smoothstep(0.34, 0.93, uv.y));
	uv.x -= torso;
	float weight = 1.0 - smoothstep(0.2, 1.0, length((uv - region.xy) / region.zw));
	vec2 units = vec2(aspect, 1.0);
	vec2 relative = (uv - joint) * units;
	float angle = -turn * gesture * weight;
	float c = cos(angle);
	float s = sin(angle);
	vec2 rotated = vec2(c * relative.x - s * relative.y, s * relative.x + c * relative.y);
	uv += (rotated - relative) / units - travel * gesture * weight;
	vec4 color = texture(tex, uv);
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	ALBEDO = color.rgb * tint.rgb * bg_dim;
	ALPHA = color.a * tint.a * inside.x * inside.y;
}
