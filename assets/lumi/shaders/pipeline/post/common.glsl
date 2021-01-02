#version 130
#extension GL_EXT_gpu_shader4 : enable

/*******************************************************
 *  lumi:shaders/pipeline/post/common.glsl             *
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;
varying vec2 v_texcoord;
