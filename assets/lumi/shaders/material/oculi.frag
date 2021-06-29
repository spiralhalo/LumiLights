#include frex:shaders/api/fragment.glsl

/**********************************************
    lumi:shaders/material/oculi.frag
***********************************************/

void frx_startFragment(inout frx_FragmentData fragData) {
    fragData.spriteColor.rgb *= 2.0;

    // manual cutout; material cutout isn't in 1.16 and currently crashing in 1.17
    if (fragData.spriteColor.a == 0.0) {
        discard;
    }
}
