// THE BOAT'S MASK (a stencil): an invisible coat over every mesh of the boat.
// It draws nothing you can see (ALPHA = 0), but it marks each pixel the boat covers with a 1 in the
// stencil buffer, a hidden layer of the screen. The sea's shader (sea.gdshader) is drawn after it and
// skips every pixel marked 1: so the water never covers the boat, even the parts that dip under the
// waterline when she heels. (In Unreal: like writing Custom Stencil on the boat and masking with it.)
// boat.gd puts it on every mesh of the boat as a material_overlay (an extra layer on top of its own
// materials), so it keeps working when the models are swapped.
shader_type spatial;
// unshaded: no lighting work; depth_draw_never: it doesn't change the depth;
// cull_disabled: both faces (the sail is seen from both sides).
render_mode unshaded, depth_draw_never, cull_disabled;
// Write the value 1 into the stencil buffer wherever this is drawn.
stencil_mode write, compare_always, 1;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;   // invisible
}
