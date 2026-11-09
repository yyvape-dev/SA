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
        // Source-registered cabinet remains stationary. Only the inset display
        // changes: two distinct scrolling symbol columns followed by a hold.
        // Rectangles are relative to the source-registered machine mask; this
        // is an interim screen-space effect pending source-pixel reel isolation.
        vec2 extent = max(region.zw - region.xy, vec2(0.00001));
        vec2 q = (uv - region.xy) / extent;
        float display_x = smoothstep(0.27, 0.30, q.x)
            * (1.0 - smoothstep(0.70, 0.73, q.x));
        float display_y = smoothstep(0.27, 0.30, q.y)
            * (1.0 - smoothstep(0.55, 0.58, q.y));
        float display_mask = display_x * display_y * inside;
        float spin = clamp(cycle / 4.7, 0.0, 1.0);
        float travel = spin * spin * (3.0 - 2.0 * spin);
        float first_column = 1.0 - smoothstep(0.49, 0.51, q.x);
        // Each column traverses an integer number of 0.28-wide source
        // bands before stopping, returning to the unmodified source UV.
        float offset = 0.28 * (3.0 + first_column) * travel;
        float reel_y = region.y + extent.y
            * (0.30 + mod(q.y - 0.30 + offset, 0.28));
        vec4 moving_symbols = texture(painted, vec2(uv.x, reel_y));
        // The last quarter of the 2-second cycle holds the original image.
        float active = 1.0 - smoothstep(4.55, 4.70, cycle);
        output_color = mix(original, moving_symbols, display_mask * active * 0.88);
        float jewel = exp(-90.0 * dot(q - vec2(0.5, 0.70), q - vec2(0.5, 0.70)));
        float pulse = pow(0.5 + 0.5 * sin(cycle * 5.0), 3.0);
        output_color.rgb += vec3(0.21, 0.08, 0.26) * jewel * pulse * inside;
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
