float getNoise(vec3 pos){
	float noise  = texture2D(noisetex, (pos.xz + vec2(frametime * WATER_SPEED) * 0.1 + pos.y) * 0.0025).r;
		  noise += texture2D(noisetex, (pos.xz - vec2(frametime * WATER_SPEED) * 0.2 - pos.y) * 0.0025).r;
		  noise -= texture2D(noisetex, (pos.xz + vec2(frametime * WATER_SPEED) * 0.3 + pos.y) * 0.0025).r;
		  noise += texture2D(noisetex, (pos.xz - vec2(frametime * WATER_SPEED) * 0.4 - pos.y) * 0.0025).r;

	return noise * 0.75;
}

float getCaustics(vec3 pos){
	float h0 = getNoise(pos);
	float h1 = getNoise(pos + vec3(1.0, 0.0, 0.0));
	float h2 = getNoise(pos + vec3(-1.0, 0.0, 0.0));
	float h3 = getNoise(pos + vec3(0.0, 0.0, 1.0));
	float h4 = getNoise(pos + vec3(0.0, 0.0, -1.0));
	
	float caustic = max((1.0 - abs(0.5 - h0)) * (1.0 - (abs(h1 - h2) + abs(h3 - h4))), 0.0);
	caustic = pow4(caustic);
	
	return caustic;
}