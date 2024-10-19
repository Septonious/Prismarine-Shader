vec3 GetVolumetricSmoke(float z1, vec2 scaledCoord, float dither) {
	#ifdef TAA
	dither = fract(dither + frameCounter / 8.0);
	#endif

	float maxDist = LIGHTSHAFT_MAX_DISTANCE;
	float depth1 = GetLinearDepth2(z1);

	vec4 vf = vec4(0.0);
    vec4 wpos = vec4(0.0);

    if (clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RENDER_RESOLUTION + 1e-3)) == texCoord) {
        for(int i = 0; i < 8; i++) {
			float minDist = (i + dither) * 8.0;

			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), scaledCoord);

            if (length(wpos.xz) < maxDist && depth1 > minDist){
                #ifdef WORLD_CURVATURE
                if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
                else break;
                #endif

                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.025, 0.0, 0.0);

                float noise = getFogSample(wpos.xyz, 64.0, 256.0, 0.9);

                #if defined NETHER_SMOKE
                vec4 fogColor = vec4(netherCol.rgb, noise);
                #elif defined END_SMOKE
                vec4 fogColor = vec4(endCol.rgb, noise);
                #endif

                fogColor.rgb *= fogColor.a;
                vf += fogColor * (1.0 - vf.a);
            }
		}
    }
	
	return vf.rgb * SMOKE_BRIGHTNESS * 0.25;
}