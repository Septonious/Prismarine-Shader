vec4 GetVolumetricSmoke(float z0, float z1, vec3 viewPos) {
    float dither = Bayer64(gl_FragCoord.xy);

	float maxDist = LIGHTSHAFT_MAX_DISTANCE;

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

    #ifdef NETHER_SMOKE
    float visibility = 1.00;
    #endif

    #ifdef END_SMOKE
    float VoL = dot(normalize(viewPos.xyz), lightVec);
    float scatter = pow(VoL * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 8.0);

    float visibility = 0.25 + scatter;
    #endif

	vec4 vf = vec4(0.0);
    vec4 wpos = vec4(0.0);

    if (visibility > 0.0){
        for(int i = 0; i < LIGHTSHAFT_SAMPLES; i++) {
			float minDist = (i + dither) * LIGHTSHAFT_MIN_DISTANCE;

			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

            if (length(wpos.xz) < maxDist && depth1 > minDist){
                #ifdef WORLD_CURVATURE
                if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
                else break;
                #endif

                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.25, 0.0, 0.0);

                #if defined NETHER_SMOKE
                float noise = getFogSample(wpos.xyz, 40.0, 256.0);
                #elif defined END_SMOKE
                float noise = getFogSample(wpos.xyz, 60.0, 128.0);
                #endif

                #if defined NETHER_SMOKE
                vec4 fogColor = vec4(netherCol.rgb * netherCol.rgb, noise);
                #elif defined END_SMOKE
                vec4 fogColor = vec4(endCol.rgb * visibility, noise);
                #endif

                fogColor.rgb *= fogColor.a;
                vf += fogColor * (1.0 - vf.a);
            }
		}
		vf = sqrt(vf * visibility);
    }
	
	return vf;
}

