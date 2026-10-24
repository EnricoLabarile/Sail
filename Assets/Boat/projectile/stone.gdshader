// A CAMERA-FACING PICTURE (a billboard) showing one frame of a sheet of frames (frames_x across, frames_y down);
// the script using it picks `frame`. Used by the sea imp's fireball (fireball.tscn) and the bomb (bomb.tscn).
// (It was the slingshot's stone's shader, hence its name and folder; the slingshot is gone.)
// The picture's bottom middle is the object's point when its QuadMesh is raised by half its height.
// (In Unreal: an unlit translucent sprite material with a Flipbook node, frame chosen from Blueprint.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; it hides nothing behind it

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;   // the sheet of frames
uniform int frames_x = 4;   // frames across the sheet…
uniform int frames_y = 4;   // …and down
uniform int frame = 0;      // the frame to show (set by stone.gd)

void vertex() {
	// Face the camera: keep the object's place, but take the camera's own right, up and forward as the picture's.
	// The node's scale is kept too (the length of each of its axes), so scaling the node in the editor (or the
	// Picture node under it) makes the picture bigger.
	vec3 node_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * node_scale.x,
		INV_VIEW_MATRIX[1] * node_scale.y,
		INV_VIEW_MATRIX[2] * node_scale.z,
		MODEL_MATRIX[3]);
}

void fragment() {
	// Where this frame sits in the sheet (its column and row), and the point of the picture inside it.
	vec2 cell = vec2(float(frame % frames_x), float(frame / frames_x));
	vec4 picture = texture(sheet, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	ALBEDO = picture.rgb;
	ALPHA = picture.a;
}
