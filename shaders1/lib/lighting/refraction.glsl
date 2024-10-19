float GetWaterHeightMap(vec3 waterPos, vec2 offset) {
    float noise = 0.0;
    
    vec2 wind = vec2(frametime) * 0.5 * WATER_SPEED;

	waterPos.xz -= waterPos.y * 0.2;
	waterPos.xz *= 0.75;

	#if WATER_NORMALS == 1
	offset /= 256.0;
	float noiseA = texture2D(noisetex, (waterPos.xz - wind) / 256.0 + offset).g;
	float noiseB = texture2D(noisetex, (waterPos.xz + wind) / 48.0 + offset).g;
	#elif WATER_NORMALS == 2
	offset /= 256.0;
	float noiseA = texture2D(noisetex, (waterPos.xz - wind) / 256.0 + offset).r;
	float noiseB = texture2D(noisetex, (waterPos.xz + wind) / 96.0 + offset).r;
	noiseA *= noiseA; noiseB *= noiseB;
	#endif

	#if WATER_NORMALS > 0
	noise = mix(noiseA, noiseB, 0.5);
	#endif

    return noise * WATER_BUMP;
}

vec2 getRefraction(vec2 coord, vec3 waterPos, float dist, float skylight){
	float normalOffset = WATER_SHARPNESS;
	float h1 = GetWaterHeightMap(waterPos, vec2( normalOffset, 0.0));
	float h2 = GetWaterHeightMap(waterPos, vec2(-normalOffset, 0.0));
	float h3 = GetWaterHeightMap(waterPos, vec2(0.0,  normalOffset));
	float h4 = GetWaterHeightMap(waterPos, vec2(0.0, -normalOffset));

	float xDelta = (h2 - h1) / normalOffset;
	float yDelta = (h4 - h3) / normalOffset;

	vec2 noise = vec2(xDelta, yDelta);

	vec2 waveN = noise * 0.00075 * REFRACTION_STRENGTH / dist;

	return coord + waveN * skylight;
}