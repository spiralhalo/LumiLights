#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/context/global/experimental.glsl
#include lumi:shaders/lib/util.glsl

/***********************************************************
 *  lumi:shaders/forward/tonemap.glsl                     *
 ***********************************************************/

vec3 ldr_reinhardJodieTonemap(in vec3 v) {
    float l = frx_luminance(v);
    vec3 tv = v / (1.0f + v);
    return mix(v / (1.0f + l), tv, tv);
}

#if LUMI_Tonemap == LUMI_Tonemap_Vibrant
vec3 ldr_vibrantTonemap(in vec3 hdrColor){
    return hdrColor / (frx_luminance(hdrColor) + vec3(1.0));
}
#endif

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

vec4 ldr_tonemap(vec4 a)
{
    vec3 c = a.rgb;
    #ifdef HIGH_CONTRAST
        c = frx_toneMap(c);
    #else
        c = hable_filmic(c);
    #endif
    // Somehow the film tonemap requires clamping. I don't understand..
    c = pow(clamp(c, 0.0, 1.0), vec3(1.0 / hdr_gamma));
    return vec4(c, a.a);
}

vec3 ldr_tonemap3(vec3 a)
{
    vec3 c = a.rgb;
    #ifdef HIGH_CONTRAST
        c = frx_toneMap(c);
    #else
        c = hable_filmic(c);
    #endif
    c = pow(clamp(c, 0.0, 1.0), vec3(1.0 / hdr_gamma));
    return c;
}
