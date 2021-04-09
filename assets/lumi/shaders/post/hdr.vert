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
#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
varying mat4 v_cloud_rotator;
#endif
varying vec2 v_invSize;
varying float v_fov;
varying float v_night;
varying float v_not_in_void;
varying float v_near_void_core;
varying float v_blindness;
varying vec3 v_sky_radiance;

attribute vec2 in_uv;

void main()
{
    #if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
        v_cloud_rotator = l2_rotationMatrix(vec3(0.0, 1.0, 0.0), PI * 0.25);
    #endif
    
    v_invSize = 1.0/frxu_size;
    v_star_rotator = l2_rotationMatrix(vec3(1.0, 0.0, 1.0), frx_worldTime() * PI);
    v_fov = 2.0 * atan(1.0/frx_projectionMatrix()[1][1]) * 180.0 / PI;
    v_night = min(smoothstep(0.50, 0.54, frx_worldTime()), smoothstep(1.0, 0.96, frx_worldTime()));
    v_not_in_void = l2_clampScale(-1.0, 0.0, frx_cameraPos().y);
    v_near_void_core = l2_clampScale(10.0, -90.0, frx_cameraPos().y) * 1.8;
    
    vec3 sunRadiance = l2_sunRadiance(1.0, frx_worldTime(), frx_rainGradient(), frx_thunderGradient());
    vec3 moonRadiance = l2_moonRadiance(1.0, frx_worldTime(), frx_rainGradient(), frx_thunderGradient());
    v_sky_radiance = frx_worldFlag(FRX_WORLD_IS_MOONLIT)
        ? moonRadiance : mix(moonRadiance, sunRadiance, frx_skyLightTransitionFactor());

    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
    lightsource_setVars();

    v_skycolor = hdr_skyColor();
    v_blindness = frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
        ? l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(v_skycolor))
        : 0.0;
}
