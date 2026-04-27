shader_type canvas_item;

// Vertical gradient body + solid outline ring + anti-aliased rounded
// corners in one pass. Optionally adds a soft white highlight strip
// inset from the top inner edge (the "glossy sticker" cue).

uniform vec4 top_color : source_color = vec4(1.0);
uniform vec4 bot_color : source_color = vec4(0.0);
uniform vec4 outline_color : source_color = vec4(0.1, 0.1, 0.2, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);
uniform float corner_radius : hint_range(0.0, 64.0) = 18.0;
uniform float outline_width : hint_range(0.0, 16.0) = 4.0;
// Highlight band thickness (px). 0.0 disables the highlight entirely.
uniform float highlight_thickness : hint_range(0.0, 16.0) = 0.0;
uniform vec2 rect_size = vec2(300.0, 240.0);

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = UV * rect_size;
	vec2 d = abs(p - half_size) - (half_size - vec2(corner_radius));
	float outer_sdf = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - corner_radius;
	float a_outer = 1.0 - smoothstep(-0.7, 0.7, outer_sdf);
	vec4 grad = mix(top_color, bot_color, clamp(UV.y, 0.0, 1.0));
	vec4 col;
	float a_inner = 1.0 - smoothstep(-outline_width - 0.7, -outline_width + 0.7, outer_sdf);
	if (outline_width < 0.5) {
		col = grad;
	} else {
		col = mix(outline_color, grad, a_inner);
	}
	if (highlight_thickness > 0.0) {
		// Top inner highlight — band starts just below the outline ring
		// and fades down over highlight_thickness px. Masked to the body
		// interior so it never paints onto the outline or rounded corners.
		float band_start = outline_width;
		float band_end = outline_width + highlight_thickness;
		float h = 1.0 - smoothstep(band_start, band_end, p.y);
		h *= a_inner;
		col.rgb = mix(col.rgb, highlight_color.rgb, h * highlight_color.a);
	}
	col.a *= a_outer;
	COLOR = col;
}
