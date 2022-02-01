#if (WATER_MODE == 1 || WATER_MODE == 3) && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos) {
    float clampEyeBrightness = clamp(eBS, 0.25, 1.0);

    #if defined OVERWORLD || defined END
    float clampTimeBrightness = pow(clamp(timeBrightness, 0.5, 1.0), 2.0);
    #endif

    float fog = length(viewPos) / waterFogRange;

    fog = 1.0 - exp(-3.0 * fog);

    #ifdef OVERWORLD
    float VoL = dot(normalize(viewPos.xyz), lightVec);
    float scattering = (VoL * shadowFade * 0.5 + 0.5) * clampEyeBrightness;
          scattering *= scattering;
          scattering *= scattering;
    #endif

    vec3 waterFogColor  = waterColor.rgb * waterColor.rgb * 0.75;
         waterFogColor  = mix(waterFogColor, weatherCol.rgb * 0.25, rainStrength);
         waterFogColor *= clampEyeBrightness;
         #ifdef OVERWORLD
         waterFogColor *= (1.0 + scattering);
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