//entirely stolen from sixthsurge's photon shader ;P

vec4 getCubicBSplineWeights(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * 0.1666666666666667;
}

// Source: https://stackoverflow.com/questions/13501081/efficient-bicubic-filtering-code-in-glsl
vec4 textureBicubic(sampler2D sampler, vec2 coord){
	vec2 res = textureSize(sampler, 0);
	vec2 texelSize = 1.0 / res;

	coord = coord * res - 0.5;

	vec2 fxy = fract(coord);
	coord -= fxy;

	vec4 xWeights = getCubicBSplineWeights(fxy.x);
	vec4 yWeights = getCubicBSplineWeights(fxy.y);

	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy;

	vec4 s = vec4(xWeights.xz + xWeights.yw, yWeights.xz + yWeights.yw);
	vec4 offset = c + vec4(xWeights.yw, yWeights.yw) / s;

	offset *= texelSize.xxyy;

	vec4 sample0 = texture(sampler, offset.xz);
	vec4 sample1 = texture(sampler, offset.yz);
	vec4 sample2 = texture(sampler, offset.xw);
	vec4 sample3 = texture(sampler, offset.yw);

	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);

	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

// Source: https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1 (MIT license)
vec4 textureCatmullRom(sampler2D sampler, vec2 coord) {
	vec2 res = textureSize(sampler, 0);
	vec2 texelSize = 1.0 / res;

    // We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
    // down the sample location to get the exact center of our "starting" texel. The starting texel will be at
    // location [1, 1] in the grid, where [0, 0] is the top left corner.
    vec2 samplePos = coord * res;
    vec2 texPos1 = floor(samplePos - 0.5) + 0.5;

    // Compute the fractional offset from our starting texel to our original sample location, which we'll
    // feed into the Catmull-Rom spline function to get our filter weights.
    vec2 f = samplePos - texPos1;

    // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
    // These equations are pre-expanded based on our knowledge of where the texels will be located,
    // which lets us avoid having to evaluate a piece-wise function.
    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
    // simultaneously evaluate the middle 2 samples from the 4x4 grid.
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);

    // Compute the final UV coordinates we'll use for sampling the texture
    vec2 texPos0 = texPos1 - 1.0;
    vec2 texPos3 = texPos1 + 2.0;
    vec2 texPos12 = texPos1 + offset12;

    texPos0 *= texelSize;
    texPos3 *= texelSize;
    texPos12 *= texelSize;

    vec4 result = vec4(0.0);
    result += texture(sampler, vec2(texPos0.x, texPos0.y), 0.0) * w0.x * w0.y;
    result += texture(sampler, vec2(texPos12.x, texPos0.y), 0.0) * w12.x * w0.y;
    result += texture(sampler, vec2(texPos3.x, texPos0.y), 0.0) * w3.x * w0.y;

    result += texture(sampler, vec2(texPos0.x, texPos12.y), 0.0) * w0.x * w12.y;
    result += texture(sampler, vec2(texPos12.x, texPos12.y), 0.0) * w12.x * w12.y;
    result += texture(sampler, vec2(texPos3.x, texPos12.y), 0.0) * w3.x * w12.y;

    result += texture(sampler, vec2(texPos0.x, texPos3.y), 0.0) * w0.x * w3.y;
    result += texture(sampler, vec2(texPos12.x, texPos3.y), 0.0) * w12.x * w3.y;
    result += texture(sampler, vec2(texPos3.x, texPos3.y), 0.0) * w3.x * w3.y;

    return result;
}