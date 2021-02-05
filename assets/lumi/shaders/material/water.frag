#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include lumi:shaders/lib/water.glsl

const float stretch = 1.2;

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
	ww_specular = 500.0;
#endif
	
	/* WATER RECOLOR */
	fragData.spriteColor.rgb *= fragData.spriteColor.rgb * (fragData.spriteColor.rgb + vec3(1.0)) * 0.8;
	fragData.spriteColor.a *= 0.5;
	
	/* WAVY NORMALS */
	// wave movement doesn't necessarily follow flow direction for the time being
	float waveSpeed = frx_var2.x;
	float scale = frx_var2.y;
	float amplitude = frx_var2.z;
	vec3 moveSpeed = frx_var1.xyz * waveSpeed;
	// const float texAmplitude = 0.005;
    vec3 up = fragData.vertexNormal.xyz;// * (1.0 + texAmplitude);
	vec3 samplePos = frx_var0.xyz;
	// samplePos = floor(samplePos) + floor(fract(samplePos) * 16) / 16;
	fragData.vertexNormal = ww_normals(up, l2_tangent, cross(up, l2_tangent), samplePos, waveSpeed, scale, amplitude, stretch, moveSpeed);
}
