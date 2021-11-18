#include lumi:shaders/pass/header.glsl

/******************************************************
  lumi:shaders/pass/copy.frag
******************************************************/

uniform sampler2D u_input;

out vec4 fragColor;

void main()
{
	fragColor = texture(u_input, v_texcoord);
}
