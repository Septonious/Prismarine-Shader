vec3 RGB2HSV(vec3 c){
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float GetHardcodedEmission(vec3 albedo) {
    #if EMISSIVE_HARDCODED == 0
    vec3 hsv = RGB2HSV(albedo.rgb);
    float saturatedEmission = clamp(hsv.y * 3.125 - 0.125, 0.0, 1.0) * pow(hsv.z, 4.0);
    float desaturatedEmission = clamp(hsv.z * 7.0 - 6.0, 0.0, 1.0);
    float emission = max(saturatedEmission, desaturatedEmission) * 0.5;
    #else
    float emission = pow(max(max(albedo.r, albedo.g), albedo.b), 4.0) * 0.4;
    #endif

    return emission;
}