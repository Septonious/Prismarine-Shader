#if defined OVERWORLD || defined END
#include "/lib/lighting/shadows.glsl"
#endif

void GetLighting(inout vec3 albedo, out vec3 shadow, vec3 viewPos, vec3 worldPos,
                 vec2 lightmap, float smoothLighting, float NoL, float vanillaDiffuse,
                 float parallaxShadow, float emission, float subsurface) {
    
    #if EMISSIVE == 0 || (!defined ADVANCED_MATERIALS && EMISSIVE == 1)
    emission = 0.0;
    #endif

    #if SSS == 0 || (!defined ADVANCED_MATERIALS && SSS == 1)
    subsurface = 0.0;
    #endif

    #ifdef SSPT
    lightmap.x *= 0.5;
    #endif

    #if defined OVERWORLD || defined END
    if (NoL > 0.0 || subsurface > 0.0) shadow = GetShadow(worldPos, NoL, subsurface, lightmap.y);
    shadow *= parallaxShadow;
    NoL = clamp(NoL * 1.01 - 0.01, 0.0, 1.0);
    
    float rainFactor = 1.0 - rainStrength;

    float scattering = 0.0;
    if (subsurface > 0.0){
        float VoL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
        scattering = pow8(VoL) * rainFactor * subsurface;
        NoL = mix(NoL, 1.0, subsurface * (0.5 + pow2(VoL) * 0.5));
        NoL = mix(NoL, 1.0, scattering);
    }
    
    vec3 fullShadow = shadow * NoL;
    
    #ifdef OVERWORLD
    #ifdef AURORA
	float auroraVisibility = moonVisibility * rainFactor;

	#ifdef WEATHER_PERBIOME
	auroraVisibility *= isCold * isCold;
	#endif

    float noise1 = texture2D(noisetex, (worldPos.xz + cameraPosition.xz) * 0.00005).r * 0.25;
    auroraVisibility *= noise1;

    vec3 auroraLowColSqrt1 = vec3(AURORA_LR, AURORA_LG, AURORA_LB) * AURORA_LI / 255.0;
    vec3 auroraLowCol1 = auroraLowColSqrt1 * auroraLowColSqrt1 * 0.1;
    vec3 auroraHighColSqrt1 = vec3(AURORA_HR, AURORA_HG, AURORA_HB) * AURORA_HI / 255.0;
    vec3 auroraHighCol1 = auroraHighColSqrt1 * auroraHighColSqrt1;
    vec3 auroraColor = (auroraLowColSqrt1 + auroraHighColSqrt1 * 0.25) * 0.5;
    auroraColor *= auroraColor * auroraColor;

    lightCol += mix(vec3(0.0), auroraColor, auroraVisibility);
    ambientCol += mix(vec3(0.0), auroraColor, auroraVisibility);
    #endif

    float shadowMult = (1.0 - 0.95 * rainStrength) * shadowFade;
    vec3 sceneLighting = mix(ambientCol * max(0.1, pow4(lightmap.y)), lightCol, fullShadow * shadowMult);
    sceneLighting *= pow(lightmap.y, 8.0 - 7.0 * eBS) * (1.0 + scattering * shadow);
    #endif

    #ifdef END
    vec3 sceneLighting = endCol.rgb * (0.06 * fullShadow + 0.02);
    #endif

    #else
    vec3 sceneLighting = netherColSqrt.rgb * 0.1;
    #endif
    
    float newLightmap  = pow(lightmap.x, 12.0) * 2.0 + lightmap.x;
    vec3 blockLighting = blocklightCol * newLightmap * newLightmap;

    vec3 minLighting = minLightCol * (1.0 - eBS);
    
    vec3 albedoNormalized = normalize(albedo.rgb + 0.00001);
    vec3 emissiveLighting = mix(albedoNormalized, vec3(1.0), emission * 0.5);
    emissiveLighting *= emission * 4.0;

    float lightFlatten = clamp(1.0 - pow(1.0 - emission, 128.0), 0.0, 1.0);
    vanillaDiffuse = mix(vanillaDiffuse, 1.0, lightFlatten);
    smoothLighting = mix(smoothLighting, 1.0, lightFlatten);
        
    float nightVisionLighting = nightVision * 0.25;
    
    #ifdef ALBEDO_BALANCING
    float albedoLength = length(albedo.rgb);
    albedoLength /= sqrt((albedoLength * albedoLength) * 0.25 * (1.0 - lightFlatten) + 1.0);
    albedo.rgb = albedoNormalized * albedoLength;
    #endif

    albedo *= sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting;
    albedo *= vanillaDiffuse * smoothLighting * smoothLighting;
}