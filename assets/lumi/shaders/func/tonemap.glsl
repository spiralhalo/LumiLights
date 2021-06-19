#include frex:shaders/api/player.glsl
#include frex:shaders/api/view.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/atmosphere.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/lib/util.glsl

/***********************************************************
 *  lumi:shaders/func/tonemap.glsl                         *
 ***********************************************************/

#ifdef POST_SHADER

vec3 ldr_reinhardJodieTonemap(in vec3 v) {
    float l = frx_luminance(v);
    vec3 tv = v / (1.0f + v);
    return mix(v / (1.0f + l), tv, tv);
}

vec3 ldr_vibrantTonemap(in vec3 hdrColor){
    return hdrColor / (frx_luminance(hdrColor) + vec3(1.0));
}

vec3 exposure_tonemap(vec3 x)
{
    #if TONE_PROFILE == TONE_PROFILE_AUTO_EXPOSURE
    float exposure = 1.0 - frx_smoothedEyeBrightness().y * atmos_celestIntensity(); /* * (0.5 + frx_ambientIntensity() * 0.5); // BAD */
    exposure *= exposure;
    exposure *= 4.5;
    exposure += 0.25;
    #else
    float exposure = 0.25;
    #endif
    return vec3(1.0) - exp(-x * exposure);
}

vec3 hable_tonemap_partial(vec3 x)
{
    float A = 0.15f;
    float B = 0.50f;
    float C = 0.10f;
    float D = 0.20f;
    float E = 0.02f;
    float F = 0.30f;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 hable_filmic(vec3 v)
{
    float exposure_bias = 2.0f;
    vec3 curr = hable_tonemap_partial(v * exposure_bias);

    vec3 W = vec3(11.2f);
    vec3 white_scale = vec3(1.0f) / hable_tonemap_partial(W);
    return curr * white_scale;
}

vec3 ldr_tonemap3noGamma(vec3 a)
{
    vec3 c = a.rgb;

    #if TONE_PROFILE == TONE_PROFILE_HIGH_CONTRAST_OLD
        c = frx_toneMap(c);
    #elif defined(HIGH_CONTRAST_ENABLED)
        c = exposure_tonemap(c);
    #else
        c = frx_toneMap(c);
    #endif

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
