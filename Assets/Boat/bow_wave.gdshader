// THE BOW WAVE: the water thrown up and out at the bow, like Wind Waker's. Two flat "wings", one a side of the
// bow (boat.tscn: BowWaveLeft / BowWaveRight), each showing a flipbook: one picture with its frames in a grid
// (frames_x across, frames_y down; bow_wave.png, Enrico's to redraw), played in turn.
// boat.gd sets `frame` (which frame now: it counts up faster the faster she goes) and `strength` (how solid:
// 0 when she's still or at anchor). See-through where the picture is; the dither turns it into dots.
// (In Unreal: a translucent unlit material with a Flipbook node.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; it doesn't hide what's behind

uniform sampler2D wave_tex : source_color, filter_linear, repeat_disable;   // the flipbook picture
uniform int frames_x = 4;       // frames across the picture…
uniform int frames_y = 4;       // …and down
uniform float frame = 0.0;      // the frame to show now (set by boat.gd; counted round)
uniform float strength : hint_range(0.0, 1.0) = 1.0;   // how solid the whole wave is (set by boat.gd)

void fragment() {
	// Which frame, and where it sits in the picture (its column and row).
	int count = frames_x * frames_y;
	int f = int(frame) % count;
	vec2 cell = vec2(float(f % frames_x), float(f / frames_x));
	// The point of the picture: inside that frame's cell.
	vec2 uv = (cell + UV) / vec2(float(frames_x), float(frames_y));
	vec4 picture = texture(wave_tex, uv);
	ALBEDO = picture.rgb;
	ALPHA = picture.a * strength;
}
