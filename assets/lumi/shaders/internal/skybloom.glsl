#include lumi:config.glsl

/***********************************************************
 *  lumi:shaders/internal/skybloom.glsl                    *
 ***********************************************************/

const float hdr_skyBloom = 0.5;

float l2_skyBloom() {
#ifdef LUMI_ApplySkyBloom
    return clamp(LUMI_SkyBloomIntensity * 0.1, 0.0, 1.0) * hdr_skyBloom;
#else
    return 0.0;
#endif
}
