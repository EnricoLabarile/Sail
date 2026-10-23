// THE BOAT'S SILHOUETTE behind the islands: an extra coat on every mesh of the boat (boat.gd add_silhouette).
// It's drawn with NO depth test (so it shows even where the island is in front of the boat), but only on
// pixels the island has marked with a 2 in the stencil buffer (island_mark.gdshader): there the island hides
// the boat, so there we draw her shape, flat, in silhouette_color. Everywhere else it draws nothing.
// (In Unreal: the classic "see the player through walls" material, with Custom Depth / Stencil.)
shader_type spatial;
// no light; both faces (the sail); no depth test (drawn over the island); no depth written
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;
stencil_mode read, compare_equal, 2;      // only where the island is in front

uniform vec4 silhouette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);   // ink; white = paper

void fragment() {
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
