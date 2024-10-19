vec4 GetWaterFog(vec3 viewPos) {
    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-4.0 * fog);

    #ifdef OVERWORLD
    vec3 waterFogColor = mix(waterColor.rgb, weatherCol.rgb * 0.25, rainStrength * 0.25);
    #else
    vec3 waterFogColor = waterColor.rgb;
    #endif
         #ifdef OVERWORLD
         waterFogColor *= 0.15 + timeBrightness * 0.35;

         if (isEyeInWater == 1) {
            vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

            float VoL = dot(normalize(viewPos), lightVec) * shadowFade;
            float glare = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
                  glare = 0.01 / (1.0 - 0.99 * glare) - 0.01;
            waterFogColor *= 1.0 + glare * 24.0 * eBS * mix(0.25, 1.0, timeBrightness);
         }
         #endif

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