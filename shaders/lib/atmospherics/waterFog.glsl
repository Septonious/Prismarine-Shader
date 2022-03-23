#if (WATER_MODE == 1 || WATER_MODE == 3) && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos) {
    float clampEyeBrightness = clamp(eBS, 0.75, 1.0);

    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-2.0 * fog);

    #ifdef OVERWORLD
    float VoL = clamp(dot(normalize(viewPos.xyz), sunVec), 0.0, 1.0);
	float scattering = 1.0 + pow(VoL, 6.0) * 3.0 * eBS;
    #endif

    vec3 waterFogColor  = waterColor.rgb * waterColor.rgb;
         #ifdef OVERWORLD
         waterFogColor *= clamp(max(pow2(timeBrightness) * 0.6, 0.1) + moonVisibility * 0.4, 0.0, 1.0);
         waterFogColor  = mix(waterFogColor, sqrt(waterFogColor) * weatherCol.rgb * 0.25, rainStrength);
         waterFogColor *= scattering;
         #else
         waterFogColor * 0.25;
         #endif
         waterFogColor *= clampEyeBrightness;
         waterFogColor *= 1.0 - blindFactor;

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * max(0.25, shadowFade);
    #endif

    #ifdef NETHER
    vec3 waterFogTint = netherCol.rgb;
    #endif

    #ifdef END
    vec3 waterFogTint = endCol.rgb;
    #endif

    waterFogTint = sqrt(waterFogTint * length(waterFogTint));

    return vec4(waterFogColor * waterFogTint, fog);
}