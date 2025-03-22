vec3 hash(vec3 p3){
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return 2.0 * fract((p3.xxy + p3.yxx) * p3.zyx) - 1.0;
}

float getFireflyNoise(vec3 pos){
    pos += 1e-4 * frameTimeCounter;

    vec3 floorPos = floor(pos);
    vec3 fractPos = fract(pos);
	
	vec3 u = (fractPos * fractPos * fractPos) * (fractPos * (fractPos * 6.0 - 15.0) + 10.0);

    return mix( mix( mix( dot( hash(floorPos + vec3(0.0,0.0,0.0)), fractPos - vec3(0.0,0.0,0.0)), 
              dot( hash(floorPos + vec3(1.0,0.0,0.0)), fractPos - vec3(1.0,0.0,0.0)), u.x),
         mix( dot( hash(floorPos + vec3(0.0,1.0,0.0)), fractPos - vec3(0.0,1.0,0.0)), 
              dot( hash(floorPos + vec3(1.0,1.0,0.0)), fractPos - vec3(1.0,1.0,0.0)), u.x), u.y),
    mix( mix( dot( hash(floorPos + vec3(0.0,0.0,1.0)), fractPos - vec3(0.0,0.0,1.0)), 
              dot( hash(floorPos + vec3(1.0,0.0,1.0)), fractPos - vec3(1.0,0.0,1.0)), u.x),
         mix( dot( hash(floorPos + vec3(0.0,1.0,1.0)), fractPos - vec3(0.0,1.0,1.0)), 
              dot( hash(floorPos + vec3(1.0,1.0,1.0)), fractPos - vec3(1.0,1.0,1.0)), u.x), u.y), u.z );
}

vec3 calculateWaving(vec3 worldPos, float wind) {
    float strength = sin(wind + worldPos.z + worldPos.y) * 0.25 + 0.05;

    float d0 = sin(wind * 0.0125);
    float d1 = sin(wind * 0.0090);
    float d2 = sin(wind * 0.0105);

    return vec3(sin(wind * 0.0065 + d0 + d1 - worldPos.x + worldPos.z + worldPos.y), 
                sin(wind * 0.0225 + d1 + d2 + worldPos.x - worldPos.z + worldPos.y),
                sin(wind * 0.0015 + d2 + d0 + worldPos.z + worldPos.y - worldPos.y)) * strength;
}

vec3 calculateMovement(vec3 worldPos, float lightIntensity, float speed, vec2 mult) {
    vec3 wave = calculateWaving(worldPos * lightIntensity, frameTimeCounter * speed);

    return wave * vec3(mult, mult.x);
}

void computeFireflies(inout float fireflies, in vec3 translucent, in float dither) {
	//Depths
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;

    //Positions
	vec3 viewPosZ0 = ToView(vec3(texCoord.xy, z0));
    vec3 viewPosZ1 = ToView(vec3(texCoord.xy, z1));
	vec3 worldPos = ToWorld(viewPosZ1);

    float lViewPosZ0 = length(viewPosZ0);
    float lViewPosZ1 = length(viewPosZ1);

	//Total fireflies visibility
	float visibility = eBS * eBS * (1.0 - sunVisibility) * (1.0 - wetness) * float(isEyeInWater == 0);

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

    //Ray Marching Parameters
    float minDist = 3.0;
    float maxDist = min(far, 96.0);
    int sampleCount = int(maxDist / minDist + 0.01);

    vec3 rayIncrement = normalize(worldPos) * minDist;
    vec3 rayPos = rayIncrement * dither;

    //Ray Marching
    for (int i = 0; i < sampleCount; i++, rayPos += rayIncrement) {
        float rayLength = length(rayPos);
        if (rayLength > lViewPosZ1) break;

        vec3 nposA = rayPos + cameraPosition;
             nposA += calculateMovement(nposA, 0.6, 3.0, vec2(2.4, 1.8));
             nposA += vec3(sin(frameTimeCounter * 0.50), - sin(frameTimeCounter * 0.75), cos(frameTimeCounter * 1.25));

        float fireflyNoise = getFireflyNoise(nposA);
              fireflyNoise = clamp(fireflyNoise - 0.675, 0.0, 1.0);

        float rayDistance = length(vec3(rayPos.x, rayPos.y * 2.0, rayPos.z));
        fireflyNoise *= max(0.0, 1.0 - rayDistance / maxDist);

        if (rayLength > lViewPosZ0) break;
        fireflies += fireflyNoise * (1.0 - clamp(nposA.y * 0.01, 0.0, 1.0)) * visibility * 64.0;
    }
}