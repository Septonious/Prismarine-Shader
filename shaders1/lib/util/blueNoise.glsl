uniform sampler2D depthtex2;

float BlueNoise(vec2 coord) {
    float noise = texelFetch(depthtex2, ivec2(coord) % 1024, 0).r;
    noise = fract(noise);

    return noise;
}