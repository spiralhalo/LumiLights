#include lumi:shaders/pass/header.glsl

#include lumi:shaders/lib/taa_jitter.glsl
#include lumi:shaders/prog/shadow.glsl
#include lumi:shaders/prog/tile_noise.glsl
#include lumi:shaders/prog/water.glsl

/*******************************************************
 *  lumi:shaders/post/shadow0.frag
 *******************************************************/

uniform sampler2D u_vanilla_depth;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_particles_depth;

uniform sampler2DArray u_gbuffer_lightnormal;
uniform sampler2DArrayShadow u_gbuffer_shadow;

uniform sampler2D u_tex_noise;

layout(location = 0) out vec3 shadowValues;

float getShadow(vec2 texcoord, float depth) {
#ifdef SHADOW_MAP_PRESENT
#ifdef TAA_ENABLED
	vec2 uvJitter	   = taaJitter(v_invSize, frx_renderFrames);
	vec4 unjitteredPos = frx_inverseViewProjectionMatrix * vec4(2.0 * texcoord - uvJitter - 1.0, 2.0 * depth - 1.0, 1.0);
	vec4 shadowViewPos = frx_shadowViewMatrix * vec4(unjitteredPos.xyz / unjitteredPos.w, 1.0);
#else
	vec4 eyePos = frx_inverseViewProjectionMatrix * vec4(2.0 * texcoord - 1.0, 2.0 * depth - 1.0, 1.0);
	vec4 shadowViewPos = frx_shadowViewMatrix * vec4(eyePos.xyz / eyePos.w, 1.0);
#endif

	return simpleShadowFactor(u_gbuffer_shadow, shadowViewPos);
#else
	return 1.0;
#endif
}

void main() {
	// vec2 tileJitter = getRandomVec(u_tex_noise, v_texcoord, frxu_size).xy * 2.0 - 1.0;
	// tileJitter *= 0.0;

	vec2 uvOther = v_texcoord;// + tileJitter * v_invSize;

	float dVanilla = texture(u_vanilla_depth, uvOther).r;
	float dTrans = texture(u_translucent_depth, uvOther).r;

	vec2 uvSolid = refractSolidUV(u_gbuffer_lightnormal, u_vanilla_depth, dVanilla, dTrans);
	// uvSolid += tileJitter * v_invSize;

	float dSolid = texture(u_vanilla_depth, uvSolid).r;
	float dParts = texture(u_particles_depth, uvOther).r;

	shadowValues = vec3(
		getShadow(uvSolid, dSolid),
		getShadow(uvOther, dTrans),
		getShadow(uvOther, dParts));
}
