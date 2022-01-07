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

vec4 TemporalAccumulation(inout vec3 color, float tempData, sampler2D temptex) {
	vec3 coord = vec3(texCoord, texture2DLod(depthtex1, texCoord, 0.0).r);
	vec2 prvCoord = Reprojection(coord);
	
	vec3 tempColor = texture2DLod(temptex, prvCoord, 0.0).gba;
	vec2 view = vec2(viewWidth, viewHeight);

	if (tempColor == vec3(0.0)) return vec4(tempData, color);
	
	vec2 velocity = (texCoord - prvCoord.xy) * view;
	float blendFactor = float(
		prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
		prvCoord.y > 0.0 && prvCoord.y < 1.0
	);
	blendFactor *= exp(-length(velocity));
	
	color = mix(color, tempColor, blendFactor);

	return vec4(tempData, color);
}
