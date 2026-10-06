// THE VESPER — windows and the city beyond them (Design + Motion Polish V1, Pass E/G).
// Cheap motion at the edge of attention: rain running down the glass, the occasional sweep of a
// passing car's lights low in the pane, a sky that changes with the night. mode 1 = a distant
// facade (skyline blocks): scattered lit windows, a slow blink of a red aircraft light.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int mode = 0;
uniform vec3 sky_top : source_color = vec3(0.08, 0.11, 0.16);
uniform vec3 sky_bottom : source_color = vec3(0.22, 0.2, 0.2);   // city glow from below
uniform float energy = 1.0;
uniform float rain = 1.0;           // 0..1 drops and streaks on the glass
uniform float traffic = 1.0;        // 0..1 passing headlights
uniform float seed = 0.0;
uniform float fade = 0.0;           // camera occlusion dither (shared contract with surfaces)

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade > 0.001) {
		ivec2 q = ivec2(mod(FRAGCOORD.xy, 4.0));
		if ((BAYER[q.y * 4 + q.x] + 0.5) / 16.0 < fade) {
			discard;
		}
	}
	vec2 uv = vec2(UV.x, 1.0 - UV.y);   // uv.y = up
	vec3 col;
	if (mode == 1) {
		// distant building: a grid of windows, a few lit and slowly changing
		vec2 g = vec2(wpos.x + wpos.z, wpos.y) * vec2(1.6, 1.4);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
		float lit = step(0.82, hash(cell + seed));
		float flick = step(0.5, hash(cell + floor(TIME * 0.05 + hash(cell) * 7.0)));
		col = sky_top * 0.35 + win * lit * mix(0.5, 1.0, flick) * vec3(1.0, 0.78, 0.5) * 0.9;
		// aircraft warning light at the top edge
		float top = smoothstep(0.985, 1.0, uv.y) * step(0.5, fract(TIME * 0.5 + seed));
		col += top * vec3(1.0, 0.08, 0.05) * 3.0;
		ALBEDO = col * energy;   // unshaded: ALBEDO is the final colour (EMISSION is ignored)
	} else {
		// each window gets its own timing (no two panes rain or flash in sync)
		float ws = hash(floor(wpos.xz / 3.0) + seed);
		// sky: cool above, city glow below
		col = mix(sky_bottom, sky_top, smoothstep(0.0, 0.85, uv.y));
		// a passing car: a soft warm-white band sweeping low in the pane, now and then
		float cyc = fract(TIME * 0.045 + ws * 5.0);
		float on = step(cyc, 0.22) * traffic;
		float x = cyc / 0.22 * 1.4 - 0.2;
		float band = exp(-pow((uv.x - x) * 6.0, 2.0)) * smoothstep(0.42, 0.0, uv.y) * on;
		col += band * vec3(0.9, 0.9, 0.85) * 0.15;   // faint: a pane half-hidden behind a bar must not bloom into a blob
		// rain: thin streaks running down, beads that catch the light
		float colx = floor(uv.x * 46.0);
		float speed = 0.35 + hash(vec2(colx, ws)) * 0.6;
		float y = fract(uv.y * 1.5 + TIME * speed + hash(vec2(colx, 3.1 + ws)));   // streaks run down
		float line = 1.0 - smoothstep(0.05, 0.14, abs(fract(uv.x * 46.0) - 0.5));
		float streak = smoothstep(0.92, 1.0, y) * step(0.55, hash(vec2(colx, 9.7 + ws))) * line;
		vec2 bead_cell = floor(uv * vec2(70.0, 40.0));
		float bead = step(0.93, hash(bead_cell + ws)) * smoothstep(0.5, 0.15, length(fract(uv * vec2(70.0, 40.0)) - 0.5));
		col += (streak * 0.22 + bead * 0.12) * rain * (sky_bottom + vec3(0.15));
		ALBEDO = col * energy;
	}
}
