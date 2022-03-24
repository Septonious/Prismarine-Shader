/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform sampler2D colortex1;

uniform float viewWidth, viewHeight;
uniform float aspectRatio;

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main scene
const int colortex1Format = RGBA16; //raw translucent, bloom, final scene
const int colortex2Format = RGBA16; //temporal data
const int colortex3Format = RGB8; //specular data
const int colortex8Format = RGBA16; //volumetric clouds
const int colortex9Format = RGBA16; //water reflection image
const int colortex10Format = RGBA16; //sspt
const int colortex11Format = RGBA16; //sspt
const int gaux1Format = R8; //cloud alpha, ao
const int gaux2Format = RGB10_A2; //reflection image
const int gaux3Format = RGB16; //normals
const int gaux4Format = RGB16; //fresnel
*/

const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;

const int noiseTextureResolution = 512;

const float drynessHalflife = 50.0;
const float wetnessHalflife = 300.0;

//Common Functions//
#if defined CAS || defined TAA
vec2 sharpenOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);

void SharpenFilter(inout vec3 color, vec2 coord) {
	float mult = MC_RENDER_QUALITY * 0.0625;
	vec2 view = 1.0 / vec2(viewWidth, viewHeight);

	color *= MC_RENDER_QUALITY * 0.25 + 1.0;

	for(int i = 0; i < 4; i++) {
		vec2 offset = sharpenOffsets[i] * view;
		color -= texture2DLod(colortex1, coord + offset, 0).rgb * mult;
	}
}
#endif

//Program//
void main() {
    vec2 newTexCoord = texCoord;

	vec3 color = texture2D(colortex1, newTexCoord).rgb;

	#if CHROMATIC_ABERRATION > 0
	float caStrength = 0.004 * CHROMATIC_ABERRATION;
	vec2 caScale = vec2(1.0 / aspectRatio, 1.0);
	color *= vec3(0.0,1.0,0.0);
	color += texture2D(colortex1, mix(newTexCoord, vec2(0.5), caScale * -caStrength)).rgb * vec3(1.0,0.0,0.0);
	color += texture2D(colortex1, mix(newTexCoord, vec2(0.5), caScale * -caStrength * 0.5)).rgb * vec3(0.5,0.5,0.0);
	color += texture2D(colortex1, mix(newTexCoord, vec2(0.5), caScale * caStrength * 0.5)).rgb * vec3(0.0,0.5,0.5);
	color += texture2D(colortex1, mix(newTexCoord, vec2(0.5), caScale* caStrength)).rgb * vec3(0.0,0.0,1.0);

	color /= vec3(1.5, 2.0, 1.5);
	#endif

	#if SHARPENING_STRENGTH > 0 && !defined DOF
	vec2 view = 1.0 / vec2(viewWidth, viewHeight);
	color *= SHARPENING_STRENGTH * 0.1 + 1.0;
	color -= texture2D(colortex1, texCoord.xy + vec2(1.0,  0.0) * view).rgb * SHARPENING_STRENGTH * 0.025;
	color -= texture2D(colortex1, texCoord.xy + vec2(0.0,  1.0) * view).rgb * SHARPENING_STRENGTH * 0.025;
	color -= texture2D(colortex1, texCoord.xy + vec2(-1.0, 0.0) * view).rgb * SHARPENING_STRENGTH * 0.025;
	color -= texture2D(colortex1, texCoord.xy + vec2(0.0, -1.0) * view).rgb * SHARPENING_STRENGTH * 0.025;
	#endif

    #if defined CAS || defined TAA
    SharpenFilter(color.rgb, newTexCoord);
    #endif

	gl_FragColor = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif