/***********************************************************
 *  lumi:shaders/internal/varying.glsl                     *
 ***********************************************************/

varying vec3 l2_viewPos;

#ifdef LUMI_BUMP
varying vec3 bump_tangent;
varying vec2 bump_topRightUv;
#endif
