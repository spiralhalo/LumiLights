#include frex:shaders/api/fragment.glsl

void frx_startFragment(inout frx_FragmentData data) {
#ifdef LUMI_PBR
    data.diffuse = false;
    pbr_disableShading = true;
#endif
}
