#include lumi:shaders/pass/header.glsl

/******************************************************
  lumi:shaders/pass/depth.frag
******************************************************/

uniform sampler2D u_vanilla_depth;

out float viewZ;

void main()
{
	float depth = texture(u_vanilla_depth, v_texcoord).r;
	vec4 temp = frx_inverseProjectionMatrix * vec4(v_texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	viewZ = -temp.z / temp.w;
}
