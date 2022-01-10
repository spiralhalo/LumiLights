#include lumi:shaders/pass/header.glsl

#include lumi:shaders/prog/shading.glsl

uniform sampler2D u_input;
uniform sampler2D u_vanilla_depth;
uniform sampler2D u_translucent_depth;
uniform sampler2DArray u_gbuffer_lightnormal;

out vec4 fragColor;

/*******************************************************
 *  lumi:shaders/pass/detectsky0.frag
 *******************************************************/

void main() {
	// sky detect utility
	float dSolid = texture(u_vanilla_depth, v_texcoord).r;
	float dTrans = texture(u_translucent_depth, v_texcoord).r;
	float id = dTrans < dSolid ? ID_TRANS_LIGT : ID_SOLID_LIGT;
	fragColor.r = lightmapRemap(texture(u_gbuffer_lightnormal, vec3(v_texcoord, id)).y);
}
