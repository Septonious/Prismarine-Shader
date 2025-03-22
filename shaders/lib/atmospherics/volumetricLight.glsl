float GetLogarithmicDepth(float dist) {
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

vec4 DistortShadow(vec4 shadowpos, float distortFactor) {
	shadowpos.xy *= 1.0 / distortFactor;
	shadowpos.z = shadowpos.z * 0.2;
	shadowpos = shadowpos * 0.5 + 0.5;

	return shadowpos;
}

vec4 GetWorldSpace(float shadowdepth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, shadowdepth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

vec4 GetShadowSpace(vec4 wpos) {
	wpos = shadowModelView * wpos;
	wpos = shadowProjection * wpos;
	wpos /= wpos.w;
	
	float distb = sqrt(wpos.x * wpos.x + wpos.y * wpos.y);
	float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
	wpos = DistortShadow(wpos,distortFactor);
	
	return wpos;
}

//Light shafts from Robobo1221 (modified)
vec3 GetLightShafts(float pixeldepth0, float pixeldepth1, vec3 color, float dither) {
	vec3 vl = vec3(0.0);

	#ifdef TAA
	#if TAA_MODE == 0
	dither = fract(dither + frameCounter * 0.618);
	#else
	dither = fract(dither + frameCounter * 0.5);
	#endif
	#endif
	
	vec3 screenPos = vec3(texCoord, pixeldepth0);
	vec4 viewPos = gbufferProjectionInverse * (vec4(screenPos, 1.0) * 2.0 - 1.0);
		 viewPos /= viewPos.w;
	
	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
	float VoL = dot(normalize(viewPos.xyz), lightVec);

	#ifdef OVERWORLD
	float visfactor = mix(LIGHT_SHAFT_MORNING_FALLOFF, LIGHT_SHAFT_DAY_FALLOFF, timeBrightness);
		  visfactor = mix(LIGHT_SHAFT_NIGHT_FALLOFF, visfactor, sunVisibility);
		  visfactor*= mix(1.0, LIGHT_SHAFT_WEATHER_FALLOFF, rainStrength) * 0.1;
		  visfactor = min(visfactor, 0.999);

	float invvisfactor = 1.0 - visfactor;

	float visibility = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
		  visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
		  visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
		  visibility = mix(1.0, visibility, 0.03125 * eBS + 0.96875);
	#endif
	
	#ifdef END
	VoL = pow(VoL * 0.5 + 0.5, 16.0) * 0.75 + 0.25;
	float visibility = VoL * 4.0;
	#endif

	visibility *= 0.14285 * float(pixeldepth0 > 0.56);

	if (visibility > 0.0) {
		float maxDist = 196.0;
		
		float depth0 = GetLinearDepth2(pixeldepth0);
		float depth1 = GetLinearDepth2(pixeldepth1);
		vec4 worldposition = vec4(0.0);
		vec4 shadowposition = vec4(0.0);
		
		vec3 watercol = mix(vec3(1.0),
							waterColor.rgb / (waterColor.a * waterColor.a),
							pow(waterAlpha, 0.25));
		
		for(int i = 0; i < 7; i++) {
			float minDist = (i + dither) * 14.0;
			if (minDist >= maxDist) break;

			if (depth1 < minDist || (depth0 < minDist && color == vec3(0.0))) {
				break;
			}

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);
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
						#ifdef WATER_CAUSTICS
						shadowCol *= 16.0 - 15.0 * (1.0 - (1.0 - shadow0) * (1.0 - shadow0));
						#endif
					}
				}
				#endif

				shadow0 *= shadow0;
				shadowCol *= shadowCol;
				
				vec3 shadow = clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(16.0));

				if (depth0 < minDist) shadow *= color;

				#ifdef END
				vec3 npos = worldposition.xyz + cameraPosition.xyz + vec3(frametime * 4.0, 0, 0);
				float n3da = texture2D(noisetex, npos.xz / 512.0 + floor(npos.y / 3.0) * 0.35).r;
				float n3db = texture2D(noisetex, npos.xz / 512.0 + floor(npos.y / 3.0 + 1.0) * 0.35).r;
				float noise = mix(n3da, n3db, fract(npos.y / 3.0));
				noise = sin(noise * 28.0 + frametime * 4.0) * 0.25 + 0.5;
				shadow *= noise;
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
		if(dot(vl, vl) > 0.0) vl += (dither - 0.25) / 128.0;
	}
	
	#ifdef OVERWORLD
	if (isEyeInWater == 0) vl *= pow(lightCol, vec3(1.0 - VoL * 0.25));
	else vl *= waterColorSqrt.rgb * 8.0;
	#endif

	return vl;
}