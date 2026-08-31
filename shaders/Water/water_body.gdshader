shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.2, 0.5, 0.8, 0.5);
uniform vec4 bottom_color : source_color = vec4(0.0, 0.2, 0.4, 0.85);

void fragment(){
	// UV.y goes from 0 (top) to 1 (bottom) of the polygon's bounding box
	COLOR = mix(top_color, bottom_color, UV.y);
}