// A WIND GUST booster's look: a flat picture lying on the water, playing a flipbook in a loop (frames_x across,
// frames_y down in one picture, gust.png, Enrico's to redraw), at fps; each gust starts at its own frame (phase).
// Sharp pixels (nearest), a solid pixel or nothing (alpha_cut). (In Unreal: an unlit masked material with a
// Flipbook node.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; no ink outline round it
// As the sea: never drawn where the boat's mask is (her inside, below the water line).
stencil_mode read, compare_not_equal, 1;

uniform sampler2D gust_tex : source_color, filter_nearest, repeat_disable;   // the flipbook picture
uniform int frames_x = 4;       // frames across the picture…
uniform int frames_y = 4;       // …and down
uniform float fps = 12.0;       // frames a second
uniform float phase = 0.0;      // where in the flipbook this gust starts (a frame number, set by gust.gd)
uniform float alpha_cut = 0.5;  // see-through below this, solid above

void fragment() {
	// Which frame now, and where it sits in the picture (its column and row).
	int count = frames_x * frames_y;
	int f = int(TIME * fps + phase) % count;
	vec2 cell = vec2(float(f % frames_x), float(f / frames_x));
	vec4 picture = texture(gust_tex, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	if (picture.a < alpha_cut) {
		discard;
	}
	ALBEDO = picture.rgb;
	ALPHA = 1.0;    // writing ALPHA puts it with the see-through things, drawn after the sea
}
