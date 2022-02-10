#ifdef WEATHER_PERBIOME
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna;
#ifdef FOG_PERBIOME
uniform float isForest, isJungle, isTaiga;
#endif
#endif

vec3 lightMorning    = vec3(LIGHT_MR,   LIGHT_MG,   LIGHT_MB)   * LIGHT_MI / 255.0;
vec3 lightDay        = vec3(LIGHT_DR,   LIGHT_DG,   LIGHT_DB)   * LIGHT_DI / 255.0;
vec3 lightEvening    = vec3(LIGHT_ER,   LIGHT_EG,   LIGHT_EB)   * LIGHT_EI / 255.0;
vec3 lightNight      = vec3(LIGHT_NR,   LIGHT_NG,   LIGHT_NB)   * LIGHT_NI * 0.3 / 255.0;

vec3 ambientMorning  = vec3(AMBIENT_MR, AMBIENT_MG, AMBIENT_MB) * AMBIENT_MI / 255.0;
vec3 ambientDay      = vec3(AMBIENT_DR, AMBIENT_DG, AMBIENT_DB) * AMBIENT_DI / 255.0;
vec3 ambientEvening  = vec3(AMBIENT_ER, AMBIENT_EG, AMBIENT_EB) * AMBIENT_EI / 255.0;
vec3 ambientNight    = vec3(AMBIENT_NR, AMBIENT_NG, AMBIENT_NB) * AMBIENT_NI * 0.3 / 255.0;

#ifdef WEATHER_PERBIOME
vec3 weatherRain     = vec3(WEATHER_RR, WEATHER_RG, WEATHER_RB) / 255.0 * WEATHER_RI;
vec3 weatherCold     = vec3(WEATHER_CR, WEATHER_CG, WEATHER_CB) / 255.0 * WEATHER_CI;
vec3 weatherDesert   = vec3(WEATHER_DR, WEATHER_DG, WEATHER_DB) / 255.0 * WEATHER_DI;
vec3 weatherBadlands = vec3(WEATHER_BR, WEATHER_BG, WEATHER_BB) / 255.0 * WEATHER_BI;
vec3 weatherSwamp    = vec3(WEATHER_SR, WEATHER_SG, WEATHER_SB) / 255.0 * WEATHER_SI;
vec3 weatherMushroom = vec3(WEATHER_MR, WEATHER_MG, WEATHER_MB) / 255.0 * WEATHER_MI;
vec3 weatherSavanna  = vec3(WEATHER_VR, WEATHER_VG, WEATHER_VB) / 255.0 * WEATHER_VI;

#ifdef FOG_PERBIOME
vec3 weatherForest = vec3(WEATHER_FR, WEATHER_FG, WEATHER_FB) / 255.0 * WEATHER_FI;
vec3 weatherTaiga  = vec3(WEATHER_TR, WEATHER_TG, WEATHER_TB) / 255.0 * WEATHER_TI;
vec3 weatherJungle = vec3(WEATHER_JR, WEATHER_JG, WEATHER_JB) / 255.0 * WEATHER_JI;
#endif

float weatherWeight = isCold + isDesert + isMesa + isSwamp + isMushroom + isSavanna;

#ifdef FOG_PERBIOME
float fogWeight = isCold + isDesert + isMesa + isSwamp + isMushroom + isSavanna + isForest + isJungle + isTaiga;

vec3 skyColSqrt0 = vec3(SKY_R, SKY_G, SKY_B) * SKY_I / 255.0;
vec3 fogCol0 = skyColSqrt0 * skyColSqrt0;

vec3 fogColBiome = mix(
	fogCol0.rgb,
	(
		weatherCold  * isCold  + weatherDesert   * isDesert   + weatherBadlands * isMesa    +
		weatherSwamp * isSwamp + weatherMushroom * isMushroom + weatherSavanna  * isSavanna +
		weatherForest * isForest + weatherJungle * isJungle + weatherTaiga * isTaiga
	) / max(fogWeight, 0.0001),
	fogWeight
);
#endif

vec3 weatherCol = mix(
	weatherRain,
	(
		weatherCold  * isCold  + weatherDesert   * isDesert   + weatherBadlands * isMesa    +
		weatherSwamp * isSwamp + weatherMushroom * isMushroom + weatherSavanna  * isSavanna
	) / max(weatherWeight, 0.0001),
	weatherWeight
);

#else
vec3 weatherCol = vec3(WEATHER_RR, WEATHER_RG, WEATHER_RB) / 255.0 * WEATHER_RI;
#endif

float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade = 1.0 - pow(1.0 - timeBrightness, 1.5);

vec3 CalcSunColor(vec3 morning, vec3 day, vec3 evening) {
	vec3 me = mix(morning, evening, mefade);
	return mix(me, day, dfade);
}

vec3 CalcLightColor(vec3 sun, vec3 night, vec3 weatherCol) {
	vec3 c = mix(night, sun, sunVisibility);
	c = mix(c, dot(c, vec3(0.299, 0.587, 0.114)) * weatherCol, rainStrength);
	return c * c;
}

vec3 lightSun   = CalcSunColor(lightMorning, lightDay, lightEvening);
vec3 ambientSun = CalcSunColor(ambientMorning, ambientDay, ambientEvening);

vec3 lightCol   = CalcLightColor(lightSun, lightNight, weatherCol.rgb);
vec3 ambientCol = CalcLightColor(ambientSun, ambientNight, weatherCol.rgb);