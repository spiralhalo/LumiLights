#version 130
#extension GL_EXT_gpu_shader4 : enable

/*******************************************************
 *  lumi:shaders/pipeline/post/common.glsl             *
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;
varying vec2 v_texcoord;
varying vec3 v_skycolor;
varying vec3 v_up;
// varying mat4 v_inv_projection;
