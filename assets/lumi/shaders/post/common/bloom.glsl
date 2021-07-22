#include lumi:shaders/common/userconfig.glsl

/******************************************************
  lumi:shaders/post/common/bloom.glsl
******************************************************/

const float BLOOM_INTENSITY_FLOAT = BLOOM_INTENSITY / 50.0;
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_SCALE / 25.0);
const vec2 BLOOM_UPSAMPLE_DIST_VEC = max(vec2(0.1), BLOOM_DOWNSAMPLE_DIST_VEC * 0.1);
