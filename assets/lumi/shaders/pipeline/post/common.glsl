#version 130
#extension GL_EXT_gpu_shader4 : enable

/*******************************************************
 *  lumi:shaders/pipeline/post/common.glsl             *
 *******************************************************/

uniform ivec2 _cvu_size;
uniform int _cvu_lod;
varying vec2 v_texcoord;
