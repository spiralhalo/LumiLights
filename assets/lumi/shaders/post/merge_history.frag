#include lumi:shaders/context/post/header.glsl

/******************************************************
  lumi:shaders/post/merge_history.frag
******************************************************/
uniform sampler2D u_current;
uniform sampler2D u_history0;

void main()
{
  if (frx_lastViewMatrix() == frx_viewMatrix()
     && frx_lastCameraPos() == frx_cameraPos()) {
    gl_FragData[0] = 0.5 * texture2D(u_current, v_texcoord)
                  + 0.5 * texture2D(u_history0, v_texcoord);
  } else {
    gl_FragData[0] = texture2D(u_current, v_texcoord);
  }
}
