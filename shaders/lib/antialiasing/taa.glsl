/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Previous frame reprojection from Chocapic13
vec2 Reprojection(vec3 pos) {
	pos = pos * 2.0 - 1.0;

	vec4 viewPosPrev = gbufferProjectionInverse * vec4(pos, 1.0);
	viewPosPrev /= viewPosPrev.w;
	viewPosPrev = gbufferModelViewInverse * viewPosPrev;

	vec3 cameraOffset = cameraPosition - previousCameraPosition;
	cameraOffset *= float(pos.z > 0.56);

	vec4 previousPosition = viewPosPrev + vec4(cameraOffset, 0.0);
	previousPosition = gbufferPreviousModelView * previousPosition;
	previousPosition = gbufferPreviousProjection * previousPosition;
	return previousPosition.xy / previousPosition.w * 0.5 + 0.5;
}

vec2 neighbourhoodOffsets[8] = vec2[8](
	vec2( 0.0, -1.0),
	vec2(-1.0,  0.0),
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0, -1.0),
	vec2( 1.0, -1.0),
	vec2(-1.0,  1.0),
	vec2( 1.0,  1.0)
);

vec3 RGBToYCoCg(vec3 col) {
	return vec3(
		col.r * 0.25 + col.g * 0.5 + col.b * 0.25,
		col.r * 0.5 - col.b * 0.5,
		col.r * -0.25 + col.g * 0.5 + col.b * -0.25
	);
}

vec3 YCoCgToRGB(vec3 col) {
	float n = col.r - col.b;
	return vec3(n + col.g, col.r + col.b, n - col.g);
}

vec3 ClipAABB(vec3 q,vec3 aabb_min, vec3 aabb_max){
	vec3 p_clip = 0.5 * (aabb_max + aabb_min);
	vec3 e_clip = 0.5 * (aabb_max - aabb_min) + 0.00000001;

	vec3 v_clip = q - vec3(p_clip);
	vec3 v_unit = v_clip.xyz / e_clip;
	vec3 a_unit = abs(v_unit);
	float ma_unit = max(a_unit.x, max(a_unit.y, a_unit.z));

	if (ma_unit > 1.0)
		return vec3(p_clip) + v_clip / ma_unit;
	else
		return q;
}

vec3 NeighbourhoodClamping(vec3 color, vec3 tempColor, vec2 view, sampler2D colortex) {
	vec3 minclr = RGBToYCoCg(color);
	vec3 maxclr = minclr;

	for(int i = 0; i < 8; i++) {
		vec2 offset = neighbourhoodOffsets[i] * view;
		vec3 clr = texture2D(colortex, texCoord + offset).rgb;

		clr = RGBToYCoCg(clr);
		minclr = min(minclr, clr); maxclr = max(maxclr, clr);
	}

	tempColor = RGBToYCoCg(tempColor);
	tempColor = ClipAABB(tempColor, minclr, maxclr);

	return YCoCgToRGB(tempColor);
}

vec4 TemporalAA(inout vec3 color, float tempData, sampler2D colortex, sampler2D temptex) {
	vec3 coord = vec3(texCoord, texture2DLod(depthtex1, texCoord, 0).r);
	vec2 prvCoord = Reprojection(coord);
	
	vec3 tempColor = texture2D(temptex, prvCoord).gba;
	vec2 view = vec2(viewWidth, viewHeight);

	if(tempColor == vec3(0.0)){
		return vec4(tempData, color);
	}
	
	tempColor = NeighbourhoodClamping(color, tempColor, 1.0 / view, colortex);
	
	vec2 velocity = (texCoord - prvCoord.xy) * view;
	float blendFactor = float(
		prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
		prvCoord.y > 0.0 && prvCoord.y < 1.0
	);
	blendFactor *= exp(-length(velocity)) * 0.4 + 0.55;
	
	color = mix(color, tempColor, blendFactor);
	return vec4(tempData, color);
}

#if defined GI_ACCUMULATION && defined SSPT
vec4 getViewPos(vec2 coord, float z0){
	vec4 screenPos = vec4(coord, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	return viewPos /= viewPos.w;
}

vec3 ToWorld(vec3 pos) {
	return mat3(gbufferModelViewInverse) * pos + gbufferModelViewInverse[3].xyz;
}

vec4 TemporalAccumulation(inout vec3 color, float tempData, sampler2D colortex, sampler2D temptex) {
	float z0 = texture2DLod(depthtex0, texCoord, 0).r;
	float shouldWeAccumulate = texture2D(colortex6, texCoord).a;

	vec3 coord = vec3(texCoord, texture2DLod(depthtex1, texCoord, 0).r);
	vec2 prvCoord = Reprojection(coord);
	vec2 view = vec2(viewWidth, viewHeight);
	vec2 velocity = (texCoord - prvCoord.xy) * view;

	vec3 tempColor = texture2D(temptex, prvCoord).gba;
	vec3 viewPos = getViewPos(texCoord, z0).xyz;
	
    float totalWeight = float(clamp(prvCoord, vec2(0.0), vec2(1.0)) == prvCoord);

	vec3 prevPos = ToWorld(getViewPos(prvCoord, z0).xyz);
    vec3 delta = ToWorld(viewPos.xyz) - prevPos;
	
    float posWeight = max(exp(-dot(delta, delta) * 3.0), 0.0);
    totalWeight *= GI_ACCUMULATION_STRENGTH * posWeight * (1.0 - float(z0 < 0.56)) * shouldWeAccumulate;
	#ifdef GI_VELOCITY_WEIGHT
	totalWeight *= exp(-length(velocity));
	#endif
	
	color = clamp(mix(color, tempColor, totalWeight), vec3(0.0), vec3(65e3));

	return vec4(tempData, color);
}
#endif