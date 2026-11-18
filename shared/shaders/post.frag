// Full-screen CRT pass over the whole scene: chromatic split, glitch band
// displacement, scanlines, a slow rolling bar, grain and vignette. glitch is
// 0 normally and spikes to 1 on a failed login or the idle glitch timer.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float glitch;
    float flash;
    float scan;      // scanline strength 0..1
    vec2 res;
    vec4 flashColor;
};

layout(binding = 1) uniform sampler2D source;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float g = clamp(glitch, 0.0, 1.0);

    // Horizontal bands jump sideways while glitching, re-rolled 24x a second.
    float tq = floor(time * 24.0);
    float band = floor(uv.y * mix(14.0, 48.0, hash12(vec2(tq, 1.0))));
    float pick = step(1.0 - g * 0.7, hash12(vec2(band, tq + 3.0)));
    uv.x += (hash12(vec2(band, tq)) - 0.5) * 0.12 * g * pick;
    // A thin tearing line that wanders even when calm.
    float tear = smoothstep(0.004, 0.0, abs(uv.y - fract(time * 0.031)));
    uv.x += tear * 0.004;

    float ca = 0.0012 + 0.014 * g + pick * g * 0.01;
    vec3 c;
    c.r = texture(source, uv + vec2(ca, 0.0)).r;
    c.g = texture(source, uv).g;
    c.b = texture(source, uv - vec2(ca, 0.0)).b;

    float sl = 0.5 + 0.5 * sin(qt_TexCoord0.y * res.y * 3.14159265);
    c *= mix(1.0, 0.78 + 0.22 * sl, scan);
    float roll = smoothstep(0.0, 0.1, abs(fract(qt_TexCoord0.y - time * 0.06) - 0.5));
    c *= 0.95 + 0.05 * roll;

    vec2 q = qt_TexCoord0 - 0.5;
    c *= 1.0 - dot(q, q) * 0.85;
    c += (hash12(qt_TexCoord0 * res + fract(time) * 977.0) - 0.5) * (0.035 + g * 0.08);
    c += flashColor.rgb * flash;

    fragColor = vec4(c, 1.0) * qt_Opacity;
}
