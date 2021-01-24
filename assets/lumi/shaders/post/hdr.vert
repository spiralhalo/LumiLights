#include lumi:shaders/context/post/header.glsl
#include lumi:shaders/context/global/lightsource.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/hdr.vert                *
 *******************************************************/

varying mat4 v_star_rotator;
varying mat4 v_cloud_rotator;

attribute vec2 in_uv;

void main()
{
    v_star_rotator = l2_rotationMatrix(vec3(1.0, 0.0, 1.0), frx_worldTime() * PI);
    v_cloud_rotator = l2_rotationMatrix(vec3(0.0, 1.0, 0.0), PI * 0.25);

    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_skycolor = hdr_skyColor() /*hdr_skyStr*/;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
    lightsource_setVars();
}
