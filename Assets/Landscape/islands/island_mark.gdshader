// THE ISLAND'S MARK (a stencil): an invisible second coat on the islands (island.tres, next_pass).
// It draws nothing you can see, but wherever the island is VISIBLE on screen it writes a 2 into the stencil
// buffer (the hidden layer the boat's mask also uses, with 1). Where the boat is in front of the island, the
// island isn't visible there (the depth test hides it), so no 2 is written. So the 2s are exactly "the island
// is in front of whatever is behind it": the boat's silhouette (boat_silhouette.gdshader) is drawn only there.
// (In Unreal: like writing Custom Stencil on the mountain, and reading it in the boat's see-through material.)
shader_type spatial;
render_mode unshaded, depth_draw_never;   // no light; it doesn't change the depth
stencil_mode write, compare_always, 2;    // write 2 where the island is drawn

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;   // invisible
}
