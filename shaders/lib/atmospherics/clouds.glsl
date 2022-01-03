void erodeCoord(inout vec2 coord, in float currentStep, in float erosionStrength){
	coord += cos(mix(vec2(cos(currentStep * 1.00), sin(currentStep * 2.00)), vec2(cos(currentStep * 3.0), sin(currentStep * 4.00)), currentStep) * erosionStrength);
}

#if CLOUDS == 1 && defined OVERWORLD
float CloudSample(vec2 coord, vec2 wind, float sampleStep) {
	float noise = 0.0;
	float mult = 1.0;
	for (int i = 1; i < 7; i++){
		noise += texture2D(noisetex, coord * mult + wind * mult).r * i;
		mult *= 0.5;
	}

	noise *= 1.0 + rainStrength * 0.15;
	float multiplier = CLOUD_THICKNESS * sampleStep;

	noise = max(noise - CLOUD_AMOUNT, 0.0) * multiplier;
	noise = noise / sqrt(noise * noise + 0.75);

	return noise;
}

vec4 DrawCloud(vec3 viewPos, float dither, vec3 lightCol, vec3 ambientCol) {
	#ifdef TAA
	dither = fract(16.0 * frameTimeCounter + dither);
	#endif
	
	float cloud = 0.0, cloudLighting = 0.0;

	float currentStep = dither * 0.5;
	
	vec3 nViewPos = normalize(viewPos);
	float VoU = dot(nViewPos, upVec);
	float VoL = dot(nViewPos, lightVec);

	vec2 wind = vec2(
		frametime * CLOUD_SPEED * 0.0005,
		sin(frametime * CLOUD_SPEED * 0.001) * 0.005
	) * CLOUD_HEIGHT / 15.0;

	vec3 cloudColor = vec3(0.0);

	vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);

	float halfVoL = VoL * shadowFade * 0.5 + 0.5;
	float halfVoLSqr = halfVoL * halfVoL;
	float scattering = pow6(halfVoL);
	float noiseLightFactor = (2.0 - 1.5 * VoL * shadowFade) * CLOUD_THICKNESS * 0.5;

	for (int i = 0; i < 2; i++) {
		vec3 planeCoord = wpos * ((CLOUD_HEIGHT + currentStep * 4.0) / wpos.y) * 0.005;
		vec2 coord = cameraPosition.xz * 0.00025 + planeCoord.xz;
		erodeCoord(coord, currentStep, 0.05);

		float noise = CloudSample(coord, wind, 0.5);

		float sampleLighting = pow(currentStep, 1.125 * halfVoLSqr + 0.875) * 0.8 + 0.2;
		sampleLighting *= 1.0 - pow(noise, noiseLightFactor);

		cloudLighting = mix(cloudLighting, sampleLighting, noise * (1.0 - cloud * cloud));
		cloud = mix(cloud, 1.0, noise);

		currentStep += 0.5;
	}	
	cloudLighting = mix(cloudLighting, 1.0, (1.0 - cloud * cloud) * scattering * 0.5);
	cloudColor = mix(
		ambientCol * (0.5 * sunVisibility + 0.5),
		lightCol * (0.85 + 1.15 * scattering),
		cloudLighting
	);
	cloudColor *= 1.0 - 0.6 * rainStrength;
	cloud *= clamp(1.0 - exp(-24.0 * VoU + 0.5), 0.0, 1.0) * (1.0 - 0.6 * rainStrength);
	cloudColor *= CLOUD_BRIGHTNESS * (0.5 - 0.25 * (1.0 - sunVisibility) * (1.0 - rainStrength));

	#if MC_VERSION >= 11800
	cloudColor *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	cloudColor *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif
	
	#ifdef UNDERGROUND_SKY
	cloud *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif
	
	return vec4(cloudColor, cloud * cloud * CLOUD_OPACITY);
}
#endif

float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

void DrawStars(inout vec3 color, vec3 viewPos) {
	vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos, 1.0));
	vec3 planeCoord = wpos / (wpos.y + length(wpos.xz));

	vec2 wind = vec2(frametime, 0.0);
	vec2 coord = planeCoord.xz * 0.4 + cameraPosition.xz * 0.0001 + wind * 0.001;
		 coord = floor(coord * 1024.0) / 1024.0;
	
	float VoU = clamp(dot(normalize(viewPos), upVec), 0.0, 1.0);
	float multiplier = VoU * 16.0 * (1.0 - rainStrength) * (1.0 - sunVisibility * 0.5);
	
	float star = GetNoise(coord.xy);
		  star*= GetNoise(coord.xy + 0.10);
		  star*= GetNoise(coord.xy + 0.23);
	star = clamp(star - 0.75, 0.0, 1.0) * multiplier;

	#if MC_VERSION >= 11800
	star *= clamp((cameraPosition.y + 70.0) / 8.0, 0.0, 1.0);
	#else
	star *= clamp((cameraPosition.y + 6.0) / 8.0, 0.0, 1.0);
	#endif

	#ifdef UNDERGROUND_SKY
	star *= mix(clamp((cameraPosition.y - 48.0) / 16.0, 0.0, 1.0), 1.0, eBS);
	#endif
		
	color += star * lightNight;
}

#ifdef AURORA
#include "/lib/color/auroraColor.glsl"

float AuroraSample(vec2 coord, vec2 wind, float VoU) {
	float noise = texture2D(noisetex, coord * 0.0625  + wind * 0.25).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.03125 + wind * 0.15).b * 3.0;

	noise = max(1.0 - 4.0 * (0.5 * VoU + 0.5) * abs(noise - 3.0), 0.0);

	return noise;
}

vec3 DrawAurora(vec3 viewPos, float dither, int samples) {
	#ifdef TAA
	dither = fract(16.0 * frameTimeCounter + dither);
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
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < samples; i++) {
			vec3 planeCoord = wpos * ((8.0 + currentStep * 8.0) / wpos.y) * 0.005;

			vec2 coord = cameraPosition.xz * 0.00004 + planeCoord.xz;
			coord += vec2(coord.y, -coord.x) * 0.5;

			float noise = AuroraSample(coord, wind, VoU);
			
			if (noise > 0.0) {
				noise *= texture2D(noisetex, coord * 0.125 + wind * 0.25).b;
				noise *= 0.5 * texture2D(noisetex, coord + wind * 16.0).b + 0.75;
				noise = noise * noise * 3.0 * sampleStep;
				noise *= max(sqrt(1.0 - length(planeCoord.xz) * 3.75), 0.0);

				vec3 auroraColor = mix(auroraLowCol, auroraHighCol, pow(currentStep, 0.4));
				aurora += noise * auroraColor * exp2(-6.0 * i * sampleStep);
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

#if defined END_NEBULA || defined OVERWORLD_NEBULA
#include "/lib/color/nebulaColor.glsl"

float nebulaSample(vec2 coord, vec2 wind, float VoU) {
	float noise = texture2D(noisetex, coord * 1.0000 - wind * 0.25).b * 2.5;
		  noise-= texture2D(noisetex, coord * 0.5000 + wind * 0.20).b * 1.5;
		  noise+= texture2D(noisetex, coord * 0.2500 - wind * 0.15).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.1250 + wind * 0.10).b * 3.5;

	noise *= NEBULA_AMOUNT;
	
	noise = max(1.0 - 2.0 * (0.5 * VoU + 0.5) * abs(noise - 3.5), 0.0);

	return noise;
}

vec3 DrawNebula(vec3 viewPos) {
	int samples = 2;

	float dither = Bayer64(gl_FragCoord.xy) * 0.4;
	float VoU = dot(normalize(viewPos.xyz), upVec);

	#ifdef END
	VoU = abs(VoU);
	#endif

	float visFactor = 1.0;

	#ifdef OVERWORLD
	float auroraVisibility = 0.0;

	#ifdef NEBULA_AURORA_CHECK
	#if defined AURORA && defined WEATHER_PERBIOME
	auroraVisibility = isCold * isCold;
	#endif
	#endif

	visFactor = (moonVisibility - rainStrength) * (moonVisibility - auroraVisibility) * (1.0 - auroraVisibility);
	#endif

	float sampleStep = 1.0 / samples;
	float currentStep = dither * sampleStep;

	vec2 wind = vec2(
		frametime * NEBULA_SPEED * 0.000125,
		sin(frametime * NEBULA_SPEED * 0.05) * 0.00125
	);

	vec3 nebula = vec3(0.0);
	vec3 nebulaColor = vec3(0.0);

	#ifdef END
	if (visFactor > 0){
	#else
	if (visFactor > 0 && VoU > 0){
	#endif
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < samples; i++) {
			#ifdef END
			vec3 planeCoord = wpos * (16.0 + currentStep * -8.0) * 0.001 * NEBULA_STRETCHING;
			#else
			vec3 planeCoord = wpos * ((6.0 + currentStep * -2.0) / wpos.y) * 0.005 * NEBULA_STRETCHING;
			#endif

			vec2 coord = (cameraPosition.xz * 0.00001 + planeCoord.xz);

			#ifdef END
			coord += vec2(coord.y, -coord.x) * 1.00 * NEBULA_DISTORTION;
			#endif

			erodeCoord(coord, currentStep, 0.1);
			erodeCoord(coord, currentStep, 0.2);

			float noise = nebulaSample(coord, wind, VoU);
				 noise *= texture2D(noisetex, coord * 0.25 + wind * 0.25).b;
				 noise *= texture2D(noisetex, coord + wind * 16.0).b + 0.75;
				 noise = noise * noise * 2.0 * sampleStep;
				 noise *= max(sqrt(1.0 - length(planeCoord.xz) * 4.0), 0.0);

			#if defined END
			nebulaColor = mix(endCol.rgb, endCol.rgb * 1.25, currentStep);
			#elif defined OVERWORLD
			nebulaColor = mix(nebulaLowCol, nebulaHighCol, currentStep);
			#endif

			nebula += noise * nebulaColor * exp2(-4.0 * i * sampleStep);
			currentStep += sampleStep;
		}
	}

	return nebula * NEBULA_BRIGHTNESS * visFactor;
}
#endif