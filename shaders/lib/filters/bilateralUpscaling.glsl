float GetLinearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec4 BilateralUpscaling(sampler2D colortex, vec2 coord, float resolution){
    coord *= resolution;

    vec4 upscaledColor = vec4(0.0);
    float weight = 0.0;

    float depth = texture2D(depthtex0, coord).r;
    float linearDepth = GetLinearDepth(depth);

    ivec2 scaling = ivec2(1 / resolution);
    ivec2 scaledCoord = ivec2(coord * resolution) * scaling;
    ivec2 halfCoord = ivec2(coord * resolution);
    float depthMult = 1.0 / (far * near);
    ivec2 newCoord = ivec2((gl_FragCoord.xy * resolution + frameCounter % 2));

    ivec2 depthCoord = scaledCoord + ivec2(-2, -2) * scaling + newCoord * scaling;
    float currentDepth = GetLinearDepth(texelFetch(depthtex0, depthCoord, 0).r);
    float depthDifference = abs(currentDepth - linearDepth) < depthMult ? 1 : 1e-5;
    upscaledColor += texelFetch(colortex, halfCoord + ivec2(-2) + newCoord, 0) * depthDifference;
    weight += depthDifference;

    depthCoord = scaledCoord + ivec2(-2, 0) * scaling + newCoord * scaling;
    currentDepth = GetLinearDepth(texelFetch(depthtex0, depthCoord, 0).r);
    depthDifference = abs(currentDepth - linearDepth) < depthMult ? 1 : 1e-5;
    upscaledColor += texelFetch(colortex, halfCoord + ivec2(-2, 0) + newCoord, 0) * depthDifference;
    weight += depthDifference;

    depthCoord = scaledCoord + ivec2(0) + newCoord * scaling;
    currentDepth = GetLinearDepth(texelFetch(depthtex0, depthCoord, 0).r);
    depthDifference = abs(currentDepth - linearDepth) < depthMult ? 1 : 1e-5;
    upscaledColor += texelFetch(colortex, halfCoord + ivec2(0) + newCoord, 0) * depthDifference;
    weight += depthDifference;

    depthCoord = scaledCoord + ivec2(0, -2) * scaling + newCoord * scaling;
    currentDepth = GetLinearDepth(texelFetch(depthtex0, depthCoord, 0).r);
    depthDifference = abs(currentDepth - linearDepth) < depthMult ? 1 : 1e-5;
    upscaledColor += texelFetch(colortex, halfCoord + ivec2(0, -2) + newCoord, 0) * depthDifference;
    weight += depthDifference;

    return upscaledColor / weight;
}