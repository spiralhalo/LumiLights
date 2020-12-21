/***********************************************************
 *  lumi:shaders/internal/tonemap.glsl                     *
 ***********************************************************/

vec3 hdr_reinhardJodieTonemap(in vec3 v) {
    float l = frx_luminance(v);
    vec3 tv = v / (1.0f + v);
    return mix(v / (1.0f + l), tv, tv);
}

#if LUMI_Tonemap == LUMI_Tonemap_Vibrant
vec3 hdr_vibrantTonemap(in vec3 hdrColor){
	return hdrColor / (frx_luminance(hdrColor) + vec3(1.0));
}
#endif

void tonemap(inout vec4 a) {
#if LUMI_Tonemap == LUMI_Tonemap_Film
    a.rgb = pow(frx_toneMap(a.rgb), vec3(1.0 / hdr_gamma));
#elif LUMI_Tonemap == LUMI_Tonemap_Vibrant
    a.rgb = pow(hdr_vibrantTonemap(a.rgb), vec3(1.0 / hdr_gamma));
#else
    a.rgb = pow(hdr_reinhardJodieTonemap(a.rgb), vec3(1.0 / hdr_gamma));
#endif
}
