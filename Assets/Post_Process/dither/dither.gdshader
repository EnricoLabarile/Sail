// 1-bit look: ordered dither (Bayer 4x4) of everything on screen to two colours,
// paper and ink, like the HTML prototype. Used by dither.tscn (a CanvasLayer over the game).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 paper_color : source_color = vec4(0.922, 0.906, 0.863, 1.0); // #ebe7dc
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.090, 1.0);   // #1b1a17
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0; // screen pixels per game pixel (the grain)
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;     // shifts the greys before dithering
uniform float contrast : hint_range(0.2, 3.0) = 1.0;

const float BAYER[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

void fragment() {
	// One block of pixel_size x pixel_size screen pixels = one game pixel.
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (block + 0.5) * pixel_size * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	grey = clamp((grey - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	ivec2 b = ivec2(mod(block, 4.0));
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0;
	COLOR = grey > threshold ? paper_color : ink_color;
}
