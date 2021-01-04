#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/internal/material_varying.glsl
#include lumi:shaders/internal/context.glsl
#include lumi:shaders/api/param_frag.glsl
#include lumi:shaders/lib/water.glsl

void frx_startFragment(inout frx_FragmentData fragData) {
	#ifdef LUMI_PBRX
		/* PBR PARAMS */
		pbr_f0 = vec3(0.02);
		pbr_roughness = 0.05;
	#else
		/* HACK */
		fragData.light.y += 0.077 * smoothstep(1.0, 0.99, fragData.vertexNormal.y);
		fragData.light.y = min(0.96875, fragData.light.y);

		/* LUMI PARAMS */
		phong_specular = 500.0;
	#endif
	
	/* WATER RECOLOR */
	vec3 desat = vec3(frx_luminance(fragData.vertexColor.rgb));
	fragData.vertexColor.rgb = mix(fragData.vertexColor.rgb, desat, 0.7);

	float maxc = max(fragData.spriteColor.r, max(fragData.spriteColor.g, fragData.spriteColor.b)); 
	fragData.spriteColor.rgb *= fragData.spriteColor.rgb * fragData.spriteColor.rgb * 2.0;

	float l = frx_luminance(fragData.spriteColor.rgb);
	#ifdef LUMI_PBRX
		pbr_f0 = mix(pbr_f0, vec3(0.2), l * l);
	#endif
	
	/* WAVY NORMALS */
	float waveSpeed = 1;
	float scale = 1.5;
	float amplitude = 0.01;
	float stretch = 2;
	// wave movement doesn't necessarily follow flow direction for the time being
	vec3 moveSpeed = vec3(0.5, 1.5, -0.5);
	// const float texAmplitude = 0.005;
	vec3 up = fragData.vertexNormal.xyz;// * (1.0 + texAmplitude);
	vec3 samplePos = frx_var0.xyz;
	// samplePos = floor(samplePos) + floor(fract(samplePos) * 16) / 16;
	fragData.vertexNormal = ww_normals(up, l2_tangent, cross(up, l2_tangent), samplePos, waveSpeed, scale, amplitude, stretch, moveSpeed);
}
