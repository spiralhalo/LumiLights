/*****************************************************
 *  lumi:shaders/lib/coords.glsl                     *
 *****************************************************/

vec2 coords_uv(vec3 view, mat4 projection)
{
	vec4 clip = projection * vec4(view, 1.0);
	clip.xyz /= clip.w;
	return clip.xy * 0.5 + 0.5;
}

vec3 coords_view(vec2 uv, mat4 inv_projection, sampler2D depth_map)
{
    float depth = texture2DLod(depth_map, uv, 0).r;
	vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
	vec4 view = inv_projection * vec4(clip, 1.0);
	return view.xyz / view.w;
}

vec3 coords_normal(vec2 uv, sampler2D normal_map)
{
	return 2.0 * texture2DLod(normal_map, uv, 0).xyz - 1.0;
}
