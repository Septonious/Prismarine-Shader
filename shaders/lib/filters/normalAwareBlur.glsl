//huge thanks to niemand for helping me with depth aware blur

#ifndef NETHER
uniform float far, near;

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}
#endif

#define TAU 6.28318530

float gaussian(float x, float sigma) {
    return (1.0 / sqrt(TAU * sigma)) * exp(-pow2(x) / (2.0 * pow2(sigma)));
}
float gaussian(vec2 i, float sigma) {
    return exp( -0.5* dot(i/=sigma,i) ) / ( 6.28 * sigma*sigma );
}

vec4 NormalAwareBlur(sampler2D colortex) {
    vec4 blur = vec4(0.0);

	vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord).xy));

	float centerDepth0 = texture2D(depthtex0, texCoord.xy).x;

    #ifndef NETHER
	float centerDepth1 = GetLinearDepth(texture2D(depthtex0, texCoord.xy).x);
    #endif

	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	float totalWeight = 0.0;

    for(int i = -DENOISE_QUALITY; i <= DENOISE_QUALITY; i++) {
        for(int j = -DENOISE_QUALITY; j <= DENOISE_QUALITY; j++) {
            float weight = gaussian(vec2(i, j), 32000);

			vec2 offset = vec2(i, j) * pixelSize * DENOISE_STRENGTH;

			vec3 currentNormal = normalize(DecodeNormal(texture2D(colortex6, texCoord + offset).xy));
			float normalWeight = pow(clamp(dot(normal, currentNormal), 0.0001, 1.0), 8.0);
			weight *= normalWeight;

			#ifndef NETHER
			float currentDepth = GetLinearDepth(texture2D(depthtex0, texCoord + offset).x);
			float depthWeight = pow(clamp(1.0 - abs(currentDepth - centerDepth1), 0.0001, 1.0), 256.0); 
			weight *= depthWeight;
			#endif			

            blur += texture2D(colortex, texCoord + offset) * weight;
            totalWeight += weight;
        }
    }
    return blur / totalWeight;
}