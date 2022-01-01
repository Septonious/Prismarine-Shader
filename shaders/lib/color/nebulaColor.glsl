vec3 nebulaLowColSqrt = vec3(NEBULA_LR, NEBULA_LG, NEBULA_LB) * NEBULA_LI / 255.0;
vec3 nebulaLowCol = nebulaLowColSqrt * nebulaLowColSqrt;
vec3 nebulaHighColSqrt = vec3(NEBULA_HR, NEBULA_HG, NEBULA_HB) * NEBULA_HI / 255.0;
vec3 nebulaHighCol = nebulaHighColSqrt * nebulaHighColSqrt;