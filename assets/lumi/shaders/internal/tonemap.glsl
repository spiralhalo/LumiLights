/***********************************************************
 *  lumi:shaders/internal/tonemap.glsl                     *
 ***********************************************************/

#define TONEMAP_HDR 0
#define TONEMAP_VIBRANT 1
#define TONEMAP_FILM 2

vec3 hdr_reinhardJodieTonemap(in vec3 v) {
    float l = frx_luminance(v);
    vec3 tv = v / (1.0f + v);
    return mix(v / (1.0f + l), tv, tv);
}

#if TONEMAP_MODE == TONEMAP_VIBRANT
vec3 hdr_vibrantTonemap(in vec3 hdrColor){
	return hdrColor / (frx_luminance(hdrColor) + vec3(1.0));
}
#endif

void tonemap(inout vec4 a) {
#if TONEMAP_MODE == TONEMAP_FILM
    a.rgb = pow(frx_toneMap(a.rgb), vec3(1.0 / hdr_gamma));
#elif TONEMAP_MODE == TONEMAP_VIBRANT
    a.rgb = pow(hdr_vibrantTonemap(a.rgb), vec3(1.0 / hdr_gamma));
#else
    a.rgb = pow(hdr_reinhardJodieTonemap(a.rgb), vec3(1.0 / hdr_gamma));
#endif
}
