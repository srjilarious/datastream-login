// Neon data city: the camera flies down an avenue of towers whose walls are
// covered in streaming hex. The scene is a 2D grid raycast (DDA over the xz
// cells) with one box per non-street cell, so the cost is bounded by
// MAX_CELLS no matter how far the camera has travelled.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds since start, drives glyph flicker and sway
    float travel;  // distance flown along the avenue, integrated from speed in QML
    float aspect;  // width / height
    float climb;   // 0 = street level, 1 = above the rooftops
    vec4 tintA;
    vec4 tintB;
    vec4 tintC;
    vec4 groundTint;
};

const int MAX_CELLS = 80;
const float MAX_DIST = 48.0;
const float AVENUE = 5.0; // every 5th column of cells along x is a street
const float CROSS = 7.0;  // every 7th row of cells along z is a cross street
const float INSET = 0.12; // sidewalk margin between a building and its cell edge

// 3x5 hex digit bitmaps 0-F, row 0 at the top, bit 14 = top-left dot.
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

// One character cell: cl in [0,1)^2 with y up. The glyph uses a 4x6 dot
// grid so there is one dot of spacing to the right and below.
float glyph(vec2 cl, float id) {
    vec2 d = floor(cl * vec2(4.0, 6.0));
    if (d.x > 2.0 || d.y < 1.0) return 0.0;
    float row = 5.0 - d.y;          // 0 at the top
    float bit = (4.0 - row) * 3.0 + (2.0 - d.x);
    float v = FONT[int(mod(id, 16.0))];
    return floor(mod(v / exp2(bit), 2.0));
}

bool isStreet(vec2 c) {
    return mod(c.x, AVENUE) == 0.0 || mod(c.y, CROSS) == 0.0;
}

float buildingHeight(vec2 c) {
    float h = hash12(c * 1.37 + 4.1);
    return 0.5 + h * h * 3.2 + step(0.93, hash12(c + 17.0)) * 2.5;
}

vec3 buildingTint(vec2 c) {
    float k = hash12(c + 91.7);
    return k < 0.45 ? tintA.rgb : (k < 0.8 ? tintB.rgb : tintC.rgb);
}

// Text on a wall. u runs along the wall from its left edge, y is height.
// Returns x = glyph lit amount, y = bright "head" amount for the rain mode.
vec2 wallText(float u, float y, vec2 cell, float face, float dist) {
    const float CW = 1.0 / 24.0;
    const float CH = CW * 1.5;
    float seed = hash12(cell * 3.1 + face * 11.0);
    float lit = 0.0;
    float head = 0.0;
    float col = floor(u / CW);
    float cx = fract(u / CW);

    if (seed < 0.55) {
        // Falling streams: the glyphs stay put and a bright head runs down.
        float row = floor(y / CH);
        float cy = fract(y / CH);
        float cs = hash13(vec3(col, cell));
        if (cs > 0.35) {
            float speed = 0.6 + cs * 1.4;
            float b = fract(row * 0.045 + time * speed * 0.35 + cs * 7.0);
            float trail = pow(b, 5.0);
            float id = floor(hash13(vec3(col, row, floor(time * (2.0 + cs * 6.0) + cs * 9.0))) * 16.0);
            float g = glyph(vec2(cx, cy), id);
            lit = g * trail;
            head = g * smoothstep(0.96, 1.0, b);
        }
    } else {
        // Scrolling readout lines, like a hex dump ticking sideways.
        float row = floor(y / CH);
        float cy = fract(y / CH);
        float rs = hash12(vec2(row, seed * 50.0));
        if (rs > 0.35) {
            float dir = rs > 0.7 ? -1.0 : 1.0;
            float uu = u + time * (0.08 + rs * 0.25) * dir;
            float c = floor(uu / CW);
            float word = hash12(vec2(floor(c / 5.0), row + seed * 13.0));
            float on = step(0.3, word) * step(0.12, hash12(vec2(c, row)));
            float id = floor(hash13(vec3(c, row, seed)) * 16.0);
            lit = on * glyph(vec2(fract(uu / CW), cy), id) * 0.75;
        }
    }
    // Far away the dots are smaller than a pixel and would shimmer, so fade
    // towards their average brightness.
    float near = clamp(1.0 - (dist - 3.0) / 9.0, 0.0, 1.0);
    lit = mix(0.12, lit, near);
    head *= near;
    return vec2(lit, head);
}

vec3 sky(vec3 rd) {
    float h = clamp(rd.y, -0.2, 1.0);
    vec3 top = vec3(0.005, 0.0, 0.02);
    vec3 horizon = mix(groundTint.rgb, tintB.rgb, 0.4) * 0.35;
    return mix(horizon, top, smoothstep(-0.02, 0.35, h));
}

void main() {
    vec2 p = vec2(qt_TexCoord0.x * 2.0 - 1.0, 1.0 - qt_TexCoord0.y * 2.0);
    p.x *= aspect;

    float t = time;
    float lift = smoothstep(0.0, 1.0, climb);
    vec3 ro = vec3(0.5 + 0.22 * sin(t * 0.21), 0.32 + 0.05 * sin(t * 0.7) + lift * 3.6, travel);
    float yaw = 0.28 * sin(t * 0.093) + 0.12 * sin(t * 0.31);
    float pitch = -0.06 - lift * 0.42 + 0.04 * sin(t * 0.17);
    float roll = 0.07 * sin(t * 0.23);

    vec2 pr = vec2(p.x * cos(roll) - p.y * sin(roll), p.x * sin(roll) + p.y * cos(roll));
    vec3 rd = normalize(vec3(pr, 1.5));
    rd.yz = vec2(rd.y * cos(pitch) + rd.z * sin(pitch), -rd.y * sin(pitch) + rd.z * cos(pitch));
    rd.xz = vec2(rd.x * cos(yaw) + rd.z * sin(yaw), -rd.x * sin(yaw) + rd.z * cos(yaw));
    rd.xz += vec2(1e-5);

    vec2 cell = floor(ro.xz);
    vec2 stepv = sign(rd.xz);
    vec2 tDelta = abs(1.0 / rd.xz);
    vec2 tMax = (stepv * (cell - ro.xz) + max(stepv, 0.0)) * tDelta;
    float tGround = rd.y < 0.0 ? -ro.y / rd.y : 1e9;

    bool hit = false;
    float tHit = MAX_DIST;
    vec3 nHit = vec3(0.0);
    vec2 cellHit = vec2(0.0);
    vec3 bminHit = vec3(0.0);
    vec3 bmaxHit = vec3(0.0);
    vec3 inv = 1.0 / rd;

    for (int i = 0; i < MAX_CELLS; i++) {
        if (!isStreet(cell)) {
            float h = buildingHeight(cell);
            vec3 bmin = vec3(cell.x + INSET, 0.0, cell.y + INSET);
            vec3 bmax = vec3(cell.x + 1.0 - INSET, h, cell.y + 1.0 - INSET);
            vec3 t0 = (bmin - ro) * inv;
            vec3 t1 = (bmax - ro) * inv;
            vec3 tn3 = min(t0, t1);
            vec3 tf3 = max(t0, t1);
            float tn = max(max(tn3.x, tn3.y), tn3.z);
            float tf = min(min(tf3.x, tf3.y), tf3.z);
            if (tf > max(tn, 0.0) && tn < tGround) {
                hit = true;
                tHit = tn;
                nHit = tn == tn3.x ? vec3(-stepv.x, 0.0, 0.0)
                     : (tn == tn3.y ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, -stepv.y));
                cellHit = cell;
                bminHit = bmin;
                bmaxHit = bmax;
                break;
            }
        }
        float tNext = min(tMax.x, tMax.y);
        if (tGround < tNext || tNext > MAX_DIST) break;
        // Above every possible roof and still climbing: nothing more to hit.
        if (rd.y > 0.0 && ro.y + rd.y * tNext > 6.5) break;
        if (tMax.x < tMax.y) {
            cell.x += stepv.x;
            tMax.x += tDelta.x;
        } else {
            cell.y += stepv.y;
            tMax.y += tDelta.y;
        }
    }

    vec3 col;
    float dist;
    if (hit) {
        dist = tHit;
        vec3 pos = ro + rd * tHit;
        vec3 tint = buildingTint(cellHit);
        if (nHit.y > 0.5) {
            // Roof: dark with a faint grid and a hot rim.
            vec2 q = pos.xz - bminHit.xz;
            vec2 e = min(q, (bmaxHit.xz - bminHit.xz) - q);
            float rim = min(e.x, e.y);
            vec2 g = abs(fract(q * 6.0) - 0.5);
            float grid = smoothstep(0.46, 0.5, max(g.x, g.y));
            col = vec3(0.01, 0.012, 0.025) + tint * (grid * 0.12 + smoothstep(0.025, 0.0, rim) * 1.4
                  + exp(-rim * 30.0) * 0.35);
        } else {
            float face;
            float u;
            float uLen;
            if (abs(nHit.x) > 0.5) {
                u = pos.z - bminHit.z;
                uLen = bmaxHit.z - bminHit.z;
                face = nHit.x > 0.0 ? 1.0 : 2.0;
            } else {
                u = pos.x - bminHit.x;
                uLen = bmaxHit.x - bminHit.x;
                face = nHit.z > 0.0 ? 3.0 : 4.0;
            }
            vec2 txt = wallText(u, pos.y, cellHit, face, dist);
            float edge = min(min(u, uLen - u), bmaxHit.y - pos.y);
            float rim = smoothstep(0.02, 0.0, edge) * 1.3 + exp(-edge * 22.0) * 0.3;
            float floors = smoothstep(0.47, 0.5, abs(fract(pos.y * 4.0) - 0.5)) * 0.06;
            float side = abs(nHit.x) > 0.5 ? 0.8 : 1.0; // cheap two-tone shading
            col = vec3(0.008, 0.01, 0.022) + tint * (txt.x * 0.95 * side + rim + floors) + vec3(txt.y * 0.9);
        }
    } else if (rd.y < 0.0 && tGround < MAX_DIST) {
        dist = tGround;
        vec3 pos = ro + rd * tGround;
        vec2 c = floor(pos.xz);
        vec2 f = fract(pos.xz);
        vec2 e = min(f, 1.0 - f);
        float line = smoothstep(0.03, 0.0, min(e.x, e.y));
        float lane = isStreet(c) ? 1.0 : 0.35;
        // Center dashes on the avenue that run past the camera.
        float dash = (mod(c.x, AVENUE) == 0.0 && abs(f.x - 0.5) < 0.015 && fract(pos.z * 1.5) < 0.5) ? 1.0 : 0.0;
        col = vec3(0.004, 0.003, 0.012) + groundTint.rgb * (line * 0.7 * lane + dash * 0.8)
              + groundTint.rgb * 0.05 * exp(-dist * 0.15);
    } else {
        dist = MAX_DIST;
        col = sky(rd);
    }

    float fog = 1.0 - exp(-dist * 0.075);
    col = mix(col, sky(rd), fog);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
