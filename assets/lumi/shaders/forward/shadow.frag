#include frex:shaders/api/material.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/userconfig.glsl

/******************************************************
  lumi:shaders/forward/shadow.frag
******************************************************/

#ifndef NAME_TAG_SHADOW
in float v_managed;
#endif

void frx_pipelineFragment() {
#ifndef NAME_TAG_SHADOW
	if (v_managed == 0.) {
		discard;
	}
#endif

	gl_FragDepth = gl_FragCoord.z;
}
