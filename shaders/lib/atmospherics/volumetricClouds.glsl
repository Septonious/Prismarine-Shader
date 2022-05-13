float getCloudSample(vec3 pos){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = VCLOUDS_AMOUNT * (1.0 + rainStrength * 0.4);

	float noise  = getTextureNoise(pos * 0.20 + wind * 0.5) * 2.0;
		  noise += getTextureNoise(pos * 0.10 + wind * 0.4) * 3.0;
		  noise += getTextureNoise(pos * 0.05 + wind * 0.3) * 4.0;

	noise *= VCLOUDS_HORIZONTAL_THICKNESS;

	float sampleHeight = abs(VCLOUDS_HEIGHT - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	noise -= getTextureNoise(pos) * 1.5;

	return clamp(noise * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

vec4 getVolumetricCloud(vec3 viewPos, float z1, float z0, vec2 texCoord, float dither, vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	#ifdef TAA
	dither = fract(dither + 0.6180339887498967 * (frameCounter & 127));
	#endif

	float ug = mix(clamp((cameraPosition.y - 64.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	float minDistFactor = (176.0 / VCLOUDS_SAMPLES * sqrt(far / 256.0)) * VCLOUDS_RANGE;

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

	if (eBS > 0.1 && ug != 0 && isEyeInWater == 0.0){
		for (int i = 0; i < VCLOUDS_SAMPLES; i++) {
			float minDist = (i + dither) * minDistFactor;
		
			if (depth1 < minDist){
				break;
			}
			
			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord);

			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			wpos.xyz += cameraPosition.xyz;

			float noise = getCloudSample(wpos.xyz);
			float heightFactor = smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noise, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noise, wpos.y);

			vec4 cloudsColor = vec4(mix(lightCol, ambientCol, heightFactor), noise);
				 cloudsColor.rgb *= cloudsColor.a;

			finalColor += cloudsColor * (1.0 - finalColor.a);
		}
	}
	
	return finalColor;
}