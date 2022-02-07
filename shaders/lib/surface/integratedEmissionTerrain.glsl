#ifdef FSH
void getIntegratedEmission(inout float emissive, in vec2 lightmap, in vec4 albedo, in vec3 worldPos){
	float newEmissive = 0.0;

	#ifdef EMISSIVE_ORES
    if (mat > 99.9 && mat < 100.1) { // Emissive Ores
        float stoneDif = max(abs(albedo.r - albedo.g), max(abs(albedo.r - albedo.b), abs(albedo.g - albedo.b)));
        float ore = max(max(stoneDif - 0.175, 0.0), 0.0);
        newEmissive = sqrt(ore) * GLOW_STRENGTH;
    } 
	#endif
	if (mat > 100.9 && mat < 101.1) { // Crying Obsidian and Respawn Anchor
		newEmissive = (albedo.b - albedo.r) * albedo.r * GLOW_STRENGTH;
        newEmissive *= newEmissive * 0.5 * GLOW_STRENGTH;
	} else if (mat > 101.9 && mat < 102.1) { // Command Block
        vec3 comPos = fract(worldPos.xyz + cameraPosition.xyz);
             comPos = abs(comPos - vec3(0.5));

        float comPosM = min(max(comPos.x, comPos.y), min(max(comPos.x, comPos.z), max(comPos.y, comPos.z)));
        newEmissive = 0.0;

        if (comPosM < 0.1882) { // Command Block Center
            vec3 dif = vec3(albedo.r - albedo.b, albedo.r - albedo.g, albedo.b - albedo.g);
            dif = abs(dif);
            newEmissive = float(max(dif.r, max(dif.g, dif.b)) > 0.1);
            newEmissive *= float(albedo.r > 0.44 || albedo.g > 0.29);
        }

	} else if (mat > 102.9 && mat < 103.1) { // Warped Stem & Hyphae
		newEmissive = float(length(albedo.rgb) > 0.49) * 0.4 + float(length(albedo.rgb) > 0.59);
		newEmissive *= GLOW_STRENGTH;
	} else if (mat > 103.9 && mat < 104.1) { // Crimson Stem & Hyphae
		newEmissive = (float(length(albedo.rgb) > 0.47) * 0.5 + float(length(albedo.rgb) > 0.50)) * float(albedo.b < 0.25);
		newEmissive *= GLOW_STRENGTH;
	} else if (mat > 104.9 && mat < 105.1) { // Warped Nether Warts
		newEmissive = pow2(float(albedo.g - albedo.b)) * GLOW_STRENGTH;
	} else if (mat > 105.9 && mat < 106.1) { // Warped Nylium
		newEmissive = float(albedo.g > albedo.b && albedo.g > albedo.r) * pow(float(albedo.g - albedo.b), 3.0) * GLOW_STRENGTH;
	} else if (mat > 107.9 && mat < 108.1) { // Amethyst
		newEmissive = float(length(albedo.rgb) > 0.5) * 0.05 * GLOW_STRENGTH;
	} else if (mat > 109.9 && mat < 110.1) { // Glow Lichen
		newEmissive = (1.0 - lightmap.y) * float(albedo.r > albedo.g || albedo.r > albedo.b) * 3.0;
	} else if (mat > 110.9 && mat < 111.1) { // Redstone Things
		newEmissive = float(albedo.r > 0.9) * 0.1 * GLOW_STRENGTH;
	} else if (mat > 111.9 && mat < 112.1) { // Soul Emissives
		newEmissive = float(length(albedo.rgb) > 0.9) * 0.05 * GLOW_STRENGTH;
	} else if (mat > 112.9 && mat < 113.1) { // Brewing Stand
		newEmissive = float(albedo.r > 0.65) * 0.25 * GLOW_STRENGTH;
	} else if (mat > 113.9 && mat < 114.1) { // Glow berries
		newEmissive = float(albedo.r > albedo.g || albedo.r > albedo.b) * GLOW_STRENGTH;
	} else if (mat > 114.9 && mat < 115.1) { // Torches
		newEmissive = float(length(albedo.rgb) > 0.99) * 0.1 * GLOW_STRENGTH;
	} else if (mat > 115.9 && mat < 116.1) { // Furnaces
		newEmissive = float(albedo.r > 0.8) * 0.5 * GLOW_STRENGTH;
	} else if (mat > 116.9 && mat < 117.1) { // Chorus
		newEmissive = float(albedo.r > albedo.b || albedo.r > albedo.g) * float(albedo.b > 0.575) * 0.25 * GLOW_STRENGTH;
	} else if (mat > 117.9 && mat < 118.1) { // Enchanting Table
		newEmissive = float(length(albedo.rgb) > 0.75) * 0.25 * GLOW_STRENGTH;
	} else if (mat > 118.9 && mat < 119.1) { // Soul Campfire
		newEmissive = float(albedo.b > albedo.r || albedo.b > albedo.g) * 0.05 * GLOW_STRENGTH;
	} else if (mat > 119.9 && mat < 120.1) { // Normal Campfire
		newEmissive = float(albedo.r > 0.65 && albedo.b < 0.35) * 0.1 * GLOW_STRENGTH;
	} else if (mat > 121.9 && mat < 122.1) {
		newEmissive = 0.25;
	} else if (mat > 122.9 && mat < 123.1) {
		newEmissive = 0.0;
	}

	#ifdef DEBRIS_HIGHLIGHT
	if (mat > 120.9 && mat < 121.1) newEmissive = 1.0;
	#endif

	#if defined OVERWORLD && defined EMISSIVE_FLOWERS
	if (isPlant > 0.9 && isPlant < 1.1){ // Flowers
		newEmissive = float(albedo.b > albedo.g || albedo.r > albedo.g) * GLOW_STRENGTH * 0.05 * (1.0 - rainStrength);
	}
	#endif

	#ifdef POWDER_SNOW_HIGHLIGHT
	if (mat > 29999.9 && mat < 30000.1){
		newEmissive = 1.0;
	} 
	#endif

	emissive += newEmissive;
}
#endif


#ifdef VSH
void getIntegratedEmissionMaterials(inout float mat, inout float isPlant){
	isPlant = 0.0;
	#ifdef EMISSIVE_ORES
	if (mc_Entity.x == 20000) mat = 100.0;
	#endif
	if (mc_Entity.x == 20001) mat = 101.0;
	if (mc_Entity.x == 20002) mat = 102.0;
	if (mc_Entity.x == 20003) mat = 103.0;
	if (mc_Entity.x == 20004) mat = 104.0;
	if (mc_Entity.x == 20005) mat = 105.0;
	if (mc_Entity.x == 20006) mat = 106.0;
	if (mc_Entity.x == 20008) mat = 108.0;
	if (mc_Entity.x == 20010) mat = 110.0;
	if (mc_Entity.x == 20011) mat = 111.0;
	if (mc_Entity.x == 20012) mat = 112.0;
	if (mc_Entity.x == 20013) mat = 113.0;
	if (mc_Entity.x == 20014) mat = 114.0;
	if (mc_Entity.x == 20015) mat = 115.0;
	if (mc_Entity.x == 20016) mat = 116.0;
	if (mc_Entity.x == 20017) mat = 117.0;
	if (mc_Entity.x == 20018) mat = 118.0;
	if (mc_Entity.x == 20019) mat = 119.0;
	if (mc_Entity.x == 20020) mat = 120.0;
	if (mc_Entity.x == 20022) mat = 122.0;
	if (mc_Entity.x == 20023) mat = 123.0;

	#ifdef DEBRIS_HIGHLIGHT
	if (mc_Entity.x == 20021) mat = 121.0;
	#endif

	#if defined EMISSIVE_FLOWERS && defined OVERWORLD
	if (mc_Entity.x == 10101) isPlant = 1.0;
	#endif

	#ifdef POWDER_SNOW_HIGHLIGHT
	if (mc_Entity.x == 30000) mat = 30000;
	#endif
}
#endif