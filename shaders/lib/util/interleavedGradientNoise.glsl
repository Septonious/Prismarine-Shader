ivec2 interleave_vec = ivec2(1125928, 97931);
#define interleaved_z 52.9829189
float fixed2float = 1.0 / exp2(24.0);

float IGN(ivec2 seed, int t) {
    ivec2 components = ivec2(seed + 5.588238 * t) * interleave_vec;
    return fract(((components.x + components.y) & int(exp2(24) - 1)) * (fixed2float * interleaved_z));
}