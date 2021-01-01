/*******************************************************
 *  lumi:shaders/lib/util.glsl                         *
 *******************************************************/

#define hdr_gamma 2.2
#define hdr_gammaAdjust(x) pow(x, vec3(hdr_gamma))
#define hdr_gammaAdjustf(x) pow(x, hdr_gamma)

float l2_clampScale(float e0, float e1, float v){
    return clamp((v-e0)/(e1-e0), 0.0, 1.0);
}
