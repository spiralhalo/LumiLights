#include lumi:shaders/pipeline/post/common.glsl
#include lumi:shaders/pipeline/post/common_vertex.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/hdr.vert                *
 *******************************************************/

attribute vec2 in_uv;

void main()
{
    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_skycolor = hdr_gammaAdjust(calc_sky_color()) /*hdr_skyStr*/;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
}
