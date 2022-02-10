float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getPerlinNoise(vec3 pos){
	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = v * v * (3.0 - 2.0 * v);
	u.y *= 32.0;

	float noisebdl = GetNoise(u.xz + u.y);
	float noisebdr = GetNoise(u.xz + u.y + vec2(1.0, 0.0));
	float noisebul = GetNoise(u.xz + u.y + vec2(0.0, 1.0));
	float noisebur = GetNoise(u.xz + u.y + vec2(1.0, 1.0));
	float noisetdl = GetNoise(u.xz + u.y + 32.0);
	float noisetdr = GetNoise(u.xz + u.y + 32.0 + vec2(1.0, 0.0));
	float noisetul = GetNoise(u.xz + u.y + 32.0 + vec2(0.0, 1.0));
	float noisetur = GetNoise(u.xz + u.y + 32.0 + vec2(1.0, 1.0));

	float noise = mix(mix(mix(noisebdl, noisebdr, v.x), mix(noisebul, noisebur, v.x), v.z), mix(mix(noisetdl, noisetdr, v.x), mix(noisetul, noisetur, v.x), v.z), v.y);

	return noise;
}

float getCloudSample(vec3 pos){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = VCLOUDS_AMOUNT * (0.90 + rainStrength * 0.50);

	float noiseA = 0.0;
	float frequency = 0.15, speed = 0.5;
	for (int i = 1; i <= VCLOUDS_OCTAVES; i++){
		noiseA += getPerlinNoise(pos * frequency - wind * speed) * i * VCLOUDS_HORIZONTAL_THICKNESS;
		frequency *= VCLOUDS_FREQUENCY;
		speed *= 0.2;
	}

	float sampleHeight = abs(VCLOUDS_HEIGHT - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	float noiseB = clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
	float density = pow(smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noiseB, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noiseB, pos.y), 0.25);
	sampleHeight = pow(sampleHeight, 8.0 * pow2(1.0 - density * 0.85));

	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

vec4 getVolumetricCloud(vec3 viewPos, float z1, float z0, float dither, vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	vec2 scaledCoord = texCoord * (1.0 / VOLUMETRICS_RENDER_RESOLUTION);

	#ifdef TAA
	dither = fract(dither + frameCounter / 32.0);
	#endif

	float VoL = clamp(dot(normalize(viewPos.xyz), sunVec), 0.0, 1.0);
	float scattering = pow16(VoL) * (1.0 - rainStrength);
          VoL = mix(VoL, 1.0, 0.75);
          VoL = mix(VoL, 1.0, scattering);

	float cloudScattering = pow4(VoL * 0.5 + 0.5) * 0.5;

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

	#if MC_VERSION >= 11800
	float altitudeFactor = clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	float altitudeFactor = clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	float altitudeFactor2 = pow2(clamp(cameraPosition.y * 0.1, 0.0, 1.0));
	altitudeFactor2 *= clamp(eBS + 0.25, 0.0, 1.0);

	if (clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RENDER_RESOLUTION + 1e-3)) == texCoord){
		for (int i = 0; i < VCLOUDS_SAMPLES; i++) {
			float minDist = (i + dither) * VCLOUDS_RANGE;

			if (depth1 < minDist || minDist > 1024.0 || finalColor.a > 0.99 || isEyeInWater > 1.0 || altitudeFactor2 < 0.25){
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

				vec3 densityLighting = mix(lightCol, ambientCol * (1.0 + cloudScattering), noise);
				vec3 heightLighting = mix(lightCol, ambientCol, sampleHeightFactor);
				vec3 cloudLighting = sqrt(densityLighting * heightLighting);

				vec4 cloudsColor = vec4(cloudLighting, noise);
					 cloudsColor.rgb *= cloudsColor.a;

				finalColor += cloudsColor * (1.0 - finalColor.a) * (1.0 - isEyeInWater * (1.0 - eBS));

				//Translucency blending, works half correct
				if (depth0 < minDist){
					cloudsColor *= translucent;
					finalColor *= translucent;
				}
			}
		}
	}

	#if MC_VERSION >= 11800
	finalColor.rgb *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	finalColor.rgb *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif
	
	return finalColor;
}