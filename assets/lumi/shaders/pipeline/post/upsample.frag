#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/context/post/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/pipeline/post/upsample.frag
******************************************************/
uniform sampler2D u_input;
uniform sampler2D u_prior;

void main()
{
	vec4 prior = frx_sampleTent(u_prior, v_texcoord, BLOOM_UPSAMPLE_DIST_VEC / frxu_size, frxu_lod + 1);
	gl_FragData[0] = texture2DLod(u_input, v_texcoord, frxu_lod) + prior;
}
