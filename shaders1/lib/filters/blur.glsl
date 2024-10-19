float pixelHeight = 1.0 / viewHeight;
float pixelWdith = 1.0 / viewWidth;

float weight[5] = float[5](1.0, 4.0, 6.0, 4.0, 1.0);

vec4 GaussianBlur(sampler2D colortex, vec2 coord, float strength) {
	vec4 blur = vec4(0.0);

	for(int i = 0; i < 5; i++) {
		for(int j = 0; j < 5; j++) {
			float wg = weight[i] * weight[j];
			vec2 pixelOffset = vec2(i * pixelWdith, j * pixelHeight) * strength;
			blur += texture2D(colortex, coord + pixelOffset) * wg;
		}
	}
	blur /= 256.0;

	return blur;
}

vec4 BoxBlur(sampler2D colortex, vec2 coord, float strength) {
	vec4 blur = vec4(0.0);

	for(int i = 0; i < 8; i++) {
		for(int j = 0; j < 8; j++) {
			vec2 pixelOffset = vec2(i * pixelWdith, j * pixelHeight) * strength;
			blur += texture2D(colortex, coord + pixelOffset);
		}
	}
	blur /= 64.0;

	return blur;
}