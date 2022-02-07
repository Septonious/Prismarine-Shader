#define pow2(x) x*x
#define pow3(x) x*x*x
#define pow6(x) x*x*x*x*x*x
#define pow4(x) pow2(pow2(x))
#define pow8(x) pow2(pow4(x))
#define pow12(x) pow2(pow6(x))
#define pow16(x) pow2(pow8(x))
#define pow24(x) pow2(pow12(x))
#define pow32(x) pow2(pow16(x))
#define pow64(x) pow2(pow32(x))
#define pow128(x) pow2(pow64(x))
#define pow256(x) pow2(pow128(x))
#define pow512(x) pow2(pow256(x))

#define sum3(x) x+x+x
#define sum4(x) x+x+x+x
#define sum6(x) sum3(x) + sum3(x)
#define sum8(x) sum4(x) + sum4(x)
#define sum12(x) sum6(x) + sum6(x)
#define sum16(x) sum8(x) + sum8(x)

#define _cube_smooth(x) ((x * x) * (3.0 - 2.0 * x))

float cube_smooth(float x) {
    return _cube_smooth(x);
}
vec3 cube_smooth(vec3 x) {
    return _cube_smooth(x);
}