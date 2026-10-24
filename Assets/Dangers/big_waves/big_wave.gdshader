// A BIG WAVE's picture: a flat plane lying on the water (the wave's crest across it, the way it travels toward
// the top of the picture), showing one frame of a flipbook (big_wave.png, frames_x x frames_y, Enrico's to
// redraw: build up, break into foam, fade). big_wave.gd picks the frame from the wave's age, so the animation
// plays once over its life. Not drawn over the boat's inside (the stencil, as the sea and the fishing spots).
// (In Unreal: an unlit translucent decal-like plane with a Flipbook node.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
stencil_mode read, compare_not_equal, 1;   // not over the boat's inside (boat_mask.gdshader writes 1 there)

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
uniform int frames_x = 4;
uniform int frames_y = 4;
uniform int frame = 0;

void fragment() {
	vec2 cell = vec2(float(frame % frames_x), float(frame / frames_x));
	vec4 picture = texture(sheet, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	ALBEDO = picture.rgb;
	ALPHA = picture.a;
}
