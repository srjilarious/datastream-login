// Screen-space hex rain drawn over the city. Each column of character cells
// has its own speed and phase; glyphs stay in place and flicker while a
// bright head sweeps down and leaves a fading trail. Output is premultiplied.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float density;  // share of columns that carry a stream, 0..1
    vec2 res;       // item size in pixels
    float cellPx;   // character cell width in pixels
    vec4 rainTint;
    vec4 headTint;
};

const float FONT[16] = float[16](
    31599.0, 11415.0, 29671.0, 29647.0, 23497.0, 31183.0, 31215.0, 29266.0,
    31727.0, 31695.0, 11245.0, 27566.0, 14627.0, 27502.0, 31207.0, 31204.0);

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// cl in [0,1)^2 with y down; 4x6 dot grid, glyph in the top-left 3x5.
// Dots are drawn as slightly rounded squares for an LED look.
float glyph(vec2 cl, float id) {
    vec2 d = floor(cl * vec2(4.0, 6.0));
    if (d.x > 2.0 || d.y > 4.0) return 0.0;
    float bit = (4.0 - d.y) * 3.0 + (2.0 - d.x);
    float v = FONT[int(mod(id, 16.0))];
    float on = floor(mod(v / exp2(bit), 2.0));
    vec2 inDot = abs(fract(cl * vec2(4.0, 6.0)) - 0.5);
    return on * smoothstep(0.5, 0.38, max(inDot.x, inDot.y));
}

void main() {
    vec2 px = qt_TexCoord0 * res;
    vec2 cellSize = vec2(cellPx, cellPx * 1.5);
    vec2 c = floor(px / cellSize);
    vec2 cl = fract(px / cellSize);

    float cs = hash12(vec2(c.x, 7.0));
    if (cs > density) {
        fragColor = vec4(0.0);
        return;
    }
    // Spread the active columns' speeds evenly no matter the density.
    float k = cs / max(density, 1e-3);
    float speed = 0.25 + k * 0.9;
    float rows = res.y / cellSize.y;
    // b grows down the column from the head, so the head is where b wraps.
    float b = fract(-c.y / (rows * 0.55) + time * speed * 0.35 + k * 13.0);
    float trail = pow(b, 7.0);
    float headAmt = smoothstep(0.975, 1.0, b);
    float id = floor(hash13(vec3(c, floor(time * (3.0 + k * 9.0) + k * 31.0))) * 16.0);
    float g = glyph(cl, id);

    vec3 col = rainTint.rgb * trail + headTint.rgb * headAmt;
    float a = g * clamp(trail * 1.2 + headAmt, 0.0, 1.0);
    fragColor = vec4(col * g, a) * qt_Opacity;
}
