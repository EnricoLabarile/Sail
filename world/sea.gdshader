// The sea: pale water with short dark wavelets fixed in the world (so you see her move),
// each one fading in and out. Unshaded: the dither turns it into paper and ink.
shader_type spatial;
render_mode unshaded;

uniform vec4 water : source_color = vec4(0.80, 0.80, 0.78, 1.0);
uniform vec4 wavelet : source_color = vec4(0.25, 0.25, 0.24, 1.0);
uniform float cell = 2.2;       // units between wavelets
uniform float dash_len = 0.22;  // a wavelet's half length, in cells

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / cell;
	vec2 id = floor(p);
	vec2 f = fract(p) - (vec2(hash(id), hash(id + 7.3)) * 0.5 + 0.25);
	float bend = f.x * f.x * 1.5;                       // a slight curve
	float on = step(abs(f.y + bend), 0.03) * step(abs(f.x), dash_len);
	float blink = step(0.35, 0.5 + 0.5 * sin(TIME * 0.7 + hash(id + 3.1) * 6.28));
	ALBEDO = mix(water.rgb, wavelet.rgb, on * blink);
}
