shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.5) = 0.50;
uniform float brightness : hint_range(0.0, 1.5) = 0.65;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
uniform vec4 tint_color : source_color = vec4(0.10, 0.06, 0.03, 0.45);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	
	// Luminance for grayscale
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	
	// Apply saturation
	vec3 sat_color = mix(vec3(gray), c.rgb, saturation);
	
	// Apply contrast & brightness
	vec3 graded = (sat_color - 0.5) * contrast + 0.5;
	graded *= brightness;
	
	// Blend with warm antique tint
	vec3 tinted = mix(graded, tint_color.rgb, tint_color.a);
	
	// Vignette around edges to keep focus on UI center
	vec2 center_uv = UV - vec2(0.5);
	float dist = length(center_uv);
	float vig = smoothstep(0.2, 0.8, dist) * vignette_strength;
	tinted = mix(tinted, vec3(0.02, 0.01, 0.01), vig);
	
	COLOR = vec4(clamp(tinted, 0.0, 1.0), c.a);
}
