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

#ifdef SSGI
//Uniforms//
uniform float timeBrightness;

uniform sampler2D colortex1, colortex11;

//Program//
void main() {
    vec3 color = texture2D(colortex1, texCoord).rgb;
    vec3 gi = texture2D(colortex11, texCoord).rgb;

    color.rgb *= vec3(1.0) + gi * 8.0 * ILLUMINATION_STRENGTH;

    /* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(color, 1.0);
}

#else

void main(){
    discard;
}

#endif

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