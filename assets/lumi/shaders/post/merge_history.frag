#include lumi:shaders/context/post/header.glsl

/******************************************************
  lumi:shaders/post/merge_history.frag
******************************************************/
uniform sampler2D u_current;
uniform sampler2DArray u_history;

void main()
{
  vec4 color = 0.2 * texture2D(u_current, v_texcoord);
  for (int i = 0; i < 4; i++) {
    color += 0.2 * texture2DArray(u_history, vec3(v_texcoord, float(i)));
  }
  gl_FragData[0] = color;
}
