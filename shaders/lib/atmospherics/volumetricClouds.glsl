float getCloudSample(vec3 pos){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = VCLOUDS_AMOUNT * (0.90 + rainStrength * 0.20);
	
	float noiseA = 0.0;
	float mult = 1.0;
	for (int i = 1; i <= VCLOUDS_OCTAVES; i++){
		noiseA += getCloudNoise(pos * (mult * mult * VCLOUDS_DETAIL) - wind * mult) * i * VCLOUDS_HORIZONTAL_THICKNESS;
		mult *= 0.5;
	}

	float sampleHeight = abs(VCLOUDS_HEIGHT - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	float noiseB = clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
	float density = pow(smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noiseB, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noiseB, pos.y), 0.25);
	sampleHeight = pow(sampleHeight, 8.0 * (1.5 - density) * (1.5 - density));

	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

vec4 getVolumetricCloud(vec3 viewPos, float z1, float z0, float dither, vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	#ifdef TAA
	dither = fract(dither + frameCounter / 32.0);
	#endif

	float VoL = dot(normalize(viewPos.xyz), lightVec);
	float halfVoL = VoL * shadowFade * 0.5 + 0.5;
	float scattering = pow6(halfVoL) * (1.0 - rainStrength) * clamp((1.0 - cameraPosition.y * 0.004), 0.0, 1.0);

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

	for (int i = 0; i < VCLOUDS_SAMPLES; i++) {
		float minDist = (i + dither) * VCLOUDS_RANGE;

		if (depth1 < minDist || minDist > 1024.0 || finalColor.a > 0.99 || isEyeInWater > 1.0){
			break;
		}
		
		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord);

		if (length(wpos.xz) < 1024.0){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

			float noise = getCloudSample(wpos.xyz);

			//Find the lower and upper parts of the cloud
			float density = pow(smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noise, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noise, wpos.y), 0.4);

			//Color calculation and lighting
			vec4 cloudsColor = vec4(mix(lightCol, ambientCol, noise * density) * (1.0 + scattering), noise);

			//Translucency blending, works half correct
			if (depth0 < minDist){
				cloudsColor *= translucent;
			}

			cloudsColor.a *= VCLOUDS_OPACITY;
			cloudsColor.rgb *= cloudsColor.a;

			#if MC_VERSION >= 11800
			cloudsColor.rgb *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
			#else
			cloudsColor.rgb *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
			#endif

			finalColor += cloudsColor * (1.0 - finalColor.a) * (1.0 - isEyeInWater * (1.0 - eBS));
		}
	}

	return max(finalColor, vec4(0.0));
}