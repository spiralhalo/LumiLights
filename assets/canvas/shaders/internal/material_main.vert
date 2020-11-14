/*
	Derived from Canvas source code (https://github.com/grondag/canvas/)

	Changes are made to add varyings that transfers the world position
	and camera position to the fragment shader.
*/

#include canvas:shaders/internal/header.glsl
#include frex:shaders/api/context.glsl
#include canvas:shaders/internal/varying.glsl
#include canvas:shaders/internal/vertex.glsl
#include canvas:shaders/internal/flags.glsl
#include frex:shaders/api/vertex.glsl
#include frex:shaders/api/sampler.glsl
#include frex:shaders/api/world.glsl
#include canvas:shaders/internal/diffuse.glsl
#include canvas:shaders/internal/program.glsl
#include frex:shaders/lib/noise/noise3d.glsl

#include canvas:apitarget

/******************************************************
  canvas:shaders/internal/material_main.vert
******************************************************/

void _cv_startVertex(inout frx_VertexData data, in int cv_programId) {
#include canvas:startvertex
}

void _cv_endVertex(inout frx_VertexData data, in int cv_programId) {
#include canvas:endvertex
}

attribute vec4 in_color;
attribute vec2 in_uv;
attribute vec2 in_material;
attribute vec4 in_lightmap;
attribute vec4 in_normal_flags;

varying vec3 wwv_aPos;
varying vec3 wwv_cameraPos;

mat4 ww_inv(mat4 m) {
  float
      a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
      a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
      a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
      a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

      b00 = a00 * a11 - a01 * a10,
      b01 = a00 * a12 - a02 * a10,
      b02 = a00 * a13 - a03 * a10,
      b03 = a01 * a12 - a02 * a11,
      b04 = a01 * a13 - a03 * a11,
      b05 = a02 * a13 - a03 * a12,
      b06 = a20 * a31 - a21 * a30,
      b07 = a20 * a32 - a22 * a30,
      b08 = a20 * a33 - a23 * a30,
      b09 = a21 * a32 - a22 * a31,
      b10 = a21 * a33 - a23 * a31,
      b11 = a22 * a33 - a23 * a32,

      det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

  return mat4(
      a11 * b11 - a12 * b10 + a13 * b09,
      a02 * b10 - a01 * b11 - a03 * b09,
      a31 * b05 - a32 * b04 + a33 * b03,
      a22 * b04 - a21 * b05 - a23 * b03,
      a12 * b08 - a10 * b11 - a13 * b07,
      a00 * b11 - a02 * b08 + a03 * b07,
      a32 * b02 - a30 * b05 - a33 * b01,
      a20 * b05 - a22 * b02 + a23 * b01,
      a10 * b10 - a11 * b08 + a13 * b06,
      a01 * b08 - a00 * b10 - a03 * b06,
      a30 * b04 - a31 * b02 + a33 * b00,
      a21 * b02 - a20 * b04 - a23 * b00,
      a11 * b07 - a10 * b09 - a12 * b06,
      a00 * b09 - a01 * b07 + a02 * b06,
      a31 * b01 - a30 * b03 - a32 * b00,
      a20 * b03 - a21 * b01 + a22 * b00) / det;
}

void main() {
	frx_VertexData data = frx_VertexData(
	gl_Vertex,
	in_uv,
	in_color,
	(in_normal_flags.xyz - 127.0) / 127.0,
	in_lightmap.rg * 0.00390625 + 0.03125
	);

	// Adding +0.5 prevents striping or other strangeness in flag-dependent rendering
	// due to FP error on some cards/drivers.  Also made varying attribute invariant (rolls eyes at OpenGL)
	_cvv_flags = in_normal_flags.w + 0.5;

	int cv_programId = _cv_vertexProgramId();
	_cv_startVertex(data, cv_programId);

	wwv_aPos = data.vertex.xyz;
    wwv_cameraPos = (ww_inv(mat4(gl_ModelViewMatrix)) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	if (_cvu_material[_CV_SPRITE_INFO_TEXTURE_SIZE] != 0.0) {
		float spriteIndex = in_material.x;
		// for sprite atlas textures, convert from normalized (0-1) to interpolated coordinates
		vec4 spriteBounds = texture2DLod(frxs_spriteInfo, vec2(0, spriteIndex / _cvu_material[_CV_SPRITE_INFO_TEXTURE_SIZE]), 0);

		float atlasHeight = _cvu_material[_CV_ATLAS_HEIGHT];
		float atlasWidth = _cvu_material[_CV_ATLAS_WIDTH];

		// snap sprite bounds to integer coordinates to correct for floating point error
		spriteBounds *= vec4(atlasWidth, atlasHeight, atlasWidth, atlasHeight);
		spriteBounds += vec4(0.5, 0.5, 0.5, 0.5);
		spriteBounds -= fract(spriteBounds);
		spriteBounds /= vec4(atlasWidth, atlasHeight, atlasWidth, atlasHeight);

		data.spriteUV = spriteBounds.xy + data.spriteUV * spriteBounds.zw;
	}

	data.spriteUV = _cv_textureCoord(data.spriteUV, 0);

	vec4 viewCoord = gl_ModelViewMatrix * data.vertex;
	gl_ClipVertex = viewCoord;
	gl_FogFragCoord = length(viewCoord.xyz);

#if DIFFUSE_SHADING_MODE != DIFFUSE_MODE_NONE
	_cvv_diffuse = _cv_diffuseBaked(data.normal);
#endif

	//data.oldNormal *= gl_NormalMatrix;
	data.vertex = gl_ModelViewProjectionMatrix * data.vertex;

	gl_Position = data.vertex;

	_cv_endVertex(data, cv_programId);

	_cvv_texcoord = data.spriteUV;
	_cvv_color = data.color;
	_cvv_normal = data.normal;

#if AO_SHADING_MODE != AO_MODE_NONE
	_cvv_ao = in_lightmap.b / 255.0;
#endif

	_cvv_lightcoord = data.light;
}
