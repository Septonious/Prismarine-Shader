float getCloudSample(vec3 pos, float height){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = 0.75 * (1.25 - timeBrightness * 0.25) * (0.8 + rainStrength * 0.1);
	
	float noiseA = getCloudNoise(pos * VCLOUDS_DETAIL * 0.500000 - wind * 0.5) * 2.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos * VCLOUDS_DETAIL * 0.250000 - wind * 0.4) * 3.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos * VCLOUDS_DETAIL * 0.125000 - wind * 0.3) * 4.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos * VCLOUDS_DETAIL * 0.062500 - wind * 0.2) * 5.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos * VCLOUDS_DETAIL * 0.031250 - wind * 0.1) * 6.0 * VCLOUDS_HORIZONTAL_THICKNESS;

	float sampleHeight = abs(height - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	float noiseB = clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
	float density = pow(smoothstep(height + VCLOUDS_VERTICAL_THICKNESS * noiseB, height - VCLOUDS_VERTICAL_THICKNESS * noiseB, pos.y), 0.25);
	sampleHeight = pow(sampleHeight, 8.0 * (1.5 - density) * (1.5 - density));

	//Output
	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

void getVolumetricCloud(in float pixeldepth1, in float pixeldepth0, in float dither, in float scattering, inout vec3 color, in vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	float depth0 = GetLinearDepth2(pixeldepth0);
	float depth1 = GetLinearDepth2(pixeldepth1);

	float maxDist = 512.0 * VCLOUDS_RANGE;
	float minDist = 0.01 + (dither * VCLOUDS_QUALITY);

	float rainFactor = (1.0 - rainStrength * 0.4);

	for (minDist; minDist < maxDist; minDist += VCLOUDS_QUALITY) {
		if (depth1 < minDist || isEyeInWater == 1){
			break;
		}
		
		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.xy);

		if (length(wpos.xz) < maxDist){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

			float height = VCLOUDS_HEIGHT * (1.0 + rainStrength * 0.2);
			float noise = getCloudSample(wpos.xyz, height);

			//Find the lower and upper parts of the cloud
			float density = pow(smoothstep(height + VCLOUDS_VERTICAL_THICKNESS * noise, height - VCLOUDS_VERTICAL_THICKNESS * noise, wpos.y), 0.4);

			//Color calculation and lighting
			vec4 cloudsColor = vec4(mix(lightCol * (1.0 + scattering), ambientCol, noise * density), noise);
			cloudsColor.rgb *= cloudsColor.a * VCLOUDS_OPACITY * isEyeInCave;

			//Translucency blending, works half correct
			if (depth0 < minDist){
				cloudsColor *= translucent;
				finalColor *= translucent;
			}

			finalColor += cloudsColor * (1.0 - finalColor.a);
		}

	}

	finalColor *= isEyeInCave * isEyeInCave * isEyeInCave;

	//Output
	color = mix(color, finalColor.rgb * rainFactor, finalColor.a);
}