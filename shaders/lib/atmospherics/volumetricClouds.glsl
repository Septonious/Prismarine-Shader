float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getPerlinNoise(vec3 pos){
	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = v * v * (3.0 - 2.0 * v);
	u.y *= 32.0;

	float noisebdl = GetNoise(u.xz + u.y);
	float noisebdr = GetNoise(u.xz + u.y + vec2(1.0, 0.0));
	float noisebul = GetNoise(u.xz + u.y + vec2(0.0, 1.0));
	float noisebur = GetNoise(u.xz + u.y + vec2(1.0, 1.0));
	float noisetdl = GetNoise(u.xz + u.y + 32.0);
	float noisetdr = GetNoise(u.xz + u.y + 32.0 + vec2(1.0, 0.0));
	float noisetul = GetNoise(u.xz + u.y + 32.0 + vec2(0.0, 1.0));
	float noisetur = GetNoise(u.xz + u.y + 32.0 + vec2(1.0, 1.0));

	float noise = mix(mix(mix(noisebdl, noisebdr, v.x), mix(noisebul, noisebur, v.x), v.z), mix(mix(noisetdl, noisetdr, v.x), mix(noisetul, noisetur, v.x), v.z), v.y);

	return noise;
}

float getCloudSample(vec3 pos){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = VCLOUDS_AMOUNT * (0.90 + rainStrength * 0.40);

	float noiseA = 0.0;
	float frequency = 0.15, speed = 0.5;
	for (int i = 1; i <= VCLOUDS_OCTAVES; i++){
		noiseA += getPerlinNoise(pos * frequency - wind * speed) * i * VCLOUDS_HORIZONTAL_THICKNESS;
		frequency *= VCLOUDS_FREQUENCY;
		speed *= 0.2;
	}

	float sampleHeight = abs(VCLOUDS_HEIGHT - pos.y) / VCLOUDS_VERTICAL_THICKNESS;

	//Shaping
	noiseA -= getPerlinNoise(pos * 0.5 - wind * speed) * 1.5;
	float noiseB = clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
	float density = pow(smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noiseB, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noiseB, pos.y), 0.25);
	sampleHeight = pow(sampleHeight, 8.0 * pow2(1.0 - density * 0.85));

	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

vec3 cloudLightCol = mix(lightCol * lightCol, lightCol, moonVisibility);
vec3 cloudAmbientCol = ambientCol * (1.0 - moonVisibility * 0.9) * (1.0 - length(ambientCol));

vec4 getVolumetricCloud(vec3 viewPos, float z1, float z0, float dither, vec4 translucent){
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	vec2 scaledCoord = texCoord * (1.0 / VOLUMETRICS_RENDER_RESOLUTION);

	#ifdef TAA
	dither = fract(dither + frameCounter / 32.0);
	#endif

	float VoL = clamp(dot(normalize(viewPos.xyz), sunVec), 0.0, 1.0);
	float scattering = moonVisibility + 1.5 + pow4(VoL) * 2.0;

	float depth0 = GetLinearDepth2(z0);
	float depth1 = GetLinearDepth2(z1);

	#if MC_VERSION >= 11800
	float altitudeFactor = clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	float altitudeFactor = clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	float altitudeFactor2 = pow2(clamp(cameraPosition.y * 0.1, 0.0, 1.0));
	altitudeFactor2 *= clamp(eBS + 0.25, 0.0, 1.0);

	if (clamp(texCoord, vec2(0.0), vec2(VOLUMETRICS_RENDER_RESOLUTION + 1e-3)) == texCoord && eBS > 0.2){
		for (int i = 0; i < VCLOUDS_SAMPLES; i++) {
			float minDist = (i + dither) * VCLOUDS_RANGE;

			if (depth1 < minDist || minDist > 1024.0 || finalColor.a > 0.99 || isEyeInWater > 1.0 || altitudeFactor2 < 0.25){
				break;
			}
			
			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), scaledCoord);

			if (length(wpos.xz) < 1024.0){
				#ifdef WORLD_CURVATURE
				if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
				else break;
				#endif

				wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

				//Cloud noise
				float noise = getCloudSample(wpos.xyz);

				//Find the lower and upper parts of the cloud
				float sampleHeightFactor = smoothstep(VCLOUDS_HEIGHT + VCLOUDS_VERTICAL_THICKNESS * noise, VCLOUDS_HEIGHT - VCLOUDS_VERTICAL_THICKNESS * noise, wpos.y);

				vec3 densityLighting = mix(cloudLightCol, cloudAmbientCol, noise);
				vec3 heightLighting = mix(cloudLightCol, cloudAmbientCol, sampleHeightFactor);
				vec3 cloudLighting = sqrt(densityLighting * heightLighting) * scattering;

				vec4 cloudsColor = vec4(cloudLighting, noise);
					 cloudsColor.rgb *= cloudsColor.a;

				finalColor += cloudsColor * (1.0 - finalColor.a) * (1.0 - isEyeInWater * (1.0 - eBS));

				//Translucency blending, works half correct
				if (depth0 < minDist){
					cloudsColor *= translucent;
					finalColor *= translucent;
				}
			}
		}
	}

	#if MC_VERSION >= 11800
	finalColor.rgb *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	finalColor.rgb *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif
	
	return finalColor;
}































/*
float noise(in vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
	vec2 rg = textureLod(noisetex, (uv+ 0.5)/256.0, 0.0 ).yx;
	return -1.0+2.0*mix( rg.x, rg.y, f.z );
}

float map5(in vec3 p) {
	vec3 q = p - vec3(0.0,0.1,1.0)*frameTimeCounter;
	float f;
    f  = 0.50000*noise( q ); q = q*2.02;
    f += 0.25000*noise( q ); q = q*2.03;
    f += 0.12500*noise( q ); q = q*2.01;
    f += 0.06250*noise( q ); q = q*2.02;
    f += 0.03125*noise( q );
	return clamp( 1.5 - p.y - 2.0 + 1.75*f, 0.0, 1.0 );
}

vec4 integrate(in vec4 sum, in float dif, in float den) {
    // lighting
    vec3 lin = ambientCol * 0.75 + lightCol * dif;
    vec4 col = vec4(mix(lightCol, vec3(0.65), den), den);
    col.xyz *= lin;

    // front to back blending    
    col.a *= 0.25;
    col.rgb *= col.a;
    return sum + col * (1.0 - sum.a);
}

#define MARCH(STEPS, MAPLOD) for(int i = 0; i < STEPS; i++) { vec3 pos = ro + t * rd; if(pos.y < -3.0 || pos.y > 2.0 || sum.a > 0.99) break; float den = MAPLOD(pos); if (den > 0.01) { float dif = clamp((den - MAPLOD(pos + 0.3 * normalize(sunVec))) / 0.6, 0.0, 1.0); sum = integrate(sum, dif, den); } t += max(0.1, 0.02 * t); }

vec4 raymarch(in vec3 ro, in vec3 rd, in vec3 bgcol) {
	vec4 sum = vec4(0.0);

	float t = 0.0;

    MARCH(100, map5);

    return clamp(sum, 0.0, 1.0);
}

vec3 render(in vec3 ro, in vec3 rd) {
    vec3 col = vec3(0.0);

    // clouds    
    vec4 res = raymarch(ro, rd, col);
    col = col * (1.0 - res.w) + res.xyz;

    return col;
}

void mainImage(out vec3 fragColor, in vec2 fragCoord) {
    vec2 p = (-vec2(viewWidth, viewHeight) + 2.0 * fragCoord.xy) / viewHeight;
    
    // ray
    vec3 rd = normalize(vec3(p.xy, 1.0));
    
    fragColor.rgb = render(rd, rd);
}
*/