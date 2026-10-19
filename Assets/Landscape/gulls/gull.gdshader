// ONE GULL: a flat picture lying level in the sky, showing a flipbook (frames_x across, frames_y down in one
// picture, gull.png, Enrico's to redraw: the gull seen from above, its head to the top of each frame), played
// in a loop at fps. Each gull starts at its own frame (phase), so a flock doesn't flap all together.
// See-through where the picture is; the dither turns it into dots. (In Unreal: an unlit translucent material
// with a Flipbook node.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; it hides nothing behind it

uniform sampler2D gull_tex : source_color, filter_linear, repeat_disable;   // the flipbook picture
uniform int frames_x = 4;       // frames across the picture…
uniform int frames_y = 4;       // …and down
uniform float fps = 12.0;       // frames a second
uniform float phase = 0.0;      // where in the flipbook this gull starts (set by gulls.gd, a frame number)

void fragment() {
	// Which frame now, and where it sits in the picture (its column and row).
	int count = frames_x * frames_y;
	int f = int(TIME * fps + phase) % count;
	vec2 cell = vec2(float(f % frames_x), float(f / frames_x));
	vec4 picture = texture(gull_tex, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	ALBEDO = picture.rgb;
	ALPHA = picture.a;
}
