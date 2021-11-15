vec4 calcBlendedReflection(sampler2D ssource, vec2 sourceUv, float fallbackMix) {
	vec4 fallbackColor	 = fallback > 0.0 ? vec4(calcFallbackColor(unit_view, unit_march, light), fallback) : vec4(0.0);
	vec4 reflected_final = mix(reflected, fallbackColor, fallbackMix);
	vec3 unit_world		 = unit_view * frx_normalModelMatrix();
	vec3 unitMarch_world = unit_march * frx_normalModelMatrix();

	vec4 pbr_color = vec4(pbr_lightCalc(roughness, f0, reflected_final.rgb * base_color.a, unitMarch_world, unit_world), reflected_final.a);
}
