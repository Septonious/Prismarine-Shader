vec4 DistortShadow(vec4 shadowpos, float distortFactor) {
	shadowpos.xy *= 1.0 / distortFactor;
	shadowpos.z = shadowpos.z * 0.2;
	shadowpos = shadowpos * 0.5 + 0.5;

	return shadowpos;
}

vec4 GetShadowSpace(vec4 wpos) {
	wpos = shadowModelView * wpos;
	wpos = shadowProjection * wpos;
	wpos /= wpos.w;
	
	float distb = sqrt(wpos.x * wpos.x + wpos.y * wpos.y);
	float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
	wpos = DistortShadow(wpos, distortFactor);
	
	return wpos;
}

//Light shafts from Robobo1221 (modified)
vec3 GetLightShafts(vec3 viewPos, float pixeldepth0, float pixeldepth1, vec3 color, float dither) {
	vec3 vl = vec3(0.0);

	vec2 scaledCoord = texCoord * (1.0 / VOLUMETRICS_RENDER_RESOLUTION);

	#ifdef TAA
	dither = fract(dither + frameCounter / 32.0);
	#endif

	#ifdef OVERWORLD
	float visfactor = 0.05 * (-0.8 * timeBrightness + 1.0);
	float invvisfactor = 1.0 - visfactor;

	float visibility = 1.0;
	visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
	visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
	visibility = mix(1.0, visibility, 0.25 * eBS + 0.75);
	visibility *= clamp(cameraPosition.y * 0.01, 0.0, 1.0);
	visibility *= (1.0 - rainStrength) * (1.0 - timeBrightness) * (1.0 - moonVisibility);
	visibility = clamp(visibility + isEyeInWater, 0.0, 1.0);
	#endif

	if (visibility > 0.0 && clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RENDER_RESOLUTION + 1e-3)) == texCoord) {
		float minDistFactor = LIGHTSHAFT_MIN_DISTANCE;
		float maxDist = LIGHTSHAFT_MAX_DISTANCE;

		float depth0 = GetLinearDepth2(pixeldepth0);
		float depth1 = GetLinearDepth2(pixeldepth1);

		vec4 worldposition = vec4(0.0);
		vec4 shadowposition = vec4(0.0);
		
		vec3 watercol = mix(vec3(1.0),
							waterColor.rgb / (waterColor.a * waterColor.a),
							pow(waterAlpha, 0.25));
		watercol.g *= 0.5;
		
		for(int i = 0; i < LIGHTSHAFT_SAMPLES; i++) {
			float minDist = minDistFactor * (i + dither) * (1.0 - isEyeInWater * 0.75);

			if (depth1 < minDist || minDist >= maxDist || (depth0 < minDist && color == vec3(0.0)) || isEyeInWater > 1.0) {
				break;
			}

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), scaledCoord);
			shadowposition = GetShadowSpace(worldposition);
			shadowposition.z += 0.0512 / shadowMapResolution;

			if (length(shadowposition.xy * 2.0 - 1.0) < 1.0) {
				float shadow0 = shadow2D(shadowtex0, shadowposition.xyz).z;
				
				vec3 shadowCol = vec3(0.0);
				#ifdef SHADOW_COLOR
				if (shadow0 < 1.0) {
					float shadow1 = shadow2D(shadowtex1, shadowposition.xyz).z;
					if (shadow1 > 0.0) {
						shadowCol = texture2D(shadowcolor0, shadowposition.xy).rgb;
						shadowCol *= shadowCol * shadow1;
					}
				}
				#endif

				vec3 shadow = clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));

				if (depth0 < minDist) shadow *= color;
				else if (isEyeInWater == 1.0) shadow *= watercol * 256.0 * (0.5 + eBS) * (0.05 + timeBrightness * 0.95);
				
				#ifdef LIGHTSHAFT_CLOUDY_NOISE
				if (isEyeInWater == 0){
					float noise = getFogSample(worldposition.xyz + cameraPosition.xyz, LIGHTSHAFT_HEIGHT, 64.0, 1.2);
					shadow *= noise;
				}
				#endif

				vl += shadow;
			}
		}
		
		#if MC_VERSION >= 11800
		vl *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
		#else
		vl *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
		#endif
		
		#ifdef UNDERGROUND_SKY
		vl *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
		#endif

		vl = sqrt(vl * visibility);
	}
	
	return vl;
}