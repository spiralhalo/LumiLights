/*******************************************************
 *  lumi:shaders/common/compat.glsl                    *
 *******************************************************
 *  This file isn't supposed to exist.                 *
 *******************************************************/

// Compatibility with 1.16 / GLSL 1.3
// NOT compatibility with GLSL 1.2
// but including it just in case because OpenGL is weird.

#if __VERSION__ <= 130
#define frx_guiViewProjectionMatrix() gl_ProjectionMatrix * gl_ModelViewMatrix
#define frxu_frameProjectionMatrix gl_ProjectionMatrix
#define frx_heldLightInnerRadius() 3.14159265359
#define frx_heldLightOuterRadius() 3.14159265359
#define in_vertex gl_Vertex
#define USE_LEGACY_FREX_COMPAT
#endif

// LIST OF INCOMPATIBLE CHANGES
// (in case I want to expand compatibility in the future)

// [see defines above]
// varying -> in/out
// texture2D -> texture
// texture2DLod -> textureLod
// shadow2DArray(...).x -> texture(...)
// gl_FragData[] -> out vec4 fragColor, out vec4[] fragColor
