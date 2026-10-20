// THE STONE'S SHADOW: a round spot of ink lying flat on the water under the stone (stone.gd moves it), as dark
// as the clouds' shadows; the dither turns it into dots. (In Unreal: a tiny decal-like plane with a round mask.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float opacity = 0.35;   // how dark (the clouds' shadows are 0.35)

void fragment() {
	// A disc: ink inside the circle that touches the square's edges, nothing outside it.
	float from_middle = length(UV - vec2(0.5)) * 2.0;   // 0 in the middle, 1 at the edge of the circle
	if (from_middle > 1.0) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = opacity;
}
