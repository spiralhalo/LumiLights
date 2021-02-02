#include frex:shaders/api/fragment.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/lib/noise/noise3d.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/lib/math.glsl
#include lumi:shaders/context/forward/common.glsl
#include lumi:shaders/api/param_frag.glsl
#include lumi:shaders/lib/water.glsl

const float stretch = 2;

void frx_startFragment(inout frx_FragmentData fragData) {
    #ifdef LUMI_PBRX
        /* PBR PARAMS */
        pbr_f0 = 0.02;
        pbr_roughness = 0.05;
    #else
        /* HACK */
        fragData.light.y += 0.077 * smoothstep(1.0, 0.99, fragData.vertexNormal.y);
        fragData.light.y = min(0.96875, fragData.light.y);

        /* LUMI PARAMS */
        phong_specular = 500.0;
    #endif
    
    /* WATER RECOLOR */
    // vec3 desat = vec3(frx_luminance(fragData.vertexColor.rgb));
    #ifdef LUMI_NoWaterTexture
        // fragData.vertexColor.rgb = mix(fragData.vertexColor.rgb, desat, 0.3);
        fragData.spriteColor.rgb = vec3(0.4);
    #else
        // fragData.vertexColor.rgb = mix(fragData.vertexColor.rgb, desat, 0.6);
        fragData.spriteColor.rgb *= fragData.spriteColor.rgb;
    #endif
    
    /* WAVY NORMALS */
    // wave movement doesn't necessarily follow flow direction for the time being
    float waveSpeed = frx_var2.x;
    float scale = frx_var2.y;
    float amplitude = frx_var2.z;
    vec3 moveSpeed = frx_var1.xyz * waveSpeed;
    vec3 up = fragData.vertexNormal.xyz;
    vec3 samplePos = frx_var0.xyz;
    vec3 noisyNormal = ww_normals(up, l2_tangent, cross(up, l2_tangent), samplePos, waveSpeed, scale, amplitude, stretch, moveSpeed);
    fragData.vertexNormal = mix(noisyNormal, fragData.vertexNormal, pow(gl_FragCoord.z, 500.0));
}
