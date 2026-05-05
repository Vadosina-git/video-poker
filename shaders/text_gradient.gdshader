shader_type canvas_item;

// Linear top→bottom gradient for Label glyphs.
//
// UV in a canvas_item Label is the glyph-atlas UV (one quad per character),
// so it cannot drive a single label-wide gradient. Instead pass VERTEX
// (local Control coordinates, 0..size) through a varying and normalize
// against the Label height supplied as a uniform.

uniform vec4 color_top : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_bottom : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rect_height = 100.0;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp(v_local.y / max(rect_height, 1.0), 0.0, 1.0);
	vec3 grad = mix(color_top.rgb, color_bottom.rgb, t);
	COLOR = vec4(grad, tex.a * COLOR.a);
}
