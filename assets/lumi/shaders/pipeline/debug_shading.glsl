/*******************************************************
 *  lumi:shaders/pipeline/debug_shading.glsl           *
 *******************************************************/

#if LUMI_DebugMode != LUMI_DebugMode_Disabled
void debug_shading(in frx_FragmentData fragData, inout vec4 a) {
#if LUMI_DebugMode == LUMI_DebugMode_ViewDir
    vec3 viewDir = normalize(-l2_viewPos) * frx_normalModelMatrix() * gl_NormalMatrix;
    a.rgb = viewDir * 0.5 + 0.5;
#else
    vec3 normal = fragData.vertexNormal * frx_normalModelMatrix();
    a.rgb = normal * 0.5 + 0.5;
#endif
}
#endif
