float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getCloudSample(vec3 pos){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = VCLOUDS_AMOUNT * (0.90 + rainStrength * 0.40);

	float noiseA = 0.0;
	float frequency = 0.25, speed = 0.5;
	for (int i = 1; i <= VCLOUDS_OCTAVES; i++){
		noiseA += getTextureNoise(pos * frequency - wind * speed) * i * VCLOUDS_HORIZONTAL_THICKNESS * (3.0 - VCLOUDS_OCTAVES * 0.5);
		frequency *= VCLOUDS_FREQUENCY;
		speed *= 0.2;
	}

	float sampleHeight = abs(VCLOUDS_HEIGHT - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	noiseA -= getTextureNoise(pos * 0.75 - wind * speed) * 1.5;

	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

vec4 getVolumetricCloud(vec3 viewPos, float z1, float z0, float dither, vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	vec2 scaledCoord = texCoord * (1.0 / VOLUMETRICS_RENDER_RESOLUTION);

	#ifdef TAA
	dither = fract(16.0 * frameTimeCounter + dither);
	#endif

	float ug = mix(clamp((cameraPosition.y - 64.0) / 16.0, 0.0, 1.0), 1.0, eBS);

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

	#if MC_VERSION >= 11800
	float altitudeFactor = clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	float altitudeFactor = clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	if (clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RENDER_RESOLUTION + 1e-3)) == texCoord && eBS > 0.1){
		for (int i = 0; i < VCLOUDS_SAMPLES; i++) {
			float minDist = (i + dither) * VCLOUDS_RANGE;

			if (depth1 < minDist || minDist > 1024.0 || finalColor.a > 0.99 || isEyeInWater > 0.0 || ug == 0){
				break;
			}
			
			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), scaledCoord);

			if (length(wpos.xz) < 1024.0){
				#ifdef WORLD_CURVATURE
				if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
				else break;
				#endif

				wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

				//Cloud noise
				float noise = getCloudSample(wpos.xyz);

				//Find the lower and upper parts of the cloud
				float sampleHeightFactor = smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noise, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noise, wpos.y);

				vec3 cloudLighting = mix(lightCol, ambientCol, sampleHeightFactor);

				vec4 cloudsColor = vec4(cloudLighting, noise);
					 cloudsColor.rgb *= cloudsColor.a;

				finalColor += cloudsColor * (1.0 - finalColor.a);

				//Translucency blending, works half correct
				if (depth0 < minDist){
					cloudsColor *= translucent;
					finalColor *= translucent;
				}
			}
		}
	}
	
	return finalColor * altitudeFactor;
}