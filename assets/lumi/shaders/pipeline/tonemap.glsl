/***********************************************************
 *  lumi:shaders/pipeline/tonemap.glsl                     *
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
    vec3 c = a.rgb;
#if LUMI_Tonemap == LUMI_Tonemap_Film
    c = frx_toneMap(c);
#elif LUMI_Tonemap == LUMI_Tonemap_Vibrant
    c = hdr_vibrantTonemap(c);
#else
    c = hdr_reinhardJodieTonemap(c);
#endif
    // Somehow the film tonemap requires clamping. I don't understand..
    a.rgb = pow(clamp(c, 0.0, 1.0), vec3(1.0 / hdr_gamma));
}
