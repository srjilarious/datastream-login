// Liquid plasma behind the acidburn emblem: domain-warped noise folded
// into marble bands, deep blue with pale highlights, black veins and thin
// iridescent streaks. `flow` is integrated on the QML side so the speed
// can change (typing speeds it up) without the pattern jumping. Near the
// pointer the domain is twisted into a whirlpool whose strength is `swirl`.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float flow;      // integrated flow distance
    float aspect;    // width / height
    vec2 pointer;    // pointer position, 0..1 texture coordinates
    float swirl;     // 0..1 whirlpool strength at the pointer
    vec4 deep;       // darkest base
    vec4 mid;        // main body color
    vec4 light;      // band highlights
    vec4 sheen;      // thin iridescent streak
    vec4 streak;     // second, rarer streak color
};

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    const mat2 rot = mat2(0.8, 0.6, -0.6, 0.8);
    float sum = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        sum += amp * noise(p);
        p = rot * p * 2.03 + vec2(1.7, 9.2);
        amp *= 0.5;
    }
    return sum;
}

vec2 rotate(vec2 v, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void main() {
    vec2 p = vec2((qt_TexCoord0.x - 0.5) * aspect, qt_TexCoord0.y - 0.5) * 2.0;

    // Whirlpool around the pointer, strongest at its center.
    vec2 pp = vec2((pointer.x - 0.5) * aspect, pointer.y - 0.5) * 2.0;
    vec2 d = p - pp;
    p = pp + rotate(d, swirl * 3.2 * exp(-dot(d, d) * 2.5));

    // The marble in the film is stretched sideways.
    p *= vec2(0.42, 0.95);
    float t = flow;

    vec2 q = vec2(fbm(p + vec2(0.0, t * 0.11)),
                  fbm(p + vec2(5.2, 1.3) - vec2(t * 0.09, 0.0)));
    vec2 r = vec2(fbm(p + 3.6 * q + vec2(1.7, 9.2) + vec2(t * 0.14, 0.0)),
                  fbm(p + 3.6 * q + vec2(8.3, 2.8) - vec2(0.0, t * 0.12)));
    float f = fbm(p + 3.2 * r + vec2(0.0, t * 0.05));

    // Fold the field into bands: soft body, sharp highlights, black veins.
    float bands = 0.5 + 0.5 * sin(f * 13.0 + r.x * 5.0 - t * 0.35);
    float body = smoothstep(0.25, 0.75, f + 0.35 * (q.y - 0.5));
    vec3 col = mix(deep.rgb, mid.rgb, body);
    col = mix(col, light.rgb, pow(bands, 10.0) * 0.8);
    col *= 0.35 + 0.65 * smoothstep(0.0, 0.22, bands);
    float veins = 0.5 + 0.5 * sin(r.y * 22.0 + f * 6.0 + t * 0.2);
    col *= 0.25 + 0.75 * smoothstep(0.02, 0.18, veins);

    // Thin oil-slick streaks along the band edges.
    float edge = 1.0 - smoothstep(0.0, 0.05, abs(bands - 0.42));
    col = mix(col, sheen.rgb, edge * smoothstep(0.55, 0.72, q.x) * 0.75);
    float edge2 = 1.0 - smoothstep(0.0, 0.04, abs(veins - 0.3));
    col = mix(col, streak.rgb, edge2 * smoothstep(0.62, 0.78, r.x) * 0.6);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
