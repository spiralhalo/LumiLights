#include lumi:shaders/context/post/header.glsl

/******************************************************
  lumi:shaders/post/merge_history.frag
******************************************************/
uniform sampler2D u_current;
uniform sampler2D u_history0;

varying float v_cameraStatic;

void main()
{
  if (v_cameraStatic > 0.0) {
    gl_FragData[0] = 0.5 * texture2D(u_current, v_texcoord)
                  + 0.5 * texture2D(u_history0, v_texcoord);
  } else {
    gl_FragData[0] = texture2D(u_current, v_texcoord);
  }
}
