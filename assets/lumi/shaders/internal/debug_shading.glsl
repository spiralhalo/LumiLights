/*******************************************************
 *  lumi:shaders/internal/debug_shading.glsl           *
 *******************************************************
 *  Copyright (c) 2020 spiralhalo and Contributors.    *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

#define DEBUG_DISABLED 0
#define DEBUG_NORMAL 1
#define DEBUG_VIEWDIR 2

#if DEBUG_MODE != DEBUG_DISABLED
void debug_shading(in frx_FragmentData fragData, inout vec4 a) {
#if DEBUG_MODE == DEBUG_VIEWDIR
    vec3 viewDir = normalize(-l2_viewPos) * frx_normalModelMatrix() * gl_NormalMatrix;
    a.rgb = viewDir * 0.5 + 0.5;
#else
    vec3 normal = fragData.vertexNormal * frx_normalModelMatrix();
    a.rgb = normal * 0.5 + 0.5;
#endif
}
#endif
