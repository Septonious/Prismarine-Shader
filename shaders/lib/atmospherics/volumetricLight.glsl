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
vec3 GetLightShafts(vec3 viewPos, float z0, float z1, vec2 scaledCoord, vec3 color, float dither) {
	vec3 vl = vec3(0.0);

	#ifdef TAA
	dither = fract(dither + 0.6180339887498967 * (frameCounter & 127));
	#endif

	float visibility = (1.0 - pow2(timeBrightness) * 0.75) * (1.0 - float(cameraPosition.y < 50.0) * (1.0 - eBS));
	float ug = mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	visibility *= ug;

	if (visibility > 0.0 && clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RENDER_RESOLUTION + 1e-3)) == texCoord) {
		float minDistFactor = LIGHTSHAFT_MIN_DISTANCE * (1.0 - isEyeInWater * 0.4);
		float maxDist = LIGHTSHAFT_MAX_DISTANCE;

		float depth0 = GetLinearDepth2(z0);
		float depth1 = GetLinearDepth2(z1);

		vec4 worldposition = vec4(0.0);
		vec4 shadowposition = vec4(0.0);
		
		vec3 watercol = mix(vec3(1.0),
							waterColor.rgb / (waterColor.a * waterColor.a),
							pow(waterAlpha, 0.25));
		
		for(int i = 0; i < LIGHTSHAFT_SAMPLES; i++) {
			float minDist = (i + dither) * minDistFactor;

			if (depth1 < minDist || minDist >= maxDist || (depth0 < minDist && color == vec3(0.0)) || isEyeInWater > 1) {
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
				if (isEyeInWater == 1.0) {
					shadow.rgb *= watercol.rgb * (1.0 + 16.0 * float(depth0 > minDist));
				} else {
					vec3 fogPosition = worldposition.xyz + cameraPosition.xyz;
					float worldHeightFactor = 1.0 - clamp(sqrt(fogPosition.y * 0.001 * LIGHTSHAFT_HEIGHT), 0.0, 1.0);
					
					#ifdef LIGHTSHAFT_CLOUDY_NOISE
					vec3 npos = fogPosition * 0.75 + vec3(frametime, 0, 0);
					float n3da = texture2D(noisetex, npos.xz * 0.0001 + floor(npos.y * 0.1) * 0.05).r;
					float n3db = texture2D(noisetex, npos.xz * 0.0001 + floor(npos.y * 0.1 + 1.0) * 0.05).r;
					float noise = mix(n3da, n3db, fract(npos.y * 0.1));
					noise = sin(noise * 16.0 + frametime * 0.5) * (0.4 + rainStrength * 0.2) + (0.6 - rainStrength * 0.2);
					shadow *= noise;
					worldHeightFactor *= noise + 1.0;
					#endif

					shadow *= worldHeightFactor;
				}

				vl += shadow;
			}
		}

		vl = sqrt(vl * visibility);
	}
	
	return vl;
}