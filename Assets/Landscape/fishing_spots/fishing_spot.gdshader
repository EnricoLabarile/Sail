// A FISHING SPOT's look: a flat picture lying on the water, showing a flipbook (frames_x across, frames_y down
// in one picture, fishing_spot.png, Enrico's to redraw): the water darkens and rings well up from the middle
// and spread out (the prototype's drawSpot). Played in a loop at fps; each spot starts at its own frame
// (phase), so they don't all pulse together. `fade` goes from 1 to 0 when the spot is fished out.
// See-through where the picture is; the dither turns its darkness into dots.
// (In Unreal: an unlit translucent material with a Flipbook node.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; it hides nothing behind it
// As the sea: never drawn where the boat's mask is (her inside, below the water line), so a spot under her
// doesn't darken the floor of the boat (see Assets/Boat/boat_mask.gdshader).
stencil_mode read, compare_not_equal, 1;

uniform sampler2D spot_tex : source_color, filter_linear, repeat_disable;   // the flipbook picture
uniform int frames_x = 4;       // frames across the picture…
uniform int frames_y = 4;       // …and down
uniform float fps = 16.0;       // frames a second
uniform float phase = 0.0;      // where in the flipbook this spot starts (set by fishing_spot.gd, a frame number)
uniform float fade = 1.0;       // 1 = as drawn, 0 = gone (set by fishing_spot.gd once it's fished out)

void fragment() {
	// Which frame now, and where it sits in the picture (its column and row).
	int count = frames_x * frames_y;
	int f = int(TIME * fps + phase) % count;
	vec2 cell = vec2(float(f % frames_x), float(f / frames_x));
	vec4 picture = texture(spot_tex, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	ALBEDO = picture.rgb;
	ALPHA = picture.a * fade;
}
