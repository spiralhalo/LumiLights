#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/context/post/bloom.glsl
#include frex:shaders/lib/sample.glsl

/******************************************************
  lumi:shaders/pipeline/post/downsample.frag
******************************************************/
uniform sampler2D u_input;

void main()
{
	gl_FragData[0] = frx_sample13(u_input, v_texcoord, BLOOM_DOWNSAMPLE_DIST_VEC / frxu_size, max(0, frxu_lod - 1));
}
