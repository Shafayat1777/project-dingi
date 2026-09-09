shader_type canvas_item;

uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float darkness_threshold : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = tex;

	if (outline_enabled && tex.a > 0.0) {
		float brightness = max(tex.r, max(tex.g, tex.b));
		if (brightness < darkness_threshold) {
			COLOR = vec4(outline_color.rgb, tex.a);
		}
	}
}