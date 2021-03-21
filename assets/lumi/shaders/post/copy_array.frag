#include lumi:shaders/context/post/header.glsl

/******************************************************
  lumi:shaders/post/copy_array.frag
******************************************************/
uniform sampler2DArray u_input;

void main()
{
    gl_FragData[0] = texture2DArray(u_input, vec3(v_texcoord, frxu_layer));
}
