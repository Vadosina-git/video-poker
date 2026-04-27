shader_type canvas_item;

// Adds a solid outline around the silhouette of a glyph TextureRect.
// Samples the texture's alpha at 8 neighbour offsets (radius =
// outline_size px in TEXTURE_PIXEL_SIZE units) — wherever any neighbour
// is opaque but the current pixel isn't, the outline color is drawn.
//
// `body_color` multiplies the texture's RGB (acts like a tint) — passing
// white preserves the SVG's native colors, which is essential for
// multi-color glyphs like the chip (yellow body + dark "C" letter).
// Modulate-based tinting can't be used because Godot would also tint
// the outline; the shader instead applies the body tint internally and
// leaves outline_color untouched. TextureRect.modulate must stay white.

uniform vec4 body_color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_size : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec2 ts = TEXTURE_PIXEL_SIZE * outline_size;
	vec4 base = texture(TEXTURE, UV);

	float ring_a = 0.0;
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(ts.x, 0.0)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(-ts.x, 0.0)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(0.0, ts.y)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(0.0, -ts.y)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(ts.x, ts.y)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(-ts.x, ts.y)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(ts.x, -ts.y)).a);
	ring_a = max(ring_a, texture(TEXTURE, UV + vec2(-ts.x, -ts.y)).a);

	// Body keeps the texture's native RGB (multi-color chip glyph stays
	// multi-colored) but tinted by body_color. Outline is the silhouette
	// of the dilated mask, painted underneath the body.
	vec3 body_rgb = base.rgb * body_color.rgb;
	vec3 col = mix(outline_color.rgb, body_rgb, base.a);
	float a = max(base.a * body_color.a, ring_a * outline_color.a);
	COLOR = vec4(col, a);
}
