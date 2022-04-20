float GetLogarithmicDepth(float dist) {
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

vec4 GetWorldSpace(float depth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, depth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

#if defined NETHER_SMOKE || defined END_SMOKE || defined VOLUMETRIC_CLOUDS
float getTextureNoise(vec3 pos){
	pos *= 0.30;
	pos.xz *= 0.20;

	vec3 u = floor(pos);
	vec3 v = fract(pos);
	v = v * v * (3.0 - 2.0 * v);

	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord = uv / 64.0;
	float a = texture2D(noisetex, coord).r;
	float b = texture2D(noisetex, coord + 0.25).r;
		
	return mix(a, b, v.y);
}

float getFBM(vec3 pos, vec3 wind){
	pos *= SMOKE_FREQUENCY;

	float noise = getTextureNoise(pos * 1.000 - wind * 0.2) * 0.8;
	      noise+= getTextureNoise(pos * 0.500 + wind * 0.3) * 0.9;
          noise+= getTextureNoise(pos * 0.250 - wind * 0.1) * 1.0;
          noise+= getTextureNoise(pos * 0.125 + wind * 0.4) * 1.1;

	return noise;
}

float getFogSample(vec3 pos, float height, float verticalThickness, float thicknessMult) {
	float sampleHeight = pow(abs(height - pos.y) / verticalThickness, 2.0);
	vec3 wind = vec3(frametime * SMOKE_SPEED, 0.0, 0.0);

	pos *= 0.25;

	float noise = getFBM(pos, wind);
	noise *= thicknessMult;
	noise = clamp(noise * 0.6 - (1.0 + sampleHeight), 0.0, 1.0);

	return noise;
}
#endif