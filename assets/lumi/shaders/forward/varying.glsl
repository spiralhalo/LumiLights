/***********************************************************
 *  lumi:shaders/forward/varying.glsl                     *
 ***********************************************************/

varying vec3 l2_viewpos;
varying vec2 pv_lightcoord;
varying float pv_ao;
varying float pv_diffuse;

#ifdef SHADOW_MAP_PRESENT
varying vec4 pv_shadowpos;
#endif
