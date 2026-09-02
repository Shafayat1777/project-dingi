shader_type canvas_item;

// Water Color
uniform vec4 top_color : source_color = vec4(0.2, 0.5, 0.8, 0.5);
uniform vec4 bottom_color : source_color = vec4(0.0, 0.2, 0.4, 0.85);

// Reflection
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.35;

// Idle animation
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_frequency : hint_range(0.0, 50.0) = 12.0;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.008;

void fragment(){
	// Animation based on position
	float wave = sin(UV.x * wave_frequency + TIME * wave_speed) * 0.5
	           + sin(UV.x * wave_frequency * 1.7 - TIME * wave_speed * 0.6) * 0.5;
	
	// Ripple Effect
	vec2 distorted_uv = SCREEN_UV + vec2(0.0, wave * distortion_strength);
	vec4 screen_color = texture(screen_texture, distorted_uv);
	
	// Top to bottom Gradient
	vec4 base = mix(top_color, bottom_color, UV.y);
	
	// Ripple effect blend
	vec4 result = mix(base, screen_color, reflection_strength);
	
	// Brightness Flash
	result.rgb += wave * 0.015;
	
	COLOR = vec4(result.rgb, base.a);
}