// THE SLINGSHOT'S STONE: a picture that always faces the camera (a billboard), showing one frame of a sheet of
// frames (frames_x across, frames_y down; stone.png, Enrico's to redraw). stone.gd picks the frame: 0 while it
// flies, then 1, 2, … to the last once it lands in the water (the splash), and then it's gone.
// The picture's bottom middle is the stone's point (the QuadMesh is raised by half its height in stone.tscn),
// so the splash rises from the water. The dither turns it into dots.
// (In Unreal: an unlit translucent sprite material with a Flipbook node, frame chosen from Blueprint.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; it hides nothing behind it

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;   // the sheet of frames
uniform int frames_x = 4;   // frames across the sheet…
uniform int frames_y = 4;   // …and down
uniform int frame = 0;      // the frame to show (set by stone.gd)

void vertex() {
	// Face the camera: keep the stone's place, but take the camera's own right, up and forward as the picture's.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	// Where this frame sits in the sheet (its column and row), and the point of the picture inside it.
	vec2 cell = vec2(float(frame % frames_x), float(frame / frames_x));
	vec4 picture = texture(sheet, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	ALBEDO = picture.rgb;
	ALPHA = picture.a;
}
