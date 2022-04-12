vec3 GetBloomTile(float lod, vec2 coord, vec2 offset, vec2 dither) {
	float scale = exp2(lod);

	vec2 bloomCoord = coord / scale + offset;
	bloomCoord += dither;
	bloomCoord = clamp(bloomCoord, offset, 1.0 / scale + offset);

	vec3 bloom = texture2D(colortex1, bloomCoord).rgb;
	bloom *= bloom;
	bloom *= bloom;

	return bloom * 128.0;
}

void Bloom(inout vec3 color, vec2 coord) {
	vec2 rescale = 1.0 / vec2(1920.0, 1080.0);
	vec2 dither = vec2(0.0);
	if (rescale.x > pw) dither.x += (Bayer64(gl_FragCoord.xy) - 0.5) * pw;
	if (rescale.y > ph) dither.y += (Bayer64(gl_FragCoord.xy) - 0.5) * ph;

	vec3 blur1 = GetBloomTile(1.0, coord, vec2(0.0      , 0.0 ), dither) * 1.5;
	vec3 blur2 = GetBloomTile(2.0, coord, vec2(0.51     , 0.0 ), dither) * 1.2;
	vec3 blur3 = GetBloomTile(3.0, coord, vec2(0.51     , 0.26), dither);
	vec3 blur4 = GetBloomTile(4.0, coord, vec2(0.645    , 0.26), dither);
	vec3 blur5 = GetBloomTile(5.0, coord, vec2(0.7175   , 0.26), dither);

	#if BLOOM_RADIUS == 1
	vec3 blur = blur1 * 0.667;
	#elif BLOOM_RADIUS == 2
	vec3 blur = (blur1 + blur2) * 0.37;
	#elif BLOOM_RADIUS == 3
	vec3 blur = (blur1 + blur2 + blur3) * 0.27;
	#elif BLOOM_RADIUS == 4
	vec3 blur = (blur1 + blur2 + blur3 + blur4) * 0.212;
	#elif BLOOM_RADIUS == 5
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5) * 0.175;
	#endif

	float strength = BLOOM_STRENGTH;

	#ifdef SSGI
	strength = 0.0;
	#endif

	#if BLOOM_CONTRAST == 0
	color = mix(color, blur, 0.2 * strength);
	#else
	vec3 bloomContrast = vec3(exp2(BLOOM_CONTRAST * 0.25));
	vec3 bloomStrength = pow(vec3(0.2 * strength), bloomContrast);

	color = pow(color, bloomContrast);
	blur = pow(blur, bloomContrast);
	color = mix(color, blur, bloomStrength);
	color = pow(color, 1.0 / bloomContrast);
	#endif
}