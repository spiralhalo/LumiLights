#include lumi:bloom_config

/******************************************************
  lumi:shaders/context/post/bloom.glsl
******************************************************/

const float BLOOM_INTENSITY_FLOAT = BLOOM_INTENSITY / 50.0;
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_DOWNSAMPLE_DIST / 25.0, BLOOM_DOWNSAMPLE_DIST / 25.0);
const vec2 BLOOM_UPSAMPLE_DIST_VEC = vec2(BLOOM_UPSAMPLE_DIST / 50.0, BLOOM_UPSAMPLE_DIST / 50.0);
const float BLOOM_CUTOFF_FLOAT = BLOOM_CUTOFF / 50.0;

const float SKY_BLOOM_MULT = 0.5;

float l2_skyBloom()
{
    #if SKY_BLOOM_INTENSITY == 0
        return 0.0;
    #else
        return clamp(SKY_BLOOM_INTENSITY * 0.1, 0.0, 1.0) * SKY_BLOOM_MULT;
    #endif
}
