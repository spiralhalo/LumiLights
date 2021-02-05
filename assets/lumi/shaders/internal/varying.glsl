/***********************************************************
 *  lumi:shaders/internal/varying.glsl                     *
 ***********************************************************/

varying vec3 l2_viewPos;
varying vec3 l2_worldPos;
varying vec3 l2_tangent;

#ifdef LUMI_BUMP
varying vec2 bump_topRightUv;
#endif
