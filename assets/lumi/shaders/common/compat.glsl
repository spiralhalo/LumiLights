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

#if __VERSION__ <= 120
#define vert_in attribute
#define vert_out varying
#define frag_in varying
#define fragColor gl_FragData
#define sample_shadow(y,z) shadow2DArray(y,z).x
#define USING_OLD_OPENGL
#ifndef VERTEX_SHADER
    vec4 texture(sampler2D x, vec2 y)          { return texture2D(x, y); }
    vec4 texture(sampler2D x, vec2 y, float z) { return texture2D(x, y, z); }
    #define textureLod(y,z,w) texture2DLod(y,z,w)
#endif
#else
#define vert_in in
#define vert_out out
#define frag_in in
#define sample_shadow(y,z) shadow2DArray(y,z).x
#endif
