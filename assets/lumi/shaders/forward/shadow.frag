#include frex:shaders/api/material.glsl
#include frex:shaders/api/player.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/common/compat.glsl
#include lumi:shaders/common/userconfig.glsl

/******************************************************
  lumi:shaders/forward/shadow.frag
******************************************************/

frag_in float v_managed;

frx_FragmentData frx_createPipelineFragment() {
    return frx_FragmentData (
        texture(frxs_baseColor, frx_texcoord, frx_matUnmippedFactor() * -4.0),
        frx_color
    );
}

void frx_writePipelineFragment(in frx_FragmentData fragData) {
    #ifndef NAME_TAG_SHADOW
    if (v_managed == 0.) {
        discard;
    }
    #endif

    gl_FragDepth = gl_FragCoord.z;
}
