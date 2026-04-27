shader_type canvas_item;

// Animated slanted highlight that only shows over non-transparent
// pixels of the underlying texture. Used on machine_card's TextureRect
// so the shimmer is clipped by the PNG's alpha mask exactly.

uniform float sweep_duration : hint_range(0.2, 4.0) = 1.0;
uniform float pause_duration : hint_range(0.0, 30.0) = 10.2;
uniform float band_width : hint_range(0.01, 0.4) = 0.08;
uniform float skew : hint_range(0.0, 1.5) = 0.6;
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float shimmer_time = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float cycle = sweep_duration + pause_duration;
	float t_abs = mod(shimmer_time, cycle);
	float sweep_t = t_abs / sweep_duration;
	float shimmer = 0.0;
	if (sweep_t <= 1.0) {
		float cx = mix(-0.3, 1.3, sweep_t);
		float band_x = cx - UV.y * skew;
		float dist = abs(UV.x - band_x);
		shimmer = max(0.0, 1.0 - dist / band_width) * shimmer_color.a;
	}
	// Clip by PNG alpha — shimmer only on visible artwork.
	COLOR = vec4(base.rgb + shimmer_color.rgb * shimmer * base.a, base.a);
}
