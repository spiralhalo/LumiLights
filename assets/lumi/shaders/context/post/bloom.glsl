#include lumi:bloom_config

/******************************************************
  lumi:shaders/context/post/bloom.glsl
******************************************************/

const float BLOOM_INTENSITY_FLOAT = BLOOM_INTENSITY / 50.0;
const vec2 BLOOM_DOWNSAMPLE_DIST_VEC = vec2(BLOOM_DOWNSAMPLE_DIST / 25.0, BLOOM_DOWNSAMPLE_DIST / 25.0);
const vec2 BLOOM_UPSAMPLE_DIST_VEC = vec2(BLOOM_UPSAMPLE_DIST / 50.0, BLOOM_UPSAMPLE_DIST / 50.0);
const float BLOOM_CUTOFF_FLOAT = BLOOM_CUTOFF / 50.0;
