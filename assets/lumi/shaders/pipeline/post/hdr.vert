#include lumi:shaders/pipeline/post/common.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/pipeline/post/simple.vert             *
 *******************************************************/

attribute vec2 in_uv;
const vec3 day_sky = vec3(0.52, 0.69, 1.0);
const vec3 day_fog = vec3(0.75, 0.84375, 1.0);

vec3 calc_sky_color()
{
    if (frx_isWorldTheOverworld()) {
        vec3 clear = frx_vanillaClearColor();
        float distanceToFog = distance(normalize(clear), normalize(day_fog));
        return mix(clear, day_sky, l2_clampScale(0.1, 0.05, distanceToFog));
    } else return frx_vanillaClearColor();
}

void main()
{
    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_skycolor = hdr_gammaAdjust(calc_sky_color()) /*hdr_skyStr*/;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
}
