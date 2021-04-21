#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/lightsource.glsl
#include lumi:shaders/lib/rectangle.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/shading.vert                     *
 *******************************************************/

vert_out vec3 v_celest1;
vert_out vec3 v_celest2;
vert_out vec3 v_celest3;
vert_out vec2 v_invSize;
vert_out mat4 v_star_rotator;
vert_out float v_fov;
vert_out float v_night;
vert_out float v_not_in_void;
vert_out float v_near_void_core;
vert_out float v_blindness;

void main()
{
    basicFrameSetup();
    atmos_generateAtmosphereModel();

    float celestSize = frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? 200. : 300.;
    vec3 celestOrigin = vec3(-1024., 0., 0.);
    Rect theCelest = Rect(celestOrigin + vec3(.0, -celestSize, -celestSize),
                          celestOrigin + vec3(.0, -celestSize,  celestSize),
                          celestOrigin + vec3(.0,  celestSize, -celestSize));
    rect_applyMatrix(
        l2_rotationMatrix(vec3( 1.,  0.,  0.), atan(frx_skyLightVector().z, -frx_skyLightVector().y))
        * l2_rotationMatrix(vec3( 0.,  0., 1.), atan(frx_skyLightVector().y, frx_skyLightVector().x * sign(frx_skyLightVector().y)))
        , theCelest, 1.0);
    v_celest1 = theCelest.bottomLeft;
    v_celest2 = theCelest.bottomRight;
    v_celest3 = theCelest.topLeft;
    
    v_invSize = 1.0/frxu_size;
    v_star_rotator = l2_rotationMatrix(vec3(1.0, 0.0, 1.0), frx_worldTime() * PI);
    v_fov = 2.0 * atan(1.0/frx_projectionMatrix()[1][1]) * 180.0 / PI;
    v_night = min(smoothstep(0.50, 0.54, frx_worldTime()), smoothstep(1.0, 0.96, frx_worldTime()));
    v_not_in_void = l2_clampScale(-1.0, 0.0, frx_cameraPos().y);
    v_near_void_core = l2_clampScale(10.0, -90.0, frx_cameraPos().y) * 1.8;
    v_blindness = frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
        ? l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor()))
        : 0.0;
}
