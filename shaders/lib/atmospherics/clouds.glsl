float getNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

#ifdef OVERWORLD

float CloudSampleBasePerlin(vec2 coord) {
	float noiseBase = texture2D(noisetex, coord).r;

	return noiseBase;
}

float CloudSampleBaseWorley(vec2 coord) {
	float noiseBase = texture2D(noisetex, coord).g;
	noiseBase = pow(1.0 - noiseBase, 2.0) * 0.5 + 0.25;

	return noiseBase;
}

float CloudSampleBaseBlocky(vec2 coord) {
	float noiseRes = 512.0;

	coord.xy = coord.xy * noiseRes - 0.5;

	vec2 flr = floor(coord.xy);
	vec2 frc = coord.xy - flr;

	frc = clamp(frc * 5.0 - 2.0, vec2(0.0), vec2(1.0));
	frc = frc * frc * (3.0 - 2.0 * frc);

	coord.xy = (flr + frc + 0.5) / noiseRes;

	float noiseBase = texture2D(noisetex, coord).a;
	noiseBase = (1.0 - noiseBase) * 4.0;

	float noiseRain = texture2D(noisetex, coord + vec2(0.5,0.0)).a;
	noiseRain = (1.0 - noiseRain) * 4.0 * smoothstep(0.0, 0.5, rainStrength);

	noiseBase = min(noiseBase + noiseRain, 1.0);

	return noiseBase;
}

float CloudSampleDetail(vec2 coord, float cloudGradient) {
	float detailZ = floor(cloudGradient * float(CLOUD_THICKNESS)) * 0.04;
	float detailFrac = fract(cloudGradient * float(CLOUD_THICKNESS));

	float noiseDetailLow = texture2D(noisetex, coord.xy + detailZ).b;
	float noiseDetailHigh = texture2D(noisetex, coord.xy + detailZ + 0.04).b;

	float noiseDetail = mix(noiseDetailLow, noiseDetailHigh, detailFrac);

	return noiseDetail;
}

float CloudCoverageDefault(float cloudGradient) {
	float noiseCoverage = abs(cloudGradient - 0.125);

	noiseCoverage *= cloudGradient > 0.125 ? (2.14 - CLOUD_AMOUNT * 0.1) : 8.0;
	noiseCoverage = noiseCoverage * noiseCoverage * 4.0;

	return noiseCoverage;
}

float CloudCoverageBlocky(float cloudGradient) {
	float noiseCoverage = abs(cloudGradient - 0.5) * 2.0;

	noiseCoverage *= noiseCoverage;
	noiseCoverage *= noiseCoverage;

	return noiseCoverage;
}

float CloudApplyDensity(float noise) {
	noise *= CLOUD_DENSITY * 0.125;
	noise *= (1.0 - 0.75 * rainStrength);
	noise = noise / sqrt(noise * noise + 0.5);

	return noise;
}

float CloudCombineDefault(float noiseBase, float noiseDetail, float noiseCoverage) {
	float noise = mix(noiseBase, noiseDetail, 0.0476 * CLOUD_DETAIL) * 21.0;

	noise = mix(noise - noiseCoverage, 18.0 - noiseCoverage * 2.5, 0.33 * rainStrength);
	noise = max(noise - CLOUD_AMOUNT, 0.0);

	noise = CloudApplyDensity(noise);

	return noise;
}

float CloudCombineBlocky(float noiseBase, float noiseCoverage) {
	float noise = (noiseBase - noiseCoverage) * 2.0;

	noise = max(noise, 0.0);
	
	noise = CloudApplyDensity(noise);

	return noise;
}

float CloudSample(vec2 coord, vec2 wind, float cloudGradient, float dither) {
	coord *= 0.004 * CLOUD_STRETCH;

	#if CLOUD_BASE == 0
	vec2 baseCoord = coord * 0.25 + wind;
	vec2 detailCoord = coord.xy * 0.5 - wind * 2.0;

	float noiseBase = CloudSampleBasePerlin(baseCoord);
	float noiseDetail = CloudSampleDetail(detailCoord, cloudGradient);
	float noiseCoverage = CloudCoverageDefault(cloudGradient);

	float noise = CloudCombineDefault(noiseBase, noiseDetail, noiseCoverage);
	
	return noise;
	#elif CLOUD_BASE == 1
	vec2 baseCoord = coord * 0.5 + wind * 2.0;
	vec2 detailCoord = coord.xy * 0.5 - wind * 2.0;

	float noiseBase = CloudSampleBaseWorley(baseCoord);
	float noiseDetail = CloudSampleDetail(detailCoord, cloudGradient);
	float noiseCoverage = CloudCoverageDefault(cloudGradient);

	float noise = CloudCombineDefault(noiseBase, noiseDetail, noiseCoverage);
	
	return noise;
	#else
	vec2 baseCoord = coord * 0.125 + wind * 0.5;

	float noiseBase = CloudSampleBaseBlocky(baseCoord);
	float noiseCoverage = CloudCoverageBlocky(cloudGradient);

	float noise = CloudCombineBlocky(noiseBase, noiseCoverage);

	return noise;
	#endif
}

float InvLerp(float v, float l, float h) {
	return clamp((v - l) / (h - l), 0.0, 1.0);
}

vec3 GetReflectedCameraPos(vec3 worldPos, vec3 normal) {
	vec4 worldNormal = gbufferModelViewInverse * vec4(normal, 1.0);
	worldNormal.xyz /= worldNormal.w;

	vec3 cameraPos = cameraPosition + 2.0 * worldNormal.xyz * dot(worldPos, worldNormal.xyz);
	cameraPos = cameraPos + reflect(worldPos, worldNormal.xyz); //bobbing stabilizer, works like magic

	return cameraPos;
}

vec4 DrawCloudVolumetric(vec3 viewPos, vec3 cameraPos, float z, float dither, vec3 lightCol, vec3 ambientCol, inout float cloudViewLength, bool fadeFaster) {
	#ifdef TAA
	#if TAA_MODE == 0
	dither = fract(dither + frameCounter * 0.618);
	#else
	dither = fract(dither + frameCounter * 0.5);
	#endif
	#endif

	vec3 nViewPos = normalize(viewPos);
	vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 nWorldPos = normalize(worldPos);
	float viewLength = length(viewPos);

	float cloudHeight = CLOUD_HEIGHT * CLOUD_VOLUMETRIC_SCALE + 70;
	// float cloudHeight = CLOUD_HEIGHT * CLOUD_VOLUMETRIC_SCALE + cameraPosition.y;
	// float cloudHeight = 63;
	float cloudThickness = CLOUD_THICKNESS;

	int maxSamples = 24;

	#if CLOUD_BASE == 2
	cloudThickness *= 0.5;
	maxSamples = 64;
	#endif

	float lowerY = cloudHeight;
	float upperY = cloudHeight + cloudThickness * CLOUD_VOLUMETRIC_SCALE;

	float lowerPlane = (lowerY - cameraPos.y) / nWorldPos.y;
	float upperPlane = (upperY - cameraPos.y) / nWorldPos.y;

	float nearestPlane = max(min(lowerPlane, upperPlane), 0.0);
	float furthestPlane = max(lowerPlane, upperPlane);

	float maxcloudViewLength = cloudViewLength;

	if (furthestPlane < 0) return vec4(0.0);

	float planeDifference = furthestPlane - nearestPlane;

	vec3 startPos = cameraPos + nearestPlane * nWorldPos;

	float scaling = abs(cameraPosition.y - (upperY + lowerY) * 0.5) / ((upperY - lowerY) * 0.5);
	scaling = clamp((scaling - 1.0) * cloudThickness * 0.125, 0.0, 1.0);

	float sampleLength = cloudThickness * CLOUD_VOLUMETRIC_SCALE / 2.0;
	sampleLength /= (4.0 * nWorldPos.y * nWorldPos.y) * scaling + 1.0;
	vec3 sampleStep = nWorldPos * sampleLength;
	int samples = int(min(planeDifference / sampleLength, maxSamples) + 1);
	
	vec3 samplePos = startPos + sampleStep * dither;
	float sampleTotalLength = nearestPlane + sampleLength * dither;

	vec2 wind = vec2(
		frametime * CLOUD_SPEED * 0.0005,
		sin(frametime * CLOUD_SPEED * 0.001) * 0.005
	) * CLOUD_HEIGHT / 15.0;

	float cloud = 0.0;
	float cloudFaded = 0.0;
	float cloudLighting = 0.0;

	float VoU = dot(nViewPos, upVec);
	float VoL = dot(nViewPos, lightVec);

	float halfVoL = mix(abs(VoL) * 0.8, VoL, shadowFade) * 0.5 + 0.5;
	float halfVoLSqr = halfVoL * halfVoL;

	float scattering = pow(halfVoL, 6.0);
	float noiseLightFactor = (2.0 - 1.5 * VoL * shadowFade) * CLOUD_DENSITY * 0.5;

	float viewLengthSoftMin = viewLength - sampleLength * 0.5;
	float viewLengthSoftMax = viewLength + sampleLength * 0.5;

	float fade = 1.0;
	float fadeStart = 32.0 / max(fogDensity, 0.5);
	float fadeEnd = (fadeFaster ? 120.0 : 320.0) / max(fogDensity, 0.5);

	for (int i = 0; i < samples; i++) {
		if (cloud > 0.99) break;
		if (sampleTotalLength > viewLengthSoftMax && z < 1.0) break;

		float cloudGradient = InvLerp(samplePos.y, lowerY, upperY);
		float xzNormalizedDistance = length(samplePos.xz - cameraPos.xz) / CLOUD_VOLUMETRIC_SCALE;
		vec2 cloudCoord = samplePos.xz / CLOUD_VOLUMETRIC_SCALE;

		float noise = CloudSample(cloudCoord * 0.75, wind, cloudGradient, dither);
		noise *= step(lowerY, samplePos.y) * step(samplePos.y, upperY);

		float sampleLighting = pow(cloudGradient, 1.125 * halfVoLSqr + 0.875) * 0.8 + 0.2;
		sampleLighting *= 1.0 - pow(noise, noiseLightFactor);

		float sampleFade = InvLerp(xzNormalizedDistance, fadeEnd, fadeStart);
		fade *= mix(1.0, sampleFade, noise * (1.0 - cloud));
		noise *= step(xzNormalizedDistance, fadeEnd);

		cloudLighting = mix(cloudLighting, sampleLighting, noise * (1.0 - cloud * cloud));
		
		if (z < 1.0) {
			noise *= InvLerp(sampleTotalLength, viewLengthSoftMax, viewLengthSoftMin);
		}

		cloud = mix(cloud, 1.0, noise);

		if (cloudViewLength == maxcloudViewLength && cloud > 0.5) {
			cloudViewLength = sampleTotalLength;
		}
		
		samplePos += sampleStep;
		sampleTotalLength += sampleLength;
	}

	cloudFaded = cloud * fade;

	cloudLighting = mix(cloudLighting, 1.0, (1.0 - cloud * cloud) * scattering * 0.5);
	cloudLighting *= (1.0 - 0.9 * rainStrength);
	
	vec3 cloudColor = mix(
		ambientCol * (0.3 * sunVisibility + 0.5),
		lightCol * (0.85 + 1.15 * scattering),
		cloudLighting
	);

	cloudColor *= 1.0 - 0.4 * rainStrength;
	cloudColor *= CLOUD_BRIGHTNESS * (0.5 - 0.25 * (1.0 - sunVisibility) * (1.0 - rainStrength));

	cloudFaded *= cloudFaded * CLOUD_OPACITY;

	if (cloudFaded < dither) {
		cloudViewLength = maxcloudViewLength;
	}

	return vec4(cloudColor, cloudFaded);
}

void DrawStars(inout vec3 color, vec3 viewPos) {
	vec3 worldPos = vec3(gbufferModelViewInverse * vec4(viewPos * 100.0, 1.0));
	vec2 planeCoord0 = worldPos.xz / (length(worldPos.y) + length(worldPos.xz));
		planeCoord0 += cameraPosition.xz * 0.00001;
		planeCoord0 += frameTimeCounter * 0.0001;
		planeCoord0 = floor(planeCoord0 * 500.0) / 500.0;

	vec2 planeCoord1 = worldPos.xz / (length(worldPos.y) + length(worldPos.xz));
		planeCoord1 += cameraPosition.xz * 0.00001;
		planeCoord1 += frameTimeCounter * 0.0001;
		planeCoord1 = floor(planeCoord1 * 200.0) / 200.0;
	
	float VoU = clamp(dot(normalize(viewPos), upVec), 0.0, 1.0);
	float multiplier = sqrt(sqrt(VoU)) * 5.0 * (1.0 - rainStrength);
	
	float star = 1.0;
	if (VoU > 0.0) {
		float smallStars = getNoise(planeCoord0 + 10.0);
			  smallStars*= getNoise(planeCoord0 + 14.0);
			  smallStars = clamp(smallStars - 0.75, 0.0, 1.0);
			  smallStars *= multiplier;
			  smallStars *= smallStars * 0.85;

		float bigStars = getNoise(planeCoord1 + 11.0);
			  bigStars*= getNoise(planeCoord1 + 13.0);
			  bigStars*= getNoise(planeCoord1 + 15.0);
			  bigStars = clamp(bigStars - 0.75, 0.0, 1.0);
			  bigStars *= multiplier;
			  bigStars *= bigStars * 2.0;

		star = smallStars + bigStars;
	}
	star = clamp(star - 0.8125, 0.0, 1.0) * multiplier;
	
	#if MC_VERSION >= 11800
	star *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	star *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	#ifdef UNDERGROUND_SKY
	star *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif
		
	color += star * pow(lightNight, vec3(0.8));
}

#ifdef AURORA
#include "/lib/color/auroraColor.glsl"

float AuroraSample(vec2 coord, vec2 wind) {
	float noise = texture2D(noisetex, coord * 0.04 + wind * 0.25).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.02 + wind * 0.15).b * 3.0;

	noise = max(1.0 - 2.0 * abs(noise - 3.0), 0.0);

	return noise;
}

vec3 DrawAurora(vec3 viewPos, float dither, int samples) {
	#ifdef TAA
	#if TAA_MODE == 0
	dither = fract(dither + frameCounter * 0.618);
	#else
	dither = fract(dither + frameCounter * 0.5);
	#endif
	#endif
	
	float sampleStep = 1.0 / samples;
	float currentStep = dither * sampleStep;

	float VoU = dot(normalize(viewPos), upVec);

	float visibility = moonVisibility * (1.0 - rainStrength) * (1.0 - rainStrength);

	#ifdef WEATHER_PERBIOME
	visibility *= isCold * isCold;
	#endif

	vec2 wind = vec2(
		frametime * CLOUD_SPEED * 0.000125,
		sin(frametime * CLOUD_SPEED * 0.05) * 0.00025
	);

	vec3 aurora = vec3(0.0);

	if (VoU > 0.0 && visibility > 0.0) {
		vec3 worldPos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < samples; i++) {
			vec3 planeCoord = worldPos * ((6.0 + currentStep * 16.0) / worldPos.y) * 0.003;

			vec2 coord = cameraPosition.xz * 0.00004 + planeCoord.xz;
				 coord += vec2(coord.y, -coord.x) * 0.6;

			float noise = AuroraSample(coord, wind);
			
			if (noise > 0.0) {
				noise *= texture2D(noisetex, coord * 0.125 + wind * 0.25).b;
				noise *= texture2D(noisetex, coord + wind * 16.0).b * 0.5 + 0.75;
				noise = noise * noise * 3.0 * sampleStep;
				noise *= max(sqrt(1.0 - length(planeCoord.xz) * 3.0), 0.0);

				vec3 auroraColor = mix(auroraLowCol, auroraHighCol, pow(currentStep, 0.4));
				aurora += noise * auroraColor * exp2(-8.0 * i * sampleStep);
			}
			currentStep += sampleStep;
		}
	}
	
	#if MC_VERSION >= 11800
	visibility *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	visibility *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	#ifdef UNDERGROUND_SKY
	visibility *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif

	return aurora * visibility;
}
#endif
#endif

float InterleavedGradientNoise1() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);

	return fract(n);
}

#ifdef OVERWORLD_NEBULA
float nebulaSample(vec2 coord, vec2 wind, float VoU) {
	float noise = texture2D(noisetex, coord * 1.0000 - wind * 0.25).b * 2.5;
		  noise-= texture2D(noisetex, coord * 0.5000 + wind * 0.20).b * 1.5;
		  noise+= texture2D(noisetex, coord * 0.2500 - wind * 0.15).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.1250 + wind * 0.10).b * 3.5;

	noise *= NEBULA_AMOUNT;

	noise = max(1.0 - 2.0 * (0.5 * VoU + 0.5) * abs(noise - 3.5), 0.0);

	return noise;
}

void erodeCoord(inout vec2 coord, in float currentStep, in float erosionStrength){
	coord += cos(mix(vec2(cos(currentStep * 1.00), sin(currentStep * 2.00)), vec2(cos(currentStep * 3.0), sin(currentStep * 4.00)), currentStep) * erosionStrength);
}

vec3 DrawNebula(vec3 viewPos) {
	float VoU = dot(normalize(viewPos.xyz), upVec);
	float visFactor = (1.0 - rainStrength) * moonVisibility;

	vec3 nebula = vec3(0.0);
	vec3 nebulaColor = vec3(0.0);

	if (visFactor > 0 && VoU > 0){
		float dither = InterleavedGradientNoise1();

		#ifdef TAA
		dither = fract(16.0 * frameTimeCounter + dither);
		#endif

		int samples = 5;
		float sampleStep = 1.0 / samples;
		float currentStep = dither * sampleStep;

		vec2 wind = vec2(
			frametime * NEBULA_SPEED * 0.000125,
			sin(frametime * NEBULA_SPEED * 0.05) * 0.00125
		);

		vec3 worldPos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < samples; i++) {
			vec3 planeCoord = worldPos * ((6.0 + currentStep * -2.0) / worldPos.y) * 0.005 * NEBULA_STRETCHING;

			vec2 coord = (cameraPosition.xz * 0.000005 + planeCoord.xz);

			erodeCoord(coord, currentStep, 0.1);
			erodeCoord(coord, currentStep, 0.2);

			float noise = nebulaSample(coord, wind, VoU);
				 noise *= texture2D(noisetex, coord * 0.25 + wind * 0.25).r;
				 noise *= texture2D(noisetex, coord + wind * 16.0).r + 0.75;
				 noise = noise * noise * 2.0 * sampleStep;
				 noise *= max(sqrt(1.0 - length(planeCoord.xz) * 4.0), 0.0);

			nebulaColor = mix(nebulaLowCol, nebulaHighCol, currentStep);

			nebula += noise * nebulaColor * exp2(-4.0 * i * sampleStep);
			currentStep += sampleStep;
		}
	}

	#if defined UNDERGROUND_SKY && defined OVERWORLD
	nebula *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif

	return nebula * NEBULA_BRIGHTNESS * visFactor;
}
#endif

#ifdef END_NEBULA
float nebulaSample2(vec2 coord, vec2 wind, float VoU) {
	#ifdef OVERWORLD
	coord *= 2.0;
	#endif

	float noise = texture2D(noisetex, coord * 1.0000 - wind * 0.25).b * 2.5;
		  noise-= texture2D(noisetex, coord * 0.5000 + wind * 0.20).b * 1.5;
		  noise+= texture2D(noisetex, coord * 0.2500 - wind * 0.15).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.1250 + wind * 0.10).b * 3.5;

	noise *= NEBULA_AMOUNT;
	
	#ifdef END
	noise *= 1.1;
	#endif

	noise = max(1.0 - 2.0 * (0.5 * VoU + 0.5) * abs(noise - 3.5), 0.0);

	return noise;
}

vec3 DrawEndNebula(vec3 viewPos) {
	int samples = 12;

	float dither = InterleavedGradientNoise1();

	#ifdef TAA
	dither = fract(16.0 * frameTimeCounter + dither);
	#endif

	float VoU = abs(dot(normalize(viewPos.xyz), upVec));

	float sampleStep = 1.0 / samples;
	float currentStep = dither * sampleStep;

	vec2 wind = vec2(
		frametime * NEBULA_SPEED * 0.000125,
		sin(frametime * NEBULA_SPEED * 0.05) * 0.00125
	);

	vec3 nebula = vec3(0.0);
	vec3 nebulaColor = vec3(0.0);

	vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
	for(int i = 0; i < samples; i++) {
		vec3 planeCoord = wpos * (16.0 + currentStep * -2.0) * 0.00025 * NEBULA_STRETCHING;
		vec2 coord = (cameraPosition.xz * 0.000001 + planeCoord.xz);
		coord += vec2(coord.y, -coord.x) * 8.00 * NEBULA_DISTORTION;

		erodeCoord(coord, currentStep, 0.175);

		float noise = nebulaSample2(coord, wind, VoU);
			 noise *= texture2D(noisetex, coord * 0.5 + wind * 0.25).r;
			 noise *= texture2D(noisetex, coord * 1.5 + wind * 16.0).r + 0.75;
			 noise = noise * noise * sampleStep;
			 noise *= max(sqrt(1.0 - length(planeCoord.xz) * 4.0), 0.0);
		nebulaColor = mix(vec3(endCol.r, endCol.g, endCol.b * 1.5) * 4.0, vec3(endCol.r * 2.0, endCol.g, endCol.b) * 16.0, currentStep);

		nebula += noise * nebulaColor * exp2(-8.0 * i * sampleStep);
		currentStep += sampleStep;
	}

	return nebula * NEBULA_BRIGHTNESS;
}
#endif

#ifdef END_STARS
void DrawEndStars(inout vec3 color, vec3 viewPos) {
	vec3 worldPos = vec3(gbufferModelViewInverse * vec4(viewPos * 100.0, 1.0));
	vec2 planeCoord0 = worldPos.xz / (length(worldPos.y) + length(worldPos.xz));
		planeCoord0 += cameraPosition.xz * 0.00001;
		planeCoord0 += frameTimeCounter * 0.0001;
		planeCoord0 = floor(planeCoord0 * 600.0) / 600.0;

	vec2 planeCoord1 = worldPos.xz / (length(worldPos.y) + length(worldPos.xz));
		planeCoord1 *= 0.35;
		planeCoord1 += cameraPosition.xz * 0.00001;
		planeCoord1 += frameTimeCounter * 0.0001;
		planeCoord1 = floor(planeCoord1 * 1000.0) / 1000.0;
	
	float star = 1.0;

	float smallStars = getNoise(planeCoord0 + 10.0);
			smallStars*= getNoise(planeCoord0 + 14.0);
			smallStars = clamp(smallStars - 0.75, 0.0, 1.0);
			smallStars *= 7;
			smallStars *= smallStars * 0.85;

	float bigStars = getNoise(planeCoord1 + 11.0);
			bigStars*= getNoise(planeCoord1 + 13.0);
			bigStars*= getNoise(planeCoord1 + 15.0);
			bigStars = clamp(bigStars - 0.75, 0.0, 1.0);
			bigStars *= 21;
			bigStars *= bigStars * 2.0;

	star = smallStars + bigStars;
	
	star = clamp(star - 0.8125, 0.0, 1.0);
		
	color += star * pow(endCol.rgb, vec3(0.8));
}
#endif