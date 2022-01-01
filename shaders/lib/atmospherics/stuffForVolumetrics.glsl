float GetLogarithmicDepth(float dist) {
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

vec4 GetWorldSpace(float shadowdepth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, shadowdepth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

float InterleavedGradientNoiseVL() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);

	return fract(n);
}

#if defined LIGHTSHAFT_CLOUDY_NOISE || defined NETHER_SMOKE || defined END_SMOKE
float getFogNoise(vec3 pos) {
	pos /= 12.0;
	pos.xz *= 0.25;

	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = (v * v) * (3.0 - 2.0 * v);
	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord = uv / 64.0;
	float a = texture2DLod(noisetex, coord, 4.0).r * LIGHTSHAFT_HORIZONTAL_THICKNESS;
	float b = texture2DLod(noisetex, coord + 0.25, 4.0).r * LIGHTSHAFT_HORIZONTAL_THICKNESS;
		
	return mix(a, b, v.y);
}

float getFogSample(vec3 pos, float height, float verticalThickness){
	float sampleHeight = pow(abs(height - pos.y) / verticalThickness, 2.0);
	vec3 wind = vec3(frametime * 0.25, 0.0, 0.0);

	float noise = getFogNoise(pos * 3.000 - wind * 0.30);
		  noise+= getFogNoise(pos * 1.500 + wind * 0.25);
          noise+= getFogNoise(pos * 0.750 - wind * 0.20);
          noise+= getFogNoise(pos * 0.325 + wind * 0.15);

	#ifdef END
	noise *= 1.1;
	#endif

	noise = clamp(noise * 0.75 - (1.0 + sampleHeight), 0.0, 1.0);

	return noise;
}
#endif