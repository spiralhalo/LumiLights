#include lumi:shaders/post/common/header.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/func/flat_cloud.glsl
#include lumi:shaders/lib/util.glsl

/*******************************************************
 *  lumi:shaders/post/hdr_half.vert                    *
 *******************************************************/

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
vert_out mat4 v_cloud_rotator;
#endif

vert_out vec2 v_invSize;
vert_out float v_blindness;

void main()
{
    basicFrameSetup();
    atmos_generateAtmosphereModel();

#ifdef HALF_REFLECTION_RESOLUTION
    gl_Position.xy -= (gl_Position.xy - vec2(-1., -1.)) * .5;
#endif

#if CLOUD_RENDERING == CLOUD_RENDERING_FLAT
    v_cloud_rotator = computeCloudRotator();
#endif

    v_invSize = 1.0/frxu_size;
    v_blindness = frx_playerHasEffect(FRX_EFFECT_BLINDNESS)
        ? l2_clampScale(0.5, 1.0, 1.0 - frx_luminance(frx_vanillaClearColor()))
        : 0.0;
}
