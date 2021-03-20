#include lumi:shaders/context/post/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/basic.vert                       *
 *******************************************************/

attribute vec2 in_uv;

void main()
{
    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
}
