// 1-bit look: ordered dither (Bayer 4x4) of everything on screen to two colours,
// paper and ink, like the HTML prototype. Used by dither.tscn (a CanvasLayer over the game).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 paper_color : source_color = vec4(0.922, 0.906, 0.863, 1.0); // #ebe7dc
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.090, 1.0);   // #1b1a17
// The grain: how many pixels of the game view one dot covers. 1 = a dot per pixel. (How many pixels the game
// view has, and so how fine the grain is on the phone, is set by GameView's `dots_across`: game_view.gd.)
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;     // shifts the greys before dithering
uniform float contrast : hint_range(0.2, 3.0) = 1.0;
// Levels (as in Photoshop), applied after brightness and contrast:
uniform float black_point : hint_range(0.0, 1.0) = 0.0;     // greys at or below this become solid ink
uniform float white_point : hint_range(0.0, 1.0) = 1.0;     // greys at or above this become solid paper
uniform float gamma : hint_range(0.2, 3.0) = 1.0;           // the middle greys: above 1 lighter, below 1 darker

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	// One block of pixel_size x pixel_size pixels = one dot (the game view is already at the game's own
	// resolution, so normally 1).
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (block + 0.5) * pixel_size * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	grey = clamp((grey - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	// Levels: black_point..white_point stretched to 0..1, then the middle bent by gamma.
	grey = clamp((grey - black_point) / max(white_point - black_point, 0.001), 0.0, 1.0);
	grey = pow(grey, 1.0 / gamma);
	ivec2 b = ivec2(mod(block, 4.0));
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
	COLOR = grey > threshold ? paper_color : ink_color;
}
