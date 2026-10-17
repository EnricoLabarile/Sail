// THE WAKE: the ribbon of foam the boat leaves on the water (built by wake.gd).
// Each point of the ribbon carries, in its vertex colour's alpha, how strong the foam is there
// (strong just behind the boat, fading to nothing at the end, and weaker if she was slow).
// Unshaded: no light; the dither turns the white into paper-and-ink dots.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// An optional drawing of foam: across the ribbon (u: 0 one edge, 1 the other) and along it (v: 0 at the
// boat, 1 at the end). Without one it's plain white.
uniform sampler2D foam_tex : source_color, hint_default_white, filter_nearest;
uniform float edge_softness = 0.5;   // 0 = hard edges; higher = the ribbon fades more toward its sides

void fragment() {
	// Fade toward the two edges: 0 at the edges, 1 in the middle (u goes 0..1 across).
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float edges = smoothstep(0.0, edge_softness, across);
	vec4 drawing = texture(foam_tex, UV);
	ALBEDO = foam_color.rgb * drawing.rgb;
	ALPHA = COLOR.a * edges * drawing.a;
}
