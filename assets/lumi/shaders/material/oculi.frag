#include frex:shaders/api/fragment.glsl

/**********************************************
    lumi:shaders/material/enderman_eye.frag
***********************************************/

void frx_startFragment(inout frx_FragmentData fragData) {
    fragData.spriteColor.rgb *= 2.0;
    // Manual cutout sus
    if (fragData.spriteColor.a < 0.5) discard;
}
