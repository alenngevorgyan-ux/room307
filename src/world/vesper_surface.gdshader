// THE VESPER — procedural CIR-25D surfaces (Visual Integration V1.4).
// Hand-painted feel without texture assets: large readable pattern groups in world space
// (boxes keep their pattern under any scale), soft value variation, soft speculars.
// Wet surfaces are the only near-mirrors. Final art can replace any material that uses this.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.4);
uniform vec3 alt_color : source_color = vec3(0.3);
uniform int pattern = 0;          // 0 plain 1 planks 2 tiles 3 wallpaper 4 carpet 5 concrete 6 marble 7 panels 8 brick
uniform float scale = 1.0;        // pattern repeats per metre
uniform float contrast = 0.5;     // strength of the alt colour in the pattern
uniform float rough = 0.8;
uniform float metal = 0.0;
uniform float variation = 0.10;   // painterly large-scale value variation
uniform float wet = 0.0;          // 0..1 puddle patches (exterior, after rain)
uniform float ripple = 0.0;       // 0..1 raindrop rings in the puddles (follows the rain)
uniform float emission_energy = 0.0;
uniform float fade = 0.0;         // camera occlusion: ordered-dither cut-out (keeps a faint silhouette)
uniform vec3 emission_color : source_color = vec3(1.0, 0.8, 0.55);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// unrolled: a loop here blanks the frame on the GL Compatibility (macOS) path
float fbm(vec2 p) {
	return 0.5 * vnoise(p) + 0.25 * vnoise(p * 2.03) + 0.125 * vnoise(p * 4.12) + 0.0625 * vnoise(p * 8.3);
}

// world-space UV on the box face facing the dominant normal axis
vec2 plane_uv(out int axis) {
	vec3 n = abs(wnrm);
	if (n.y >= n.x && n.y >= n.z) { axis = 1; return wpos.xz; }
	if (n.x >= n.z) { axis = 0; return vec2(wpos.z, wpos.y); }
	axis = 2;
	return vec2(wpos.x, wpos.y);
}

// raindrop rings in puddles: one drop per 0.6 m cell at a time, widening and fading
float drop_rings(vec2 wxz, float tm) {
	vec2 rg = wxz / 0.6;
	vec2 rc = floor(rg);
	float rh = hash(rc);
	float rt = fract(tm * (0.7 + rh * 0.6) + rh * 9.0);
	vec2 rctr = rc + vec2(0.25) + vec2(0.5 * rh, 0.5 * hash(rc + vec2(7.3, 1.1)));
	float rd = length(rg - rctr);
	return smoothstep(0.06, 0.0, abs(rd - rt * 0.45)) * (1.0 - rt);
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	if (fade > 0.001) {
		ivec2 q = ivec2(mod(FRAGCOORD.xy, 4.0));
		if ((BAYER[q.y * 4 + q.x] + 0.5) / 16.0 < fade) {
			discard;
		}
	}
	int axis;
	vec2 uv = plane_uv(axis) * scale;
	vec3 col = base_color;
	float r = rough;
	float line = 0.0;
	if (pattern == 1) {            // planks: rows, staggered seams, long grain
		float row = floor(uv.y * 3.0);
		float off = hash(vec2(row, 3.1));
		float x = uv.x * 0.5 + off;
		float seam = min(smoothstep(0.0, 0.02, fract(uv.y * 3.0)), smoothstep(0.0, 0.012, fract(x)));
		float grain = fbm(vec2(uv.x * 0.7 + off * 9.0, uv.y * 22.0));
		col = mix(base_color, alt_color, grain * contrast) * (0.88 + 0.24 * hash(vec2(row, floor(x))));
		col *= mix(0.55, 1.0, seam);
	} else if (pattern == 2) {     // tiles with grout
		vec2 g = fract(uv);
		float grout = min(min(smoothstep(0.0, 0.035, g.x), smoothstep(0.0, 0.035, g.y)),
			min(smoothstep(0.0, 0.035, 1.0 - g.x), smoothstep(0.0, 0.035, 1.0 - g.y)));
		col = base_color * (0.92 + 0.16 * hash(floor(uv)));
		col = mix(alt_color, col, mix(1.0 - contrast, 1.0, grout));
		r = mix(rough + 0.1, rough, grout);
	} else if (pattern == 3) {     // wallpaper: soft vertical stripes + faint damask
		float s = smoothstep(0.42, 0.5, abs(fract(uv.x * 4.0) - 0.5));
		float dam = fbm(uv * vec2(6.0, 3.0));
		col = mix(base_color, alt_color, (s * 0.7 + dam * 0.3) * contrast);
	} else if (pattern == 4) {     // carpet: diamond lattice, fibre noise
		vec2 d = abs(fract(vec2(uv.x + uv.y, uv.x - uv.y) * 0.5) - 0.5);
		float lat = smoothstep(0.03, 0.0, abs(d.x + d.y - 0.42));
		float medal = smoothstep(0.12, 0.08, length(d));
		float fibre = vnoise(uv * 40.0);
		col = mix(base_color, alt_color, clamp(lat + medal * 0.6, 0.0, 1.0) * contrast) * (0.9 + 0.12 * fibre);
	} else if (pattern == 5) {     // concrete: blotches
		float b = fbm(uv * 0.8);
		col = mix(base_color, alt_color, smoothstep(0.35, 0.75, b) * contrast) * (0.92 + 0.12 * vnoise(uv * 9.0));
	} else if (pattern == 6) {     // marble: soft veins
		float v = abs(sin((uv.x + uv.y * 0.6 + fbm(uv * 1.5) * 3.0) * 3.0));
		col = mix(alt_color, base_color, mix(1.0, smoothstep(0.0, 0.18, v), contrast));
		col *= 0.94 + 0.1 * fbm(uv * 4.0);
	} else if (pattern == 7) {     // raised panels (wainscot / doors)
		vec2 p = fract(vec2(uv.x * 0.8, uv.y * 1.0));
		float edge = min(min(p.x, 1.0 - p.x), min(p.y, 1.0 - p.y));
		float bevel = smoothstep(0.06, 0.1, edge) - smoothstep(0.1, 0.13, edge) * 0.5;
		float grain = fbm(vec2(uv.x * 0.6, uv.y * 14.0));
		col = mix(base_color, alt_color, grain * contrast) * (0.82 + 0.25 * bevel);
	} else if (pattern == 8) {     // brick
		float row = floor(uv.y * 4.0);
		float x = uv.x * 2.0 + mod(row, 2.0) * 0.5;
		vec2 b = vec2(fract(x), fract(uv.y * 4.0));
		float mortar = min(smoothstep(0.0, 0.05, b.x), smoothstep(0.0, 0.08, b.y));
		col = base_color * (0.85 + 0.25 * hash(vec2(floor(x), row)));
		col = mix(alt_color, col, mortar);
	}
	// painterly large-scale value variation, never pure black or pure white
	col *= 1.0 + (fbm(wpos.xz * 0.21 + wpos.y * 0.13) - 0.5) * variation * 2.0;
	col = clamp(col, vec3(0.055, 0.051, 0.047), vec3(0.945, 0.902, 0.812));
	if (wet > 0.0 && axis == 1) {
		float puddle = smoothstep(0.55, 0.7, fbm(wpos.xz * 0.35));
		r = mix(r, 0.08, puddle * wet);
		col = mix(col, col * 0.55, puddle * wet);
		col += drop_rings(wpos.xz, TIME) * puddle * wet * ripple * vec3(0.16, 0.17, 0.19);
	}
	ALBEDO = col;
	ROUGHNESS = r;
	METALLIC = metal;
	SPECULAR = 0.35;
	EMISSION = emission_color * emission_energy;
}
