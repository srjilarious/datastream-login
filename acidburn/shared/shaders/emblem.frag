// The acidburn emblem, drawn over the plasma texture: a wide diamond with
// a beaded, perforated cream border that sweeps in from its right corner,
// a fire that spreads from its center until it is white hot and then cools
// into scorched paper, a flame that pops in as hex halftone dots, and a
// dissolve that breaks the diamond into shrinking dots and lets the plasma
// through. Afterwards the flame stays, its dots sized and colored by the
// plasma behind it.
//
// Everything that comes and goes does so per halftone cell: each cell is
// one dot on a hex grid, its coverage is worked out at the cell center and
// sets the dot's radius. A coverage of 1 makes neighbouring dots overlap,
// so solid areas read as solid and only their edges break into dots.
//
// Emblem units: the diamond is 1 unit tall (half extents 0.85 x 0.5),
// centered on `center` and `scale` pixels per unit, y pointing up.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 res;        // output size in pixels
    vec2 center;     // emblem center in pixels, y down
    float scale;     // pixels per emblem unit
    float cellPx;    // distance between halftone dot centers in pixels
    // Intro progress, each 0..1 in this order.
    float drawIn;    // border sweeps in
    float burn;      // fire spreads to white heat
    float cool;      // white heat cools into scorched paper
    float flameOn;   // flame dots pop in
    float dissolve;  // diamond breaks up, plasma shows through
    // Reactions.
    float outro;     // 0..1 cream dots flood outwards on unlock
    float heat;      // 0..1 flare while typing
    float deny;      // 0..1 red-hot scatter after a wrong password
    vec4 shade;      // dark pool behind the prompt: center x, y, radius x, y (pixels)
    float shadeAmt;  // 0..1 how dark the pool is
    vec4 gold;
    vec4 cream;
    vec4 rust;
    vec4 soot;
    vec4 skyTint;    // pale blotches in the scorched paper
    vec4 dotTint;    // flame dots before the plasma shows
    vec4 flameLow;   // flame ramp: dark end
    vec4 flameHigh;  // flame ramp: bright end
    vec4 alertTint;
};

layout(binding = 1) uniform sampler2D plasma;

const vec2 B = vec2(0.85, 0.5);    // diamond half extents
const float BORDER = 0.05;         // border width
const float PI = 3.14159265;

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

// 1 at x <= a, 0 at x >= b, smooth between (a < b).
float fall(float a, float b, float x) {
    return 1.0 - smoothstep(a, b, x);
}

// Offset from the nearest hex grid point; neighbouring points are 1 apart.
vec2 hexOffset(vec2 p) {
    const vec2 r = vec2(1.0, 1.7320508);
    const vec2 h = r * 0.5;
    vec2 a = mod(p, r) - h;
    vec2 b = mod(p - h, r) - h;
    return dot(a, a) < dot(b, b) ? a : b;
}

float ndot(vec2 a, vec2 b) {
    return a.x * b.x - a.y * b.y;
}

// Signed distance to a rhombus with half extents b (Inigo Quilez).
float sdRhombus(vec2 p, vec2 b) {
    p = abs(p);
    float h = clamp(ndot(b - 2.0 * p, b) / dot(b, b), -1.0, 1.0);
    float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
    return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}

// One tongue of fire: widest (half width hw) at y0 with a rounded bottom
// below it, tapering to a point at y0 + h, its spine bending sideways by
// `lean` towards the tip. A taper above 1 gives the concave sides of a
// flame, below 1 a bulging blade. Positive inside, roughly the horizontal
// distance to the edge.
float tongue(vec2 p, float x0, float y0, float h, float hw, float lean, float taper, float phase) {
    float s = (p.y - y0) / h;
    float sway = sin(time * 1.9 + phase + s * 3.0) * 0.022 * max(s, 0.0);
    float cx = x0 + lean * s * s + sway;
    float bottom = hw * 0.9 / h;
    float w;
    if (s < -bottom)
        return -(-s - bottom) * h - abs(p.x - cx);
    if (s > 1.0)
        return -(s - 1.0) * h - abs(p.x - cx);
    if (s < 0.0)
        w = hw * sqrt(max(0.0, 1.0 - (s / bottom) * (s / bottom)));
    else
        w = hw * pow(1.0 - s, taper);
    return w - abs(p.x - cx);
}

// The flame emblem: a teardrop body whose tip curls over, a lick on each
// side curling outwards, a hollow inner flame low in the body, all standing
// on a bar. Spans about y -0.36 (bar) to 0.45 (tip).
float flameField(vec2 p) {
    vec2 f = p;
    float rise = clamp(f.y + 0.2, 0.0, 1.0);
    f.x += (noise(vec2(f.x * 5.0, f.y * 4.0 - time * 2.2)) - 0.5) * 0.10 * rise;
    f.y += (noise(vec2(f.x * 4.0 + 3.1, f.y * 3.0 - time * 1.6)) - 0.5) * 0.04 * rise;
    float m = tongue(f, 0.0, -0.10, 0.55, 0.19, 0.11, 1.7, 0.0);
    m = max(m, tongue(f, -0.12, -0.02, 0.38, 0.085, -0.13, 1.5, 1.7));
    m = max(m, tongue(f, 0.13, -0.05, 0.30, 0.075, 0.10, 1.5, 3.1));
    m = min(m, -tongue(f, 0.015, -0.17, 0.2, 0.055, 0.03, 1.6, 2.2));
    vec2 bar = abs(p - vec2(0.0, -0.36)) - vec2(0.21, 0.022);
    return max(m, -max(bar.x, bar.y));
}

// Scorched paper inside the diamond. age 0..1 lets the rust creep in.
vec3 paper(vec2 p, float age) {
    float n1 = fbm(p * 2.5 + 7.0);
    float n2 = fbm(p * 7.0 + 3.0 + vec2(0.0, time * 0.02));
    float n3 = fbm(p * 1.6 - 4.0);
    vec3 c = mix(cream.rgb, gold.rgb, smoothstep(0.3, 0.7, n1));
    float rustAmt = smoothstep(0.7 - 0.16 * age, 0.86 - 0.12 * age, n2 * 0.6 + n3 * 0.55);
    c = mix(c, rust.rgb, rustAmt * 0.85);
    c = mix(c, soot.rgb, smoothstep(0.7, 0.88, n2) * 0.7 * age);
    c = mix(c, skyTint.rgb, smoothstep(0.70, 0.78, n3) * 0.55);
    return c;
}

// Dot mask for a cell: 1 inside a dot of radius cov * 0.62 (in cell units).
float dotMask(float cov, float dist, float aa) {
    float r = cov * 0.62;
    return fall(r - aa, r + aa, dist) * step(0.001, cov);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 frag = uv * res;
    vec3 pl = texture(plasma, uv).rgb;
    float lum = dot(pl, vec3(0.3, 0.55, 0.15));

    // Halftone cell for this pixel. The grid is anchored on the emblem so
    // it zooms with it rather than sliding past.
    vec2 hp = (frag - center) / cellPx;
    vec2 g = hexOffset(hp);
    vec2 cell = hp - g;
    vec2 cid = floor(cell * 2.0 + 0.5);
    float h1 = hash12(cid);
    float h2 = hash12(cid + 17.0);
    // A wrong password knocks the dots off their grid for a moment.
    g += (vec2(h1, h2) - 0.5) * deny * 0.9;
    float gl = length(g);
    float aa = 1.2 / cellPx;
    vec2 cellPos = center + cell * cellPx;

    // Pixel and cell center in emblem units.
    vec2 p = (frag - center) / scale * vec2(1.0, -1.0);
    vec2 pc = (cellPos - center) / scale * vec2(1.0, -1.0);
    float px = 1.0 / scale;

    vec3 col = pl * dissolve;

    // Darken the plasma behind the prompt so its text stays readable.
    vec2 sd = (frag - shade.xy) / shade.zw;
    col *= 1.0 - shadeAmt * fall(0.4, 1.0, length(sd));

    // ---- the diamond, until it has dissolved ----
    if (dissolve < 1.0 && drawIn > 0.0) {
        float dd = sdRhombus(p, B);

        // Border edge, worked out in the mirrored first quadrant where the
        // edge runs from (B.x, 0) to (0, B.y).
        vec2 q = abs(p);
        vec2 e = normalize(vec2(-B.x, B.y));
        vec2 nrm = vec2(e.y, -e.x);
        float along = dot(q - vec2(B.x, 0.0), e);
        float across = dot(q - vec2(B.x, 0.0), nrm);
        const float sp = 0.032;
        float bead = length(vec2(mod(along, sp) - 0.5 * sp, across)) - 0.012;
        float outer = min(dd + 0.006, bead);
        float hole = length(vec2(mod(along + 0.5 * sp, sp) - 0.5 * sp, across + 0.025)) - 0.0065;
        float shape = fall(-px, px, outer) * smoothstep(-px, px, hole);
        float isBorder = smoothstep(-BORDER - px, -BORDER + px, dd);

        // Sweep in from the right corner, both ways round at once.
        float a = abs(atan(pc.y, pc.x)) / PI;
        float front = drawIn * 1.08;
        float covIn = smoothstep(a, a + 0.06, front);
        float hot = fall(0.0, 0.18, front - a) * (1.0 - burn);

        // Break up from the corners inwards, each dot at its own moment.
        float k = 0.55 * h1 + 0.45 * (1.0 - clamp(abs(pc.x) / B.x, 0.0, 1.0));
        float covD = fall(k - 0.12, k + 0.12, dissolve * 1.4 - 0.2);

        // Fire spreading from the center, then cooling into paper.
        float fn = fbm(p * 4.0 + vec2(0.0, -time * 0.4));
        float fd = length(p * vec2(0.62, 1.0)) + 0.22 * (fn - 0.5) - burn * 0.95;
        float depth = -fd;
        vec3 fire;
        if (depth > 0.0) {
            fire = mix(soot.rgb, rust.rgb, smoothstep(0.0, 0.03, depth));
            fire = mix(fire, gold.rgb, smoothstep(0.03, 0.08, depth));
            fire = mix(fire, vec3(1.0, 0.97, 0.93), smoothstep(0.08, 0.16, depth));
        } else {
            // Embers ahead of the front, and a spark at the center just
            // before it catches.
            fire = rust.rgb * exp(-fd * 22.0) * 0.7 * smoothstep(0.6, 1.0, drawIn);
        }
        vec3 inside = mix(fire, paper(p, cool), smoothstep(0.0, 1.0, cool));

        // A hand-drawn wave along the lower left edge.
        float inward = -dd - BORDER;
        float t = along / length(B);
        float wave = 0.03 + 0.011 * sin(along * 170.0);
        float squiggle = fall(0.4 * px, 1.6 * px, abs(inward - wave) - 0.002)
                       * step(p.x, 0.0) * step(p.y, 0.0)
                       * smoothstep(0.18, 0.24, t) * fall(0.7, 0.76, t) * cool;
        inside = mix(inside, soot.rgb, squiggle * 0.85);

        vec3 rim = mix(gold.rgb, cream.rgb, 0.25 + 0.35 * fbm(p * 30.0));
        rim = mix(rim, vec3(1.0), hot);
        vec3 diamond = mix(inside, rim, isBorder);

        float vis = shape * dotMask(covIn * covD, gl, aa);
        col = mix(col, diamond, vis);
    }

    // ---- the flame ----
    if (flameOn > 0.0) {
        // A soft dark halo, per pixel, so the silhouette holds against
        // bright marble once the dots sit over the plasma.
        float mp = flameField((p - vec2(0.0, -0.36)) / vec2(1.0 + 0.04 * heat, 1.0 + 0.14 * heat) + vec2(0.0, -0.36));
        col *= 1.0 - 0.6 * dissolve * flameOn * smoothstep(-0.07, 0.0, mp);
        // Typing makes it stand taller, anchored on its bar.
        vec2 fp = pc - vec2(0.0, -0.36);
        fp /= vec2(1.0 + 0.04 * heat, 1.0 + 0.14 * heat);
        float m = flameField(fp + vec2(0.0, -0.36));
        float covF = smoothstep(-0.015, 0.025, m);
        covF *= smoothstep(h2 - 0.1, h2 + 0.1, flameOn * 1.25 - 0.1);
        // Over the paper, a slow mottling thins some dots out.
        covF *= mix(0.62 + 0.5 * fbm(pc * 7.0 + vec2(0.0, -time * 0.5)), 1.0, dissolve);
        // Once the plasma is through, the marble behind sets the dot size.
        vec3 plc = texture(plasma, cellPos / res).rgb;
        float lumC = dot(plc, vec3(0.3, 0.55, 0.15));
        covF *= mix(1.0, 0.78 + 0.3 * smoothstep(0.04, 0.4, lumC), dissolve);
        covF *= 1.0 + 0.1 * heat;

        // The same swirl recolored: dark olive through gold to near white.
        vec3 marble = mix(flameLow.rgb, gold.rgb, smoothstep(0.04, 0.3, lum));
        marble = mix(marble, cream.rgb, smoothstep(0.3, 0.55, lum));
        marble = mix(marble, flameHigh.rgb, smoothstep(0.55, 0.85, lum));
        vec3 fc = mix(dotTint.rgb, marble, dissolve);
        fc *= 1.0 + 0.35 * heat;
        float flicker = 0.7 + 0.6 * hash12(cid + floor(time * 20.0));
        fc = mix(fc, alertTint.rgb * flicker, deny * 0.85);

        col = mix(col, fc, dotMask(covF, gl, aa));
    }

    // ---- unlock: cream dots flood out from the flame ----
    if (outro > 0.0) {
        float front = outro * 3.2;
        float covO = fall(front - 0.5, front - 0.05, length(pc) + 0.25 * h1);
        col = mix(col, cream.rgb, dotMask(covO, gl, aa));
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
