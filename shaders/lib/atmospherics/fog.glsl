#ifdef OVERWORLD
#if MC_VERSION >= 11800
float altitudeFactor = clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
#else
float altitudeFactor = clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
#endif

vec3 GetFogColor(vec3 viewPos) {
	vec3 nViewPos = normalize(viewPos);

    float VoU = clamp(dot(nViewPos, upVec), -1.0, 1.0);
	float VoL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
	
	float density = 0.50;
    float nightDensity = 0.75;
    float weatherDensity = exp2(1.0);
    
    float exposure = exp2(timeBrightness * 0.75 - 1.00);
    float nightExposure = exp2(-3.5);

	float baseGradient = exp(-(VoU * 0.5 + 0.5) * 0.5 / density);
	float ug = mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	float ug2 = mix(clamp((cameraPosition.y - 32.0) / 16.0, 0.0, 1.0), 1.0, eBS);

	vec3 skyColor = GetSkyColor(viewPos, false);
	vec3 fogColor = skyCol;

	#ifdef FOG_PERBIOME
	fogColor = getBiomeFog(skyCol);
	#endif

	fogColor = mix(sqrt(skyColor), fogColor, max(timeBrightness - eBS, 0.0) * 0.5);

	vec3 fog = fogColor * (4.0 - timeBrightness) * baseGradient / SKY_I;

    fog = fog * exposure * sunVisibility * SKY_I * (1.0 + (VoL * 0.5 + 0.5));

	float nightGradient = exp(-(VoU * 0.5 + 0.5) * 0.35 / nightDensity);
    vec3 nightFog = lightNight * lightNight * 6.0 * nightGradient * nightExposure;
    fog = mix(nightFog, fog, sunVisibility * sunVisibility);

    float rainGradient = exp(-(VoU * 0.5 + 0.5) * 0.25 / weatherDensity);
    vec3 weatherFog = weatherCol.rgb * weatherCol.rgb;
    weatherFog *= GetLuminance(ambientCol / (weatherFog)) * (0.4 * sunVisibility + 0.2);
    fog = mix(fog, weatherFog * rainGradient, rainStrength);

	fog = mix(minLightCol, fog, ug2);

	return fog;
}
#endif

void NormalFog(inout vec3 color, vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	worldPos.xyz /= worldPos.w;

	#if DISTANT_FADE > 0
	#if DISTANT_FADE_STYLE == 0
	float fogFactor = length(viewPos);
	#else
	float fogFactor = length(worldPos.xz);
	#endif
	#endif
	
	#ifdef OVERWORLD
	float density = (0.25 + eBS * 0.75) * altitudeFactor * FOG_DENSITY * (1.0 + rainStrength) * (1.0 - sunVisibility * 0.5);
	float fog = length(viewPos) * density / 256.0;
	float clearDay = sunVisibility * (1.0 - rainStrength);
	fog *= mix(1.0, (0.5 * rainStrength + 1.0) / (4.0 * clearDay + 1.0), eBS);
	fog = 1.0 - exp(-2.0 * pow(fog, 0.05 * clearDay + 1.35));

	vec3 pos = worldPos.xyz + cameraPosition.xyz;
	float worldHeightFactor = clamp(pos.y * 0.008, 0.0, 1.0);
	fog *= 1.0 - worldHeightFactor;

	vec3 fogColor = GetFogColor(viewPos);

	#if DISTANT_FADE == 1 || DISTANT_FADE == 3
	if(isEyeInWater == 0.0){
		#if MC_VERSION >= 11800
		float fogOffset = 0.0;
		#else
		float fogOffset = 12.0;
		#endif

		float vanillaFog = 1.0 - (far - (fogFactor + fogOffset)) / (FOG_DENSITY * 0.25 * far);
		vanillaFog = clamp(vanillaFog, 0.0, 1.0);
	
		if (vanillaFog > 0.0){
			vec3 vanillaFogColor = GetSkyColor(viewPos, false);
			vanillaFogColor *= 1.0 + nightVision;

			fogColor *= fog;
			
			fog = mix(fog, 1.0, vanillaFog);
			if (fog > 0.0) fogColor = mix(fogColor, vanillaFogColor, vanillaFog) / fog;
		}
	}
	#endif
	#endif

	#ifdef NETHER
	float viewLength = length(viewPos);
	float fog = 2.0 * pow(viewLength * FOG_DENSITY / 256.0, 1.5);
	#if DISTANT_FADE == 2 || DISTANT_FADE == 3
	fog += 6.0 * pow4(fogFactor * 1.5 / far);
	#endif
	fog = 1.0 - exp(-fog);
	vec3 fogColor = netherCol.rgb * 0.04;
	#endif
	
	#ifndef END
	color = mix(color, fogColor, fog);
	#endif
}

void BlindFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * (blindFactor * 0.2);
	fog = (1.0 - exp(-6.0 * fog * fog * fog)) * blindFactor;
	color = mix(color, vec3(0.0), fog);
}

vec3 denseFogColor[2] = vec3[2](
	vec3(1.0, 0.3, 0.01),
	vec3(0.1, 0.14, 0.24)
);

void DenseFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * 0.5;
	fog = (1.0 - exp(-4.0 * fog * fog * fog));

	vec3 denseFogColor0 = denseFogColor[isEyeInWater - 2];

	#ifdef OVERWORLD
	denseFogColor0 *- clamp(timeBrightness, 0.1, 1.0);
	#endif

	color = mix(color, denseFogColor0, fog);
}

void Fog(inout vec3 color, vec3 viewPos) {
	if (isEyeInWater == 0) NormalFog(color, viewPos);
	if (isEyeInWater > 1) DenseFog(color, viewPos);
	if (blindFactor > 0.0) BlindFog(color, viewPos);
}
