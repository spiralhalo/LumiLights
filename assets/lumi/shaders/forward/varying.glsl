#include lumi:shaders/context/global/experimental.glsl

/***********************************************************
 *  lumi:shaders/forward/varying.glsl                     *
 ***********************************************************/

varying vec3 l2_viewpos;
varying vec2 pv_lightcoord;
varying float pv_ao;
varying float pv_diffuse;

#if defined(SHADOW_MAP_PRESENT) && !defined(DEFERRED_SHADOW)
varying vec4 pv_shadowpos;
#endif
