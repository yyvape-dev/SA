shader_type canvas_item;
// Full-resolution source-pixel deformation; no generated intermediate frames.
uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
void fragment() {
    vec2 uv = UV;
    float a = phase * 6.28318530718;
    float hair_w = (1.0 - smoothstep(0.28, 0.55, uv.x)) *
        smoothstep(0.16, 0.29, uv.y) * (1.0 - smoothstep(0.47, 0.53, uv.y));
    float torso_w = exp(-pow((uv.x - 0.52) / 0.25, 2.0)) *
        smoothstep(0.22, 0.35, uv.y) * (1.0 - smoothstep(0.50, 0.67, uv.y));
    float upper_w = 1.0 - smoothstep(0.48, 0.90, uv.y);
    float hand_w = exp(-pow((uv.x - 0.76) / 0.085, 2.0) -
        pow((uv.y - 0.429) / 0.080, 2.0));
    vec2 dpx = vec2(0.0);
    dpx.x += hair_w * (4.0 * sin(a) + 1.1 * sin(2.0 * a));
    dpx.y += upper_w * (-2.0 * sin(a));
    dpx.y += torso_w * (-1.4 * sin(a));
    dpx.x += hand_w * 2.0 * sin(a);
    dpx.y += hand_w * 1.5 * sin(a);
    vec2 src_uv = clamp(uv - dpx * TEXTURE_PIXEL_SIZE * strength,
        vec2(0.0), vec2(1.0));
    COLOR = texture(TEXTURE, src_uv);
}
