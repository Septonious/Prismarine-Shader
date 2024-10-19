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
uniform float viewHeight, viewWidth;

uniform sampler2D colortex0;

#ifdef BLOOM
//Optifine Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
float ph = 1.0 / viewHeight;
float pw = 1.0 / viewWidth;

float weight[7] = float[7](1.0, 6.0, 15.0, 20.0, 15.0, 6.0, 1.0);

//Common Functions//
vec3 BloomTile(float lod, vec2 coord, vec2 offset) {
	vec3 bloom = vec3(0.0);
	float scale = exp2(lod);
	coord = (coord - offset) * scale;
	float padding = 0.5 + 0.005 * scale;

	if (abs(coord.x - 0.5) < padding && abs(coord.y - 0.5) < padding) {
		for(int i = -3; i < 3; i++) {
			for(int j = -3; j < 3; j++) {
				float wg = weight[i + 3] * weight[j + 3];
				#ifdef ANAMORPHIC_BLOOM
				vec2 pixelOffset = vec2((float(i) - 2.0) * pw, 0.0);
				#else
				vec2 pixelOffset = vec2(i * pw, j * ph);
				#endif
				vec2 sampleCoord = coord + pixelOffset * scale;
				bloom += texture2D(colortex0, sampleCoord).rgb * wg;
			}
		}
		bloom /= 4096.0;
	}

	return pow(bloom / 128.0, vec3(0.25));
}
#endif

//Program//
void main() {
	#ifdef BLOOM
	vec3 blur =  BloomTile(1.0, texCoord, vec2(0.0      , 0.0   ));
	     blur += BloomTile(2.0, texCoord, vec2(0.51     , 0.0   ));
	     blur += BloomTile(3.0, texCoord, vec2(0.51     , 0.26  ));
	     blur += BloomTile(4.0, texCoord, vec2(0.645    , 0.26  ));
	     blur += BloomTile(5.0, texCoord, vec2(0.7175   , 0.26  ));
		
		 blur = clamp(blur, vec3(0.0), vec3(1.0));
	#else
	vec3 blur = texture2D(colortex0, texCoord.xy).rgb;
	#endif

    /* DRAWBUFFERS:1 */
	gl_FragData[0] = vec4(blur, 1.0);
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