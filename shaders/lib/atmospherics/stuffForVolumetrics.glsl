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

#if defined LIGHTSHAFT_CLOUDY_NOISE || defined NETHER_SMOKE || defined END_SMOKE || defined VOLUMETRIC_CLOUDS
uniform sampler2D depthtex2;

float InterleavedGradientNoiseVL() {
    float noise = texelFetch2D(depthtex2, ivec2(gl_FragCoord.xy) & 255, 0).r;
    noise = fract(noise);

    return noise;
}

float getCloudNoise(vec3 pos){
	pos *= 0.35;
	pos.xz *= 0.25;

	#ifdef END
	pos.xz *= 0.5;
	#endif

	vec3 u = floor(pos);
	vec3 v = fract(pos);
	v = v * v * (3.0 - 2.0 * v);

	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord = uv / 64.0;
	float a = texture2D(noisetex, coord).r;
	float b = texture2D(noisetex, coord + 0.25).r;
		
	return mix(a, b, v.y);
}

float getFogSample(vec3 pos, float height, float verticalThickness, float thicknessMult) {
	float sampleHeight = pow(abs(height - pos.y) / verticalThickness, 2.0);
	vec3 wind = vec3(frametime, 0.0, 0.0);

	#ifdef OVERWORLD
	wind *= 0.5;
	#endif

	pos *= 0.1;

	#ifdef END
	pos *= 3.0;
	#endif

	#ifdef NETHER
	pos *= 4.0;
	#endif

	float noise = getCloudNoise(pos * 1.000 - wind * 0.2);
		  noise+= getCloudNoise(pos * 0.500 + wind * 0.3);
          noise+= getCloudNoise(pos * 0.250 - wind * 0.1);
          noise+= getCloudNoise(pos * 0.125 + wind * 0.4);

	noise *= thicknessMult;

	noise = clamp(noise * 0.6 - (1.0 + sampleHeight), 0.0, 1.0);

	return noise;
}
#endif