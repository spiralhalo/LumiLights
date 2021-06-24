#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/tmo.glsl
#include lumi:shaders/lib/util.glsl

/***********************************************************
 *  lumi:shaders/func/tonemap.glsl                         *
 ***********************************************************/

#ifdef POST_SHADER

vec3 ldr_tonemap3noGamma(vec3 a)
{
    vec3 c = a.rgb;
    float exposure = 1.0;

#ifdef HIGH_CONTRAST_ENABLED
    float eyeBrightness = frx_smoothedEyeBrightness().y * atmos_celestIntensity();

    eyeBrightness *= eyeBrightness;
    exposure = mix(2.0, 1.0, eyeBrightness);
#endif

    c = frx_toneMap(c * exposure);

    // In the past ACES requires clamping for some reason
    c = clamp(c, 0.0, 1.0);
    return c;
}

vec3 ldr_tonemap3(vec3 a)
{
    vec3 c = ldr_tonemap3noGamma(a);
    float capBrightness = min(1.5, frx_viewBrightness());
    float viewGamma = hdr_gamma + capBrightness;

    c = pow(c, vec3(1.0 / viewGamma));
    return c;
}

vec4 ldr_tonemap(vec4 a)
{
    vec3 c = ldr_tonemap3(a.rgb);

    return vec4(c, a.a);
}

#endif
