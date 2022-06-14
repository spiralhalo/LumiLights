#include lumi:shaders/pass/header.glsl

/*******************************************************
 *  lumi:shaders/post/shadow_v.frag
 *******************************************************/

uniform sampler2D u_vanilla_depth;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_particles_depth;

uniform sampler2DArray u_gbuffer_lightnormal;

layout(location = 0) out vec3 shadowValue;

vec3 getDepth(vec2 texcoord) {
	return vec3(
		texture(u_vanilla_depth, texcoord).r,
		texture(u_translucent_depth, texcoord).r,
		texture(u_particles_depth, texcoord).r);
}

vec3 getShadowValue(vec2 texcoord) {
	return texture(u_gbuffer_lightnormal, vec3(texcoord, ID_SHADOW_VAL + frxu_layer)).rgb;
}

vec3 getWeight(vec3 depthBase, vec3 depthSampled) {
	return step(depthBase, depthSampled);// min(vec3(1.0), abs(depthBase - depthSampled) / 0.1);
}

void main() {
	const vec2 plus[] = vec2[](
		vec2(0, -2),
		vec2(0, 2)
	);

	vec3 depth = getDepth(v_texcoord);
	shadowValue = getShadowValue(v_texcoord);
	vec3 weightTotal = vec3(1.0);

	for (int i = 0; i < 2; i++) {
		vec2 sample = v_texcoord + plus[i] * v_invSize;
		vec3 weight = getWeight(depth, getDepth(sample));
		shadowValue += getShadowValue(sample) * weight;
		weightTotal += weight;
	}

	shadowValue /= weightTotal;
}
