#include lumi:shaders/common/userconfig.glsl

/******************************************************
  lumi:shaders/post/common/bloom.glsl
******************************************************/

const float BLOOM_INTENSITY_FLOAT = BLOOM_INTENSITY * 0.02; // / 50.0
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_SCALE * 0.04); // / 25.0
const vec2 BLOOM_UPSAMPLE_DIST_VEC = vec2(0.1); // / 50.0
const float BLOOM_CUTOFF_FLOAT = 0.2; // / 50.0
