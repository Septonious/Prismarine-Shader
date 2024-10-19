vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.x - 0.5), abs(coord.y - 0.5)) * 1.85;
}

#ifdef REFLECTION_PRECISION
#if REFLECTION_MODE == 0
float errMult = 1.0;
#elif REFLECTION_MODE == 1
float errMult = 1.8;
#else
float errMult = 2.2;
#endif
#else
#if REFLECTION_MODE == 0
float errMult = 1.0;
#elif REFLECTION_MODE == 1
float errMult = 1.3;
#else
float errMult = 1.6;
#endif
#endif

vec4 Raytrace(sampler2D depthtex, vec3 viewPos, vec3 normal, float dither, out float border, 
			  int maxf, float stp, float ref, float inc) {
	vec3 pos = vec3(0.0);
	float dist = 0.0;
	
	#ifdef TAA
	#if TAA_MODE == 0
	dither = fract(dither + frameCounter * 0.618);
	#else
	dither = fract(dither + frameCounter * 0.5);
	#endif
	#endif

	vec3 start = viewPos + normal * 0.075;

    vec3 vector = stp * reflect(normalize(viewPos), normalize(normal));
    viewPos += vector;
	vec3 tvector = vector;

    int sr = 0;

    for(int i = 0; i < 30; i++) {
        pos = nvec3(gbufferProjection * nvec4(viewPos)) * 0.5 + 0.5;
		if (pos.x < -0.05 || pos.x > 1.05 || pos.y < -0.05 || pos.y > 1.05) break;

		vec3 rfragpos = vec3(pos.xy, texture2D(depthtex,pos.xy).r);
        rfragpos = nvec3(gbufferProjectionInverse * nvec4(rfragpos * 2.0 - 1.0));
		dist = abs(dot(normalize(start - rfragpos), normal));

        float err = length(viewPos - rfragpos);
		float lVector = length(vector) * pow(length(tvector), 0.1) * errMult;
		if (err < lVector) {
			sr++;
			if (sr >= maxf) break;
			tvector -= vector;
			vector *= ref;
		}
        vector *= inc;
        tvector += vector;
		viewPos = start + tvector;
    }

	border = cdist(pos.st);

	#ifdef REFLECTION_PREVIOUS
	//Previous frame reprojection from Chocapic13
	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos * 2.0 - 1.0, 1.0);
	viewPosPrev /= viewPosPrev.w;
	
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec4 previousPosition = viewPosPrev + vec4(cameraPosition - previousCameraPosition, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	pos.xy = previousPosition.xy / previousPosition.w * 0.5 + 0.5;
	#endif

	return vec4(pos, dist);
}

vec4 BasicReflect(vec3 viewPos, vec3 normal, out float border) {
	vec3 reflectedViewPos = reflect(viewPos, normal) + normal * dot(viewPos, normal) * 0.5;

	vec3 pos = nvec3(gbufferProjection * nvec4(reflectedViewPos)) * 0.5 + 0.5;

	border = cdist(pos.st);

	return vec4(pos, 0.0);
}