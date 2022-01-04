//huge thanks to niemand for helping me with depth aware blur

#ifndef NETHER
uniform float far, near;

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}
#endif

#define TAU 6.28318530

float gaussian(float x, float sigma) {
    return (1.0 / sqrt(TAU * sigma)) * exp(-pow2(x) / (2.0 * pow2(sigma)));
}

vec3 NormalAwareBlur() {
    vec3 blur = vec3(0.0);

	vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord).xy));

	float centerDepth0 = texture2D(depthtex0, texCoord.xy).x;

    #ifndef NETHER
	float centerDepth1 = GetLinearDepth2(texture2D(depthtex1, texCoord.xy).x);
    #endif

	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	float totalWeight = 0.0;

    for(int i = -DENOISE_QUALITY; i <= DENOISE_QUALITY; i++) {
        for(int j = -DENOISE_QUALITY; j <= DENOISE_QUALITY; j++) {
            float weight = gaussian(i, 128.0) * gaussian(j, 128.0);

			vec2 offset = vec2(i, j) * DENOISE_STRENGTH * pixelSize;

			vec3 currentNormal = normalize(DecodeNormal(texture2D(colortex6, texCoord + offset).xy));
			float normalWeight = pow8(clamp(dot(normal, currentNormal), 0.0001, 1.0));
			weight *= normalWeight;

			#ifndef NETHER
			float currentDepth = GetLinearDepth2(texture2D(depthtex1, texCoord + offset).x);
			float depthWeight = (clamp(1.0 - abs(currentDepth - centerDepth1), 0.0001, 0.1)); 
			weight *= depthWeight;
			#endif			

            blur += texture2D(colortex11, texCoord + offset).rgb * weight;
            totalWeight += weight;
        }
    }
    return blur / totalWeight;
}