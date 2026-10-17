// THE SEA: the big flat plane under everything (Sea, in sea.tscn), 504 x 504 metres, fixed in place with
// home in the middle. The coasts are separate 3D meshes on top of it. It does two things:
//   1. it paints the sea with Enrico's texture (sea_tex), repeated over the water and animated
//      (a flipbook of frames and/or a slow scroll), tinted by sea_color; with short dark wavelets on top
//      that stay fixed in the world, so you can see the boat moving;
//   2. it never covers the boat: it skips every pixel the boat's mask has marked (a stencil, see
//      Assets/Boat/boat_mask.gdshader), so the water doesn't cut through her when she heels.
// Unshaded: no light on it, the greys are shown as they are; the dither turns them into paper and ink.
shader_type spatial;
render_mode unshaded;
// The stencil: draw only where the stencil buffer is NOT 1 (1 = the boat's mask was drawn there).
stencil_mode read, compare_not_equal, 1;

uniform vec4 sea_color : source_color = vec4(0.91, 0.91, 0.91, 1.0);   // the water's grey (tints the texture)

// The sea texture: one image, repeated over the water. hint_default_white: with no image it's plain white,
// so the sea is just sea_color. filter_nearest: crisp pixels; repeat_enable: it tiles.
uniform sampler2D sea_tex : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform float tile_size = 8.0;       // metres of sea one tile of the texture covers
// The flipbook: the image can hold several frames side by side, frames_x across and frames_y down
// (like a Flipbook in Unreal). They play in turn, fps frames a second. 1 x 1 = one still tile.
uniform int frames_x = 1;
uniform int frames_y = 1;
uniform float fps = 6.0;
uniform vec2 scroll = vec2(0.0, 0.0);   // metres a second the texture slides (0, 0 = it stays put)
uniform vec4 wavelet : source_color = vec4(0.25, 0.25, 0.24, 1.0);
uniform float cell = 2.2;       // metres between wavelets
uniform float dash_len = 0.22;  // a wavelet's half length, in cells
// (The fog of war is a screen effect of its own: fog.gdshader, put on screen by sea.gd.)

// world_pos: where on the sea this pixel is, in metres. vertex() works it out, fragment() reads it.
varying vec3 world_pos;

// A cheap "random" number between 0 and 1 for each cell, always the same for the same cell.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The texture. 1. Which point of the tile this is: the position in the world (in metres, plus the
	//    scroll), divided by the tile's size; fract() keeps only the part after the point, 0..1 in the tile.
	vec2 in_tile = fract((world_pos.xz + scroll * TIME) / tile_size);
	// 2. Which frame now: the time × frames a second, counted round (% = what's left after dividing).
	int frame_count = frames_x * frames_y;
	int frame = int(TIME * fps) % frame_count;
	// 3. Where that frame sits in the image: its column and row.
	vec2 frame_cell = vec2(float(frame % frames_x), float(frame / frames_x));
	// 4. The point of the image: inside that frame's cell (each cell is 1/frames_x wide, 1/frames_y tall).
	vec2 uv = (frame_cell + in_tile) / vec2(float(frames_x), float(frames_y));
	vec3 water = texture(sea_tex, uv).rgb * sea_color.rgb;

	// The wavelets: the sea is cut into cells, each with one short curved dash at a random spot.
	vec2 p = world_pos.xz / cell;
	vec2 id = floor(p);
	vec2 f = fract(p) - (vec2(hash(id), hash(id + 7.3)) * 0.5 + 0.25);
	float bend = f.x * f.x * 1.5;                       // a slight curve
	float on = step(abs(f.y + bend), 0.03) * step(abs(f.x), dash_len);
	float blink = step(0.35, 0.5 + 0.5 * sin(TIME * 0.7 + hash(id + 3.1) * 6.28));   // each fades in and out

	ALBEDO = mix(water, wavelet.rgb, on * blink);
	// Fully solid, but writing ALPHA puts the sea among the see-through things, which Godot draws AFTER
	// the solid ones: so the boat (and its mask) is already drawn when the sea comes, and the stencil works.
	ALPHA = 1.0;
}
