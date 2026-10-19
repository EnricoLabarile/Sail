// THE SLINGSHOT'S AIM: while the pouch is pulled, a dashed ring lies on the water where the stone will land,
// with a faint spot of ink inside it, firmer the nearer the pull is to the shot (as in the prototype: paper
// under ink, so it reads over any sea). slingshot.gd moves it and sets `strength`.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float strength = 0.0;    // 0 = just started pulling, 1 = about to shoot
uniform float dashes = 12.0;     // how many dashes round the ring

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;        // -1..1 across the square: the ring's edge is at 1
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	// Which part of the ring: dashes and gaps, by the angle round the middle.
	float dash = step(0.5, fract(atan(p.y, p.x) / 6.2832 * dashes));
	if (r > 0.8 && dash > 0.5) {
		ALBEDO = vec3(0.0);                               // an ink dash
		ALPHA = 0.5 + 0.5 * strength;
	} else if (r > 0.72) {
		ALBEDO = vec3(1.0);                               // paper round and between the dashes
		ALPHA = (0.5 + 0.5 * strength) * 0.7;
	} else {
		ALBEDO = vec3(0.0);                               // the faint spot inside
		ALPHA = 0.12 + 0.18 * strength;
	}
}
