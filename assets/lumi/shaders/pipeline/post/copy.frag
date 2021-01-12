#include lumi:shaders/pipeline/post/common.glsl

/******************************************************
  lumi:shaders/pipeline/post/copy.frag
******************************************************/
uniform sampler2D u_input;

void main()
{
	gl_FragData[0] = texture2D(u_input, v_texcoord);
}
