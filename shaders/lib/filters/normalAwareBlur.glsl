//huge thanks to niemand for helping me with depth aware blur

#ifndef NETHER
uniform float far, near;

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}
#endif

float[22] KernelOffsets = float[22](
    0.06859499456330513,
    0.06758866276489915,
    0.0646582434672158,
    0.060053666382841785,
    0.05415271962490796,
    0.0474096695217294,
    0.040297683205704475,
    0.033255219213172406,
    0.0266443947480172,
    0.02072610900858287,
    0.015652912895289143,
    0.011477248433445731,
    0.008170442697260053,
    0.0056470130318222785,
    0.0037892897088649766,
    0.0024686712595739543,
    0.0015614781087428572,
    0.0009589072215278897,
    0.0005717237762381398,
    0.0003309526350349594,
    0.0001860014387826795,
    0.0001014935746937502
);

vec4 NormalAwareBlur(sampler2D colortex, vec2 direction) {
    vec4 blur = vec4(0.0);
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord).xy));

	float centerDepth = texture2D(depthtex0, texCoord.xy).x;

    #ifndef NETHER
	float centerDepthLinear = GetLinearDepth(centerDepth);
    #endif

	float totalWeight = 0.0;

    for(int i = -DENOISE_QUALITY; i < DENOISE_QUALITY; i++) {
        float weight = KernelOffsets[abs(i)];
        vec2 offset = direction * pixelSize * float(i) * DENOISE_STRENGTH * float(centerDepth > 0.56);

		vec3 currentNormal = normalize(DecodeNormal(texture2D(colortex6, texCoord + offset).xy));
		float normalWeight = pow(clamp(dot(normal, currentNormal), 0.0001, 1.0), 8.0);
		     weight *= normalWeight;

		#ifndef NETHER
		float currentDepth = GetLinearDepth(texture2D(depthtex0, texCoord + offset).x);
		float depthWeight = pow(clamp(1.0 - abs(currentDepth - centerDepthLinear), 0.0001, 1.0), 64.0); 
		     weight *= depthWeight;
		#endif			

        blur += texture2D(colortex, texCoord + offset) * weight;
        totalWeight += weight;
    }
    return blur / totalWeight;
}