/***********************************************************
 *  lumi:shaders/forward/vanilla.glsl                     *
 ***********************************************************/

#ifdef VANILLA_LIGHTING
float l2_ao(frx_FragmentData fragData) {
    #if AO_SHADING_MODE != AO_MODE_NONE
    #if LIGHTING_PROFILE == LIGHTING_PROFILE_SystemUnused
        float aoInv = 1.0 - (fragData.ao ? fragData.aoShade : 1.0);
        return 1.0 - 0.8 * smoothstep(0.0, 0.3, aoInv * (0.5 + 0.5 * abs((fragData.vertexNormal * frx_normalModelMatrix()).y)));
    #else
        float ao = fragData.ao ? fragData.aoShade : 1.0;
        return hdr_gammaAdjustf(min(1.0, ao + fragData.emissivity));
    #endif
    #else
        return 1.0;
    #endif
}
#endif
