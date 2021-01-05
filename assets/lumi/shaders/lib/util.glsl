/*******************************************************
 *  lumi:shaders/lib/util.glsl                         *
 *******************************************************/

#define hdr_gamma 2.2
#define hdr_gammaAdjust(x) pow(x, vec3(hdr_gamma))
#define hdr_gammaAdjustf(x) pow(x, hdr_gamma)
#define l2_min3(vec) min(vec.x, min(vec.y, vec.z))
#define l2_max3(vec) max(vec.x, max(vec.y, vec.z))
// #define ldr_ravel(vec) vec4(1.0/(vec.rgb + 1.0), vec.a)
// #define hdr_unravel(vec) vec4((1.0/vec.rgb) - 1.0, vec.a)

float l2_clampScale(float e0, float e1, float v){
    return clamp((v-e0)/(e1-e0), 0.0, 1.0);
}
