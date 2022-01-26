//huge thanks to niemand for helping me with depth aware blur
uniform float far, near;

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

vec2 direction(float i, bool pass){
    if (pass) return vec2(0.0, i);
    else return vec2(i, 0.0);
}

const float sigma = DENOISE_QUALITY * 0.25;
float multiplier = 0.398942280401 / sigma;

float gaussian(float x) {
    return multiplier * exp(-x * x * 0.5 / (sigma * sigma));
}

vec3 NormalAwareBlur(sampler2D colortex, bool pass) {
    vec3 blur = vec3(0.0);
    vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord).xy));
    vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	float centerDepth = texture2D(depthtex0, texCoord.xy).x;
	float centerDepthLinear = GetLinearDepth(centerDepth);

    float totalWeight = 0.0;

    for(float i = -DENOISE_QUALITY; i <= DENOISE_QUALITY; i++){
        float weight = gaussian(i);
        vec2 offset = direction(i * DENOISE_STRENGTH * float(centerDepth > 0.56), pass) * pixelSize;

		vec3 currentNormal = normalize(DecodeNormal(texture2D(colortex6, texCoord + offset).xy));

        float currentDepth = texture2D(depthtex0, texCoord.xy).x;
        float currentDepthLinear = GetLinearDepth(currentDepth);
        weight *= pow(exp((clamp((1.0 - abs(currentDepthLinear - centerDepthLinear)) * dot(normal, currentNormal), 0.001, 1.0))), 32.0);

        blur += weight * texture2D(colortex, texCoord + offset).rgb;
        totalWeight += weight;
    }
    
    return blur / totalWeight;
}