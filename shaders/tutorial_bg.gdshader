shader_type canvas_item;

// Tutorial overlay backdrop. Two soft glows drift in opposite directions
// under a uniform translucent dim — lobby behind shows through, but the
// foreground reads cleanly. Alpha stays constant so the dim doesn't
// pulse along with the glow.

uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 0.78);
uniform vec4 glow_color : source_color = vec4(0.18, 0.36, 0.50, 1.0);
uniform float speed = 0.15;

void fragment() {
	float t = TIME * speed;
	vec2 c1 = vec2(0.30 + sin(t) * 0.22, 0.30 + cos(t * 0.7) * 0.18);
	vec2 c2 = vec2(0.72 + cos(t * 0.6) * 0.18, 0.70 + sin(t * 0.5) * 0.16);
	float d1 = distance(UV, c1);
	float d2 = distance(UV, c2);
	float g = (1.0 - smoothstep(0.0, 0.45, d1)) * 0.55
			+ (1.0 - smoothstep(0.0, 0.50, d2)) * 0.45;
	g = clamp(g, 0.0, 1.0);
	vec3 rgb = mix(base_color.rgb, glow_color.rgb, g);
	COLOR = vec4(rgb, base_color.a);
}
