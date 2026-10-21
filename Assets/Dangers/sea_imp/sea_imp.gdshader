// THE SEA IMP'S PICTURE: a picture that always faces the camera (a billboard, like the slingshot's stone),
// showing one frame of a sheet of frames (frames_x across, frames_y down; sea_imp.png is a single frame for now,
// Enrico will replace it with an animation sheet: then set frames_x / frames_y and sea_imp_zone.gd picks `frame`).
// Whatever of it is below the water (world height under water_level) is not drawn, so it rises out of the
// water and sinks back into it when sea_imp_zone.gd moves it up and down.
// (In Unreal: an unlit masked sprite material with a Flipbook node, clipped below a world height.)
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;   // no light; both faces; it hides nothing behind it

uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;   // the picture (or sheet of frames)
uniform int frames_x = 1;          // frames across the sheet…
uniform int frames_y = 1;          // …and down
uniform int frame = 0;             // the frame to show
uniform float alpha_cut = 0.5;     // a pixel is drawn solid or not at all (sharp edges, as the dither wants)
uniform float water_level = 0.0;   // the sea's height: nothing below it is drawn

varying float world_height;        // how high this point of the picture is in the world (for the water line)

void vertex() {
	// Face the camera: keep the imp's place, but take the camera's own right, up and forward as the picture's.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	// The point's height in the world: the imp's height plus how far up the (camera-facing) picture it is.
	world_height = MODEL_MATRIX[3].y + INV_VIEW_MATRIX[0].y * VERTEX.x + INV_VIEW_MATRIX[1].y * VERTEX.y;
}

void fragment() {
	if (world_height < water_level) {
		discard;   // under the water
	}
	vec2 cell = vec2(float(frame % frames_x), float(frame / frames_x));
	vec4 picture = texture(sheet, (cell + UV) / vec2(float(frames_x), float(frames_y)));
	if (picture.a < alpha_cut) {
		discard;
	}
	ALBEDO = picture.rgb;
	ALPHA = 1.0;
}
