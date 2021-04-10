/*******************************************************
 *  lumi:shaders/common/compat.glsl                    *
 *******************************************************/

// Compatibility with 1.16 / GLSL 1.3
// NOT compatibility with GLSL 1.2

#if __VERSION__ == 130
#define frx_guiViewProjectionMatrix() gl_ProjectionMatrix * gl_ModelViewMatrix
#define frxu_frameProjectionMatrix gl_ProjectionMatrix
#define in_vertex gl_Vertex
#endif
