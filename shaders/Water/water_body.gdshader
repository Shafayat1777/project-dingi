shader_type canvas_item;

// The screen texture captured by Godot (everything drawn before this water polygon)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Grayscale noise driving the horizontal ripple distortion
uniform sampler2D noise_texture : repeat_enable;

// Base tint/opacity of the water over the reflection
uniform vec4 water_color : source_color = vec4(0.08, 0.26, 0.15, 0.7);

// How far pixels are smeared left/right, and how fast the ripple pattern scrolls
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float scroll_speed = 0.05;

// Normalized screen-space Y of the water surface line, pushed each frame from
// water_body.gd (tracks the spring simulation's average height + camera position)
uniform float water_level = 0.5;

// Per-spring foam energy, pushed each physics frame; only rises from real splash
// events (see water_body.gd's splash()), so foam reads as "just impacted" rather
// than pulsing with ambient wave motion. 128 is a fixed cap (>= spring_number),
// unused tail entries are zeroed
uniform float spring_displacement[128];
uniform int spring_count = 0;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float foam_strength : hint_range(0.0, 2.0) = 0.6;
uniform float foam_band : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// Flip the Y coordinate about the water line to sample from above the surface
	float depth = SCREEN_UV.y - water_level;
	vec2 flipped_uv = vec2(SCREEN_UV.x, water_level - depth);

	// Stretch the noise vertically so its streaks read as horizontal ripples,
	// and scroll it over time for a flowing-water feel
	vec2 noise_uv = UV * vec2(1.0, 5.0) + vec2(TIME * scroll_speed, 0.0);
	float noise_val = texture(noise_texture, noise_uv).r;

	// Smear horizontally; distortion grows with depth so reflections blur out
	// further from the surface line, matching a real water column
	flipped_uv.x += (noise_val - 0.5) * distortion_strength * depth;

	vec4 reflection_color = texture(screen_texture, flipped_uv);

	vec4 result = mix(reflection_color, water_color, water_color.a);

	// Foam highlight at the real (wavy) surface, using this polygon's own local
	// UV rather than the flat mirror line, so it sits exactly where a splash
	// happened instead of on the flattened reflection plane
	if (spring_count > 0) {
		int idx = clamp(int(UV.x * float(spring_count)), 0, spring_count - 1);
		float foam = spring_displacement[idx] * foam_strength;
		float depth_mask = 1.0 - smoothstep(0.0, foam_band, UV.y);
		result.rgb = mix(result.rgb, foam_color.rgb, clamp(foam * depth_mask, 0.0, 1.0) * foam_color.a);
	}

	COLOR = result;
}
