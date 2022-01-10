vec3 GetVolumetricSmoke(float z0, float z1, vec3 viewPos) {
    float dither = InterleavedGradientNoiseVL();

	#ifdef TAA
	dither = fract(dither + frameCounter / 32.0);
	#endif

	float maxDist = LIGHTSHAFT_MAX_DISTANCE;

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

    #ifdef NETHER_SMOKE
    float visibility = 0.025;
    #endif

    #ifdef END_SMOKE
    float VoL = dot(normalize(viewPos.xyz), lightVec);
    float scatter = pow(VoL * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 8.0) * 0.1;

    float visibility = 0.025 + scatter;
    #endif

	vec4 vf = vec4(0.0);
    vec4 wpos = vec4(0.0);

    if (visibility > 0.0){
        for(int i = 0; i < 4; i++) {
			float minDist = (i + dither) * 16.0;

			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

            if (length(wpos.xz) < maxDist && depth1 > minDist){
                #ifdef WORLD_CURVATURE
                if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
                else break;
                #endif

                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.025, 0.0, 0.0);

                #if defined NETHER_SMOKE
                float noise = getFogSample(wpos.xyz, 40.0, 256.0, 0.7);
                #elif defined END_SMOKE
                float noise = getFogSample(wpos.xyz, 50.0, 128.0, 1.0);
                #endif

                #if defined NETHER_SMOKE
                vec4 fogColor = vec4(netherCol.rgb * netherCol.rgb * 0.25, noise);
                #elif defined END_SMOKE
                vec4 fogColor = vec4(endCol.rgb * visibility, noise);
                #endif

                fogColor.rgb *= fogColor.a;
                vf += fogColor * (1.0 - vf.a);
            }
		}
		vf = sqrt(vf * visibility);
    }
	
	return vf.rgb;
}

