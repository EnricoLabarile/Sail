// THE SEA: the big flat plane under everything (Sea, in sea.tscn), Land.WORLD_SIZE metres a side (1008), fixed in place with
// home in the middle. The coasts are separate 3D meshes on top of it. It does two things:
//   1. it paints the sea with Enrico's texture (sea_tex), repeated over the water and animated
//      (a flipbook of frames and/or a slow scroll), tinted by sea_color;
//   2. it draws waves along the coasts: lines of foam that roll in toward the shore (see SHORE WAVES below);
//   3. it never covers the boat: it skips every pixel the boat's mask has marked (a stencil, see
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
uniform float tile_size = 32;       // metres of sea one tile of the texture covers
// The flipbook: the image can hold several frames side by side, frames_x across and frames_y down
// (like a Flipbook in Unreal). They play in turn, fps frames a second. 1 x 1 = one still tile.
uniform int frames_x = 1;
uniform int frames_y = 1;
uniform float fps = 6.0;
uniform vec2 scroll = vec2(0.0, 0.0);   // metres a second the texture slides (0, 0 = it stays put)
// The turn that follows the wind (set every frame by sea.gd; 0 in the editor): the angle, and a shift that
// keeps the water under the boat still while it turns.
uniform float wind_angle = 0.0;
uniform vec2 wind_offset = vec2(0.0, 0.0);
// (The fog of war is a screen effect of its own: fog.gdshader, put on screen by sea.gd.)

// THE GRID ON THE SEA (as the prototype's room seams): dashed lines along the borders between the squares of
// the logbook's 9 x 9 map, so you can see on the water where one square ends and the next begins.
uniform vec4 seam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // the lines' colour (white: paper, reads on this sea)
uniform float seam_opacity : hint_range(0.0, 1.0) = 0.8;   // how strong the lines are (0 = no grid)
uniform float seam_width = 0.3;      // metres: how thick a line is
uniform float seam_dash = 0.6;       // metres: one dash…
uniform float seam_gap = 0.9;        // …and the gap after it
uniform float cell_size = 112.0;     // metres a square, a side (sea.gd sends Land.WORLD_SIZE / 9)
uniform float world_size = 1008.0;   // the map's side (sea.gd sends Land.WORLD_SIZE): the grid starts at its edge

// SHORE WAVES (Enrico): lines of foam parallel to every coast, rolling in toward it, and a steady line of foam
// right along it. They read shore_tex, a picture of how far each point of the sea is from the nearest coast,
// baked by the ShoreBaker node in Overworld (Assets/Landscape/shore/shore_baker.gd: press "Bake shore" after
// changing the coasts). One texture read and a few sums a pixel: cheap.
// hint_default_white: with no picture, every point is "far from any coast", so no waves at all.
uniform sampler2D shore_tex : hint_default_white, filter_linear, repeat_disable;
uniform float shore_max_distance = 32.0;   // metres white means in shore_tex (must match the baker's MAX_DISTANCE)
uniform vec4 shore_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // the foam's colour (white: paper)
uniform float shore_opacity : hint_range(0.0, 1.0) = 0.9;   // how strong the foam is (0 = no shore waves)
uniform float shore_width = 10.0;      // metres from the coast the waves reach
uniform float wave_spacing = 3.5;      // metres between one line of foam and the next
uniform float wave_speed = 1.2;        // metres a second they roll in toward the shore
uniform float wave_line = 0.5;         // metres: how thick a line is near the shore (thinner further out)
uniform float foam_width = 0.8;        // metres of steady foam right along the coast
uniform float wave_wobble = 1.0;       // metres the lines wander in and out, so they aren't perfectly even

// world_pos: where on the sea this pixel is, in metres. vertex() works it out, fragment() reads it.
varying vec3 world_pos;

// Turns a point round (0, 0) by an angle, clockwise seen from above (the same as Vector2.rotated in GDScript).
vec2 rotate(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// 1 if this point of the sea is on a dash of the grid's lines, 0 if not.
float seam(vec2 p) {
	// How far the point is from the nearest border, across (x) and down (z): the borders are every cell_size
	// metres, counted from the map's edge (-world_size / 2).
	vec2 from_edge = p + world_size * 0.5;
	vec2 to_border = abs(from_edge - round(from_edge / cell_size) * cell_size);
	// The dashes: along a north-south border they go by z, along an east-west border by x.
	float period = seam_dash + seam_gap;
	float dash_along_z = step(fract(p.y / period), seam_dash / period);
	float dash_along_x = step(fract(p.x / period), seam_dash / period);
	float on_ns_border = step(to_border.x, seam_width * 0.5) * dash_along_z;   // a north-south line
	float on_ew_border = step(to_border.y, seam_width * 0.5) * dash_along_x;   // an east-west line
	return max(on_ns_border, on_ew_border);
}

// A cheap smooth noise (0..1) over the sea: random values at whole metres, blended in between.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 where this point of the sea is on a line of foam by the shore, 0 where it isn't.
float shore_foam(vec2 p) {
	// 1. How far from the coast, in metres: shore_tex covers the whole map, so the point's place on the map
	//    (0..1 across and down) is where to read it.
	vec2 on_map = (p + world_size * 0.5) / world_size;
	float from_coast = texture(shore_tex, on_map).r * shore_max_distance;
	if (from_coast > shore_width) {
		return 0.0;                                    // too far out: no waves (most of the sea)
	}
	// 2. Wobble it a little, so the lines aren't perfectly even copies of the coast.
	from_coast += (noise(p * 0.25) - 0.5) * wave_wobble;
	// 3. Near the shore 1, at shore_width 0: lines get thinner further out.
	float closeness = 1.0 - from_coast / shore_width;
	// 4. The rolling lines: every wave_spacing metres, moving in at wave_speed. fract() counts 0..1 from one line
	//    to the next; the point is on a line while that count is under the line's thickness.
	float count = fract((from_coast + TIME * wave_speed) / wave_spacing);
	float on_line = step(count, wave_line * closeness / wave_spacing);
	// 5. The steady foam right along the coast.
	float on_foam = step(from_coast, foam_width);
	return max(on_line, on_foam);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The texture. 0. Turn it with the wind: read the drawing at this point turned back by the wind's angle
	//    (so the drawing looks turned forward by it), plus the shift from sea.gd.
	vec2 turned = rotate(world_pos.xz, -wind_angle) + wind_offset;
	// 1. Which point of the tile this is: that position (in metres, plus the scroll), divided by the tile's
	//    size; fract() keeps only the part after the point, 0..1 in the tile.
	vec2 in_tile = fract((turned + scroll * TIME) / tile_size);
	// 2. Which frame now: the time × frames a second, counted round (% = what's left after dividing).
	int frame_count = frames_x * frames_y;
	int frame = int(TIME * fps) % frame_count;
	// 3. Where that frame sits in the image: its column and row.
	vec2 frame_cell = vec2(float(frame % frames_x), float(frame / frames_x));
	// 4. The point of the image: inside that frame's cell (each cell is 1/frames_x wide, 1/frames_y tall).
	vec2 uv = (frame_cell + in_tile) / vec2(float(frames_x), float(frames_y));
	vec3 water = texture(sea_tex, uv).rgb * sea_color.rgb;

	// The grid: is this pixel on a border between squares, and on a dash rather than a gap?
	vec3 with_grid = mix(water, seam_color.rgb, seam_opacity * seam(world_pos.xz));
	// The shore waves on top.
	ALBEDO = mix(with_grid, shore_color.rgb, shore_opacity * shore_foam(world_pos.xz));
	// Fully solid, but writing ALPHA puts the sea among the see-through things, which Godot draws AFTER
	// the solid ones: so the boat (and its mask) is already drawn when the sea comes, and the stencil works.
	ALPHA = 1.0;
}
