#include lumi:shaders/post/common/header.glsl

/******************************************************
  lumi:shaders/post/copy.frag
******************************************************/
uniform sampler2D u_input;

out vec4 fragColor;

void main()
{
	fragColor = texture(u_input, v_texcoord);
}
