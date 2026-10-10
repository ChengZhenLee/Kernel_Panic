shader_type canvas_item;
// Cheap CRT look: scanlines, a soft vignette and a slow rolling bar.
uniform float scanline_strength = 0.16;
uniform float vignette_strength = 0.5;

void fragment() {
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * 360.0 * 6.28318);
	float roll = smoothstep(0.0, 0.08, abs(fract(uv.y - TIME * 0.07) - 0.5)) ;
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.35, 0.85, d) * vignette_strength;
	float a = (1.0 - scan) * scanline_strength + vig + (1.0 - roll) * 0.04;
	COLOR = vec4(0.0, 0.01, 0.02, clamp(a, 0.0, 1.0));
}
