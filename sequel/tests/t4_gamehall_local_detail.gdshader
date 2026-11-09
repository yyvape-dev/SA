shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

// T4 source-registered paintings: only INSIDE the declared region can move.
// The structure, table, seat positions and slot cabinets never translate.
uniform sampler2D painted : source_color, filter_linear_mipmap;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0); // x0,y0,x1,y1
uniform float cycle = 0.0;
uniform int motion_kind = 0; // 1=reel symbols, 2=roulette wheel, 3=head/upper torso

void fragment() {
    vec2 uv = UV;
    vec4 original = texture(painted, uv);
    vec4 output_color = original;
    float in_x = smoothstep(region.x, region.x + 0.0015, uv.x)
        * (1.0 - smoothstep(region.z - 0.0015, region.z, uv.x));
    float in_y = smoothstep(region.y, region.y + 0.0015, uv.y)
        * (1.0 - smoothstep(region.w - 0.0015, region.w, uv.y));
    float inside = in_x * in_y;

    if (motion_kind == 1) {
        // Keep every reel-symbol cell and cabinet fixed.  The previous wrap
        // sampling created a visible horizontal seam; reject large UV shifts.
        // Apply subpixel drift only inside the screen plus a traveling glint.
        float h = region.w - region.y;
        float shift_y = 0.00040 * sin(cycle * 2.0);
        vec4 shifted = texture(painted, vec2(uv.x, uv.y + shift_y * inside));
        output_color = mix(original, shifted, inside * 0.75);
        float local_y = (uv.y - region.y) / h;
        float glint = exp(-85.0 * pow(local_y - (0.5 + 0.32 * sin(cycle)), 2.0));
        output_color.rgb *= 1.0 + 0.13 * inside * glint;
    } else if (motion_kind == 2) {
        // Rotate ONLY the tiny wheel interior; felt/table/dealer/chairs stay put.
        vec2 center = (region.xy + region.zw) * 0.5;
        vec2 radii = (region.zw - region.xy) * 0.5;
        vec2 local = (uv - center) / radii;
        float dist = length(local);
        float wheel_mask = 1.0 - smoothstep(0.70, 0.98, dist);
        float co = cos(cycle);
        float si = sin(cycle);
        vec2 spun = vec2(co * local.x - si * local.y, si * local.x + co * local.y);
        vec4 wheel = texture(painted, center + radii * spun);
        output_color = mix(original, wheel, wheel_mask);
    } else if (motion_kind == 3) {
        // Subpixel head movement fades to zero at torso/feet, preventing foot sliding.
        float t = clamp((uv.y - region.y) / max(region.w - region.y, 0.0001), 0.0, 1.0);
        float upper = inside * (1.0 - smoothstep(0.14, 0.88, t));
        vec2 moved_uv = uv + vec2(0.00060 * sin(cycle), 0.00042 * sin(cycle + 0.5)) * upper;
        vec4 moved = texture(painted, moved_uv);
        output_color = mix(original, moved, upper);
    }
    ALBEDO = output_color.rgb;
    ALPHA = output_color.a;
}
