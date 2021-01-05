#include lumi:shaders/internal/context.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/util.glsl

/***********************************************************
 *  lumi:shaders/pipeline/tonemap.glsl                     *
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

vec3 ldr_tonemap(vec3 a) {
    vec3 c = a;
#if LUMI_Tonemap == LUMI_Tonemap_Film
    c = frx_toneMap(c);
#elif LUMI_Tonemap == LUMI_Tonemap_Vibrant
    c = ldr_vibrantTonemap(c);
#else
    c = ldr_reinhardJodieTonemap(c);
#endif
    // Somehow the film tonemap requires clamping. I don't understand..
    c = pow(clamp(c, 0.0, 1.0), vec3(1.0 / hdr_gamma));
    return c;
}
