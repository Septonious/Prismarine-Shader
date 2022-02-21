#ifdef FSH
void getIntegratedEmission(inout float emission, inout vec2 lightmap, in vec4 albedo){
	float newEmissive = 0.0;

    if (mat > 99.9 && mat < 100.1){ // Dragon
        newEmissive = float(length(albedo.rgb) > 0.75);
    }

    if (mat > 100.9 && mat < 101.1){ // Stray
        newEmissive = float(length(albedo.rgb) > 0.999999999999999999 && albedo.r > 0.9019) * 0.25; // that was painful
    }

    if (mat > 101.9 && mat < 102.1){ // Witch
        newEmissive = float(albedo.g > 0.3 && albedo.r < 0.3);
    }

    if (mat > 102.9 && mat < 103.1){ // Magma Cube
        newEmissive = 0.75 + float(albedo.g > 0.5 && length(albedo.rgb) > 0.5) * 0.25;
        lightmap.x *= newEmissive;
    }

    if (mat > 103.9 && mat < 104.1){ // Drowned && Shulker
        newEmissive = float(length(albedo.rgb) > 0.99) * 0.25;
    }

    if (mat > 104.9 && mat < 105.1){ // JellySquid
        newEmissive = 0.025 + float(length(albedo.rgb) > 0.99) * 0.25;
        lightmap.x *= newEmissive;
    }

    if (mat > 105.9 && mat < 106.1){ // End Crystal
        newEmissive = float(albedo.r > 0.5 && albedo.g < 0.55);
        lightmap.x *= newEmissive;
    }

    if (mat > 106.9 && mat < 107.1){ // Warden
        newEmissive = float(albedo.b > 0.5 && length(albedo.rgb) > 0.7);
    }

    #ifdef ENTITY_BRIGHT_PARTS_HIGHLIGHT
    newEmissive += float(length(albedo.rgb) > 0.85);
    #endif

	emission += newEmissive * GLOW_STRENGTH;
}
#endif


#ifdef VSH
void getIntegratedEmissionEntities(inout float mat){
    if (entityId == 20000) mat = 100.0;
	if (entityId == 20001) mat = 101.0;
	if (entityId == 20002) mat = 102.0;
	if (entityId == 20003) mat = 103.0;
	if (entityId == 20004) mat = 104.0;
	if (entityId == 20005) mat = 105.0;
	if (entityId == 20006) mat = 106.0;
    if (entityId == 20007) mat = 107.0;
	if (entityId == 20008) mat = 108.0;
	if (entityId == 20010) mat = 110.0;
	if (entityId == 20011) mat = 111.0;
	if (entityId == 20012) mat = 112.0;
	if (entityId == 20013) mat = 113.0;
	if (entityId == 20014) mat = 114.0;
	if (entityId == 20015) mat = 115.0;
	if (entityId == 20016) mat = 116.0;
	if (entityId == 20017) mat = 117.0;
	if (entityId == 20018) mat = 118.0;
	if (entityId == 20019) mat = 119.0;
	if (entityId == 20020) mat = 120.0;
}
#endif