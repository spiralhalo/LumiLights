#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/basic.vert                       *
 *******************************************************/

out vec2 v_invSize;

void main()
{
    v_invSize = 1.0 / frxu_size;
    vec4 screen = frxu_frameProjectionMatrix * vec4(in_vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
}
