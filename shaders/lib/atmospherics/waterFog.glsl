#if (WATER_MODE == 1 || WATER_MODE == 3) && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos) {
    float clampEyeBrightness = pow2(clamp(eBS, 0.25, 1.0));

    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-2.0 * fog);

    vec3 waterFogColor  = waterColor.rgb * waterColor.rgb * 0.25;
         waterFogColor *= clampEyeBrightness;
         #ifdef OVERWORLD
         waterFogColor  = mix(waterFogColor, weatherCol.rgb * 0.05 * clampEyeBrightness, rainStrength);
         #endif
         waterFogColor *= 1.0 - blindFactor;

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * shadowFade;
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