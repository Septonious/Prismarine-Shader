uniform sampler2DShadow shadowtex0;

#ifdef SHADOW_COLOR
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

vec2 shadowOffsets[16] = vec2[16](
	vec2( 0.0    ,  0.25  ),
	vec2(-0.2165 ,  0.125 ),
	vec2(-0.2165 , -0.125 ),
	vec2( 0      , -0.25  ),
	vec2( 0.2165 , -0.125 ),
	vec2( 0.2165 ,  0.125 ),
	vec2( 0      ,  0.5   ),
	vec2(-0.25   ,  0.433 ),
	vec2(-0.433  ,  0.25  ),
	vec2(-0.5    ,  0     ),
	vec2(-0.433  , -0.25  ),
	vec2(-0.25   , -0.433 ),
	vec2( 0      , -0.5   ),
	vec2( 0.25   , -0.433 ),
	vec2( 0.433  , -0.2   ),
	vec2( 0.5    ,  0     )
);

float biasDistribution[10] = float[10](
    0.0, 0.057, 0.118, 0.184, 0.255, 0.333, 0.423, 0.529, 0.667, 1.0
);

vec3 DistortShadow(vec3 worldPos, float distortFactor) {
	worldPos.xy /= distortFactor;
	worldPos.z *= 0.2;
	return worldPos * 0.5 + 0.5;
}

float GetCurvedBias(int i, float dither) {
    return mix(biasDistribution[i], biasDistribution[i+1], dither);
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}

vec3 SampleBasicShadow(vec3 shadowPos) {
    float shadow0 = shadow2D(shadowtex0, vec3(shadowPos.st, shadowPos.z)).x;

    vec3 shadowCol = vec3(0.0);
    #ifdef SHADOW_COLOR
    if (shadow0 < 1.0) {
        shadowCol = texture2D(shadowcolor0, shadowPos.st).rgb *
                    shadow2D(shadowtex1, vec3(shadowPos.st, shadowPos.z)).x;
    }
    #endif

    return clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));
}

vec3 SampleFilteredShadow(vec3 shadowPos, float offset, float biasStep) {
    float shadow0 = 0.0;

    #if SSS_QUALITY == 1
    float sz = shadowPos.z;
    float dither = InterleavedGradientNoise();
    #endif
    
    for (int i = 0; i < 16; i++) {
        vec2 shadowOffset = shadowOffsets[i] * offset;
        shadow0 += shadow2D(shadowtex0, vec3(shadowPos.st + shadowOffset, shadowPos.z)).x;
        #if SSS_QUALITY == 1
        if (biasStep > 0.0) shadowPos.z = sz - biasStep * GetCurvedBias(i, dither);
        #endif
    }
    shadow0 /= 16.0;

    vec3 shadowCol = vec3(0.0);
    #ifdef SHADOW_COLOR
    if (shadow0 < 0.999) {
        for (int i = 0; i < 16; i++) {
            vec2 shadowOffset = shadowOffsets[i] * offset;
            shadowCol += texture2D(shadowcolor0, shadowPos.st + shadowOffset).rgb *
                         shadow2D(shadowtex1, vec3(shadowPos.st + shadowOffset, shadowPos.z)).x;
            #if SSS_QUALITY == 1
            if (biasStep > 0.0) shadowPos.z = sz - biasStep * GetCurvedBias(i, dither);
            #endif
        }
        shadowCol /= 16.0;
    }
    #endif

    return clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));
}

#if defined CLOUD_SHADOWS || defined AURORA
#if !defined GB_BLOCK && !defined GB_WATER
uniform sampler2D noisetex;
#endif
#endif

#ifdef CLOUD_SHADOWS
float CloudNoiseShadow(vec2 coord, vec2 wind){
	float windMult = 0.5;
	float frequencyMult = 0.25;
	float noiseMult = 1.0, noiseFactor = 0.0;
	float noise = 0.0;

	#if CLOUD_OCTAVES == 2
	noiseFactor = 12.4;
	#elif CLOUD_OCTAVES == 3
	noiseFactor = 5.2;
	#elif CLOUD_OCTAVES == 4
	noiseFactor = 2.6;
	#elif CLOUD_OCTAVES == 5
	noiseFactor = 1.4;
	#elif CLOUD_OCTAVES == 6
	noiseFactor = 0.8;
	#elif CLOUD_OCTAVES == 7
	noiseFactor = 0.5;
	#elif CLOUD_OCTAVES == 8
	noiseFactor = 0.32;
	#endif

	for (int i = 0; i < CLOUD_OCTAVES; i++){
		noise += texture2D(noisetex, coord * frequencyMult + wind * windMult).x * noiseMult;
		windMult *= 0.75;
		frequencyMult *= CLOUD_FREQUENCY;
		noiseMult += noiseFactor;
	}

	return noise;
}

float CloudCoverageShadow(float noise){
	float noiseMix = mix(noise, 21.0, 0.33 * rainStrength);
	float noiseFade = clamp(sqrt(10.0), 0.0, 1.0);
	float noiseCoverage = CLOUD_AMOUNT;
	float multiplier = 1.0 - 0.5 * rainStrength;

	return max(noiseMix * noiseFade - noiseCoverage, 0.0) * multiplier;
}

float DrawCloudShadow(vec2 worldPos){
	float cloud = 0.0;
	float noiseMultiplier = CLOUD_THICKNESS * 0.2;

	vec2 wind = vec2(
		frametime * CLOUD_SPEED * 0.001,
		sin(frametime * CLOUD_SPEED * 0.05) * 0.002
	) * CLOUD_HEIGHT / 15.0;

	vec2 coord = (cameraPosition.xz + worldPos) * 0.0005;

	float noise = CloudNoiseShadow(coord, wind);
		  noise = CloudCoverageShadow(noise) * noiseMultiplier;
		  noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);

	cloud = mix(cloud, 1.0, noise);
	
	return 1.0 - clamp(cloud * cloud, 0.0, 1.0);
}
#endif

vec3 GetShadow(vec3 worldPos, float NoL, float subsurface, float skylight) {
    #if SHADOW_PIXEL > 0
    worldPos = (floor((worldPos + cameraPosition) * SHADOW_PIXEL + 0.01) + 0.5) /
               SHADOW_PIXEL - cameraPosition;
    #endif
    
    vec3 shadowPos = ToShadow(worldPos);

    float distb = sqrt(dot(shadowPos.xy, shadowPos.xy));
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
    shadowPos = DistortShadow(shadowPos, distortFactor);

    bool doShadow = shadowPos.x > 0.0 && shadowPos.x < 1.0 &&
                    shadowPos.y > 0.0 && shadowPos.y < 1.0;

    #ifdef OVERWORLD
    doShadow = doShadow && skylight > 0.001;
    #endif

    if (!doShadow) return vec3(0.0);

    float biasFactor = sqrt(1.0 - NoL * NoL) / NoL;
    float distortBias = distortFactor * shadowDistance / 256.0;
          distortBias *= 8.0 * distortBias;
    float distanceBias = sqrt(dot(worldPos.xyz, worldPos.xyz)) * 0.005;
    
    float bias = (distortBias * biasFactor + distanceBias + 0.05) / shadowMapResolution;
    float offset = 2.0 / shadowMapResolution;
    
    if (subsurface > 0.0) {
        bias = 0.0002;
        #if defined SHADOW_FILTER && SSS_QUALITY == 1
        bias *= mix(subsurface, 1.0, NoL);
        #endif
        offset = 0.0007;
    }
    float biasStep = 0.001 * subsurface * (1.0 - NoL);
    
    #if SHADOW_PIXEL > 0
    bias += 0.0025 / SHADOW_PIXEL;
    #endif

    shadowPos.z -= bias;

    #ifdef SHADOW_FILTER
    vec3 shadow = SampleFilteredShadow(shadowPos, offset, biasStep);
    #else
    vec3 shadow = SampleBasicShadow(shadowPos);
    #endif

    #ifdef CLOUD_SHADOWS
    float cloudShadow = DrawCloudShadow(worldPos.xz);
    shadow *= cloudShadow;
    #endif

    return shadow;
}