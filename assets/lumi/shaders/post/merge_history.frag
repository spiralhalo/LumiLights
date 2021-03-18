#include lumi:shaders/context/post/header.glsl

/******************************************************
  lumi:shaders/post/merge_history.frag
******************************************************/
uniform sampler2D u_current;
uniform sampler2D u_history0;
uniform sampler2D u_history1;
uniform sampler2D u_history2;

void main()
{
  gl_FragData[0] = 0.25 * texture2D(u_current, v_texcoord)
                  + 0.25 * texture2D(u_history0, v_texcoord)
                  + 0.25 * texture2D(u_history1, v_texcoord)
                  + 0.25 * texture2D(u_history2, v_texcoord);
}
