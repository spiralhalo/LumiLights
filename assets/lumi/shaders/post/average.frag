#include lumi:shaders/context/post/header.glsl

/******************************************************
  lumi:shaders/post/average.frag
******************************************************/
uniform sampler2D u_input_one;
uniform sampler2D u_input_two;

void main()
{
    gl_FragData[0] = 0.5 * texture2D(u_input_one, v_texcoord) + 0.5 * texture2D(u_input_two, v_texcoord);
}
