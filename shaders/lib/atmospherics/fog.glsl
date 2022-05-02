#ifdef OVERWORLD
vec3 GetFogColor(vec3 viewPos) {
	vec3 nViewPos = normalize(viewPos);

    float VoU = -(clamp(dot(nViewPos, upVec), -1.0, 1.0) * 0.5 + 0.5);
	float VoL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
    
    float exposure = exp2(timeBrightness * 0.75 - 1.00);
    float nightExposure = exp2(-3.5);

	float baseGradient = exp(VoU / 0.4125);
	float ug = mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);

	vec3 skyColor = GetSkyColor(viewPos, false) * (1.0 + VoL);
	vec3 fog = skyColor * (4.0 - timeBrightness) * baseGradient / SKY_I;

    fog = fog * exposure * sunVisibility * SKY_I;

	float nightGradient = exp(VoU * 0.5 / 0.6125);
    vec3 nightFog = lightNight * lightNight * 8.0 * nightGradient * nightExposure;
    fog = mix(nightFog, fog, sunVisibility * sunVisibility);

    float rainGradient = exp(VoU * 0.25);
    vec3 weatherFog = weatherCol.rgb * GetLuminance(ambientCol / (weatherCol.rgb)) * (0.4 * sunVisibility + 0.2);
    fog = mix(fog, weatherFog * rainGradient, rainStrength);

	return fog;
}
#endif

uniform sampler2D colortex9;

void NormalFog(inout vec3 color, vec3 viewPos) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	worldPos.xyz /= worldPos.w;

	float lViewPos = length(viewPos);

	#if DISTANT_FADE > 0
	#if DISTANT_FADE_STYLE == 0
	float fogFactor = lViewPos;
	#else
	float fogFactor = length(worldPos.xz);
	#endif
	#endif
	
	#ifdef OVERWORLD
    float ug = mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	float density = ug * FOG_DENSITY * (1.0 + rainStrength);
	float fog = lViewPos * density / 256.0;
	float clearDay = sunVisibility * (1.0 - rainStrength);
	fog *= mix(1.0, (0.5 * rainStrength + 1.0) / (4.0 * clearDay + 1.0), eBS);
	fog = 1.0 - exp(-2.0 * pow(fog, 0.05 * clearDay + 1.35));

	vec3 pos = worldPos.xyz + cameraPosition.xyz;
	float worldHeightFactor = clamp(pos.y * 0.008, 0.0, 1.0);
	fog *= 1.0 - worldHeightFactor;

	vec3 fogColor = GetFogColor(viewPos);

	#if DISTANT_FADE == 1 || DISTANT_FADE == 3
	if (isEyeInWater == 0){
		float vanillaFog = 1.0 - (far - fogFactor) / (far * 0.25);
		vanillaFog = clamp(vanillaFog, 0.0, 1.0);
	
		if (vanillaFog > 0.0){
			vec3 vanillaFogColor = texture2D(colortex9, texCoord).rgb;
			fogColor *= fog;
			
			fog = mix(fog, 1.0, vanillaFog);
			if (fog > 0.0) fogColor = mix(fogColor, vanillaFogColor, vanillaFog) / fog;
		}
	}
	#endif
	#endif

	#ifdef NETHER
	vec3 fogColor = netherCol.rgb * 0.04;
	float fog = 2.0 * pow(lViewPos * FOG_DENSITY / 256.0, 1.5);

	#if DISTANT_FADE == 2 || DISTANT_FADE == 3
	fog += 6.0 * pow4(fogFactor * 1.5 / far);
	#endif

	fog = 1.0 - exp(-fog);
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
	vec3(0.1, 0.14, 0.24) * 0.5
);

void DenseFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * 0.5;
	fog = (1.0 - exp(-4.0 * fog * fog * fog));

	vec3 denseFogColor0 = denseFogColor[isEyeInWater - 2];

	#ifdef OVERWORLD
	denseFogColor0 *- clamp(timeBrightness, 0.01, 1.0);
	#endif

	color = mix(color, denseFogColor0, fog);
}

void Fog(inout vec3 color, vec3 viewPos) {
	if (isEyeInWater == 0) NormalFog(color, viewPos);
	if (isEyeInWater > 1) DenseFog(color, viewPos);
	if (blindFactor > 0.0) BlindFog(color, viewPos);
}
