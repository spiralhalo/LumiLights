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
varying float v_fov;
varying float v_night;
varying float v_not_in_void;
varying float v_near_void_core;
varying vec3 v_sky_radiance;
varying vec3 v_fogcolor;

attribute vec2 in_uv;

void main()
{
    v_star_rotator = l2_rotationMatrix(vec3(1.0, 0.0, 1.0), frx_worldTime() * PI);
    v_cloud_rotator = l2_rotationMatrix(vec3(0.0, 1.0, 0.0), PI * 0.25);
    v_fov = 2.0 * atan(1.0/frx_projectionMatrix()[1][1]) * 180.0 / PI;
    v_night = min(smoothstep(0.50, 0.54, frx_worldTime()), smoothstep(1.0, 0.96, frx_worldTime()));
    v_not_in_void = l2_clampScale(-1.0, 0.0, frx_cameraPos().y);
    v_near_void_core = l2_clampScale(10.0, -90.0, frx_cameraPos().y) * 1.8;
    v_sky_radiance = frx_worldFlag(FRX_WORLD_IS_MOONLIT)
        ? l2_moonRadiance(1.0, frx_worldTime(), frx_skyLightTransitionFactor())
        : l2_sunRadiance(1.0, frx_worldTime(), frx_skyLightTransitionFactor(), frx_rainGradient());

    vec4 screen = gl_ProjectionMatrix * vec4(gl_Vertex.xy * frxu_size, 0.0, 1.0);
    gl_Position = vec4(screen.xy, 0.2, 1.0);
    v_texcoord = in_uv;
    v_up = frx_normalModelMatrix() * vec3(0.0, 1.0, 0.0);
    lightsource_setVars();

    vec3 skyColor = hdr_skyColor();
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        float thunderFactor = frx_rainGradient() *0.5 + frx_thunderGradient() *0.5;
        skyColor *= (1.0 - thunderFactor * 0.9);
        vec3 grayScale = vec3(frx_luminance(skyColor));
        v_fogcolor = mix(skyColor, grayScale, thunderFactor);
    } else {
        v_fogcolor = skyColor;
    }
    v_skycolor = skyColor;
}
