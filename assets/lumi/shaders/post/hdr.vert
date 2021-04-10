#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/common/lightsource.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/hdr.vert                *
 *******************************************************/

out mat4 v_star_rotator;
#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
out mat4 v_cloud_rotator;
#endif
out vec2 v_invSize;
out float v_fov;
out float v_night;
out float v_not_in_void;
out float v_near_void_core;
out float v_blindness;
out vec3 v_sky_radiance;

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

    vec4 screen = frxu_frameProjectionMatrix * vec4(in_vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
    lightsource_setVars();

    v_skycolor = hdr_skyColor();
    v_blindness = frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
        ? l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(v_skycolor))
        : 0.0;
}
