#include lumi:shaders/common/userconfig.glsl

/******************************************************
  lumi:shaders/post/common/bloom.glsl
******************************************************/

const float BLOOM_INTENSITY_FLOAT = BLOOM_INTENSITY * 0.02; // / 50.0
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_SCALE * 0.04); // / 25.0
const vec2 BLOOM_UPSAMPLE_DIST_VEC = vec2(0.1); // / 50.0
const float BLOOM_CUTOFF_FLOAT = 0.2; // / 50.0

const float SKY_BLOOM_MULT = 0.5;

float l2_skyBloom()
{
    #if SKY_BLOOM_INTENSITY == 0
        return 0.0;
    #else
        return clamp(SKY_BLOOM_INTENSITY * 0.1, 0.0, 1.0) * SKY_BLOOM_MULT;
    #endif
}
