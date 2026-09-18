shader_type canvas_item;

uniform bool enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (enabled) {
		vec2 texel_size = outline_width / vec2(textureSize(TEXTURE, 0));

		float alpha = tex_color.a;
		if (alpha < 1.0) {
			float outline_alpha = 0.0;
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(texel_size.x, 0)).a);
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV - vec2(texel_size.x, 0)).a);
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0, texel_size.y)).a);
			outline_alpha = max(outline_alpha, texture(TEXTURE, UV - vec2(0, texel_size.y)).a);

			if (outline_alpha > 0.0 && alpha < 0.1) {
				tex_color = outline_color;
				tex_color.a = outline_alpha;
			}
		}
	}

	COLOR = tex_color;
}