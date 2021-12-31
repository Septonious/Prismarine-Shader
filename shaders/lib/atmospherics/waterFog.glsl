#if (WATER_MODE == 1 || WATER_MODE == 3) && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos) {
    float clampEyeBrightness = clamp(eBS, 0.1, 1.0);
    float clampTimeBrightness = pow2(clamp(timeBrightness, 0.25, 1.0));

    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-3.0 * fog);

    #ifdef OVERWORLD
    float VoL = dot(normalize(viewPos.xyz), lightVec);
    float scattering = pow6(VoL * shadowFade * 0.5 + 0.5) * 6.0 * clampEyeBrightness;
    #endif

    vec3 waterFogColor  = waterColor.rgb * waterColor.rgb;
         waterFogColor *= clampEyeBrightness;
         #ifdef OVERWORLD
         waterFogColor *= (1.0 + scattering) * (1.00 - rainStrength * 0.75) * (1.00 + timeBrightness);
         #endif
         waterFogColor *= 1.0 - blindFactor;

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * shadowFade * clampTimeBrightness;
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