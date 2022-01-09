float getCloudSample(vec3 pos, float height){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = VCLOUDS_AMOUNT * (0.85 + rainStrength * 0.15);
	
	float noiseA = 0.0;
	float mult = 1.0;
	for (int i = 1; i <= VCLOUDS_OCTAVES; i++){
		noiseA += getCloudNoise(pos * (mult * mult * VCLOUDS_DETAIL) - wind * mult) * i * VCLOUDS_HORIZONTAL_THICKNESS;
		mult *= 0.5;
	}

	float sampleHeight = abs(height - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	float noiseB = clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
	float density = pow(smoothstep(height + VCLOUDS_VERTICAL_THICKNESS * noiseB, height - VCLOUDS_VERTICAL_THICKNESS * noiseB, pos.y), 0.25);
	sampleHeight = pow(sampleHeight, 8.0 * (1.5 - density) * (1.5 - density));

	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

vec4 getVolumetricCloud(in vec3 viewPos, in float z1, in float z0, in float dither, in vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	#ifdef TAA
	dither = fract(dither + frameCounter / 32.0);
	#endif

	float VoL = dot(normalize(viewPos.xyz), lightVec);
	float halfVoL = VoL * shadowFade * 0.5 + 0.5;
	float scattering = pow6(halfVoL) * (1.0 - rainStrength);

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

	float height = VCLOUDS_HEIGHT * (1.0 + rainStrength * 0.25);

	for (int i = 0; i < VCLOUDS_SAMPLES; i++) {
		float minDist = (i + dither) * VCLOUDS_RANGE;

		if (depth1 < minDist || isEyeInWater == 1.0 || minDist > 1024.0){
			break;
		}
		
		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord);

		if (length(wpos.xz) < 1024.0){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

			float noise = getCloudSample(wpos.xyz, height);

			//Find the lower and upper parts of the cloud
			float density = pow(smoothstep(height + VCLOUDS_VERTICAL_THICKNESS * noise, height - VCLOUDS_VERTICAL_THICKNESS * noise, wpos.y), 0.4);

			//Color calculation and lighting
			vec4 cloudsColor = vec4(mix(lightCol, ambientCol, noise * density) * (1.0 + scattering), noise);
			cloudsColor.a *= VCLOUDS_OPACITY;
			cloudsColor.rgb *= cloudsColor.a;

			#if MC_VERSION >= 11800
			cloudsColor.rgb *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
			#else
			cloudsColor.rgb *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
			#endif

			//Translucency blending, works half correct
			if (depth0 < minDist){
				cloudsColor *= translucent;
			}

			finalColor += cloudsColor * (1.0 - finalColor.a);
		}
	}

	return max(finalColor, vec4(0.0));
}