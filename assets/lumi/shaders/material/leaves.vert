#include frex:shaders/api/vertex.glsl
#include frex:shaders/lib/noise/noise4d.glsl

void frx_materialVertex() {
	vec4 world = frx_vertex + vec4(frx_modelToWorld.xyz, frx_renderSeconds);
	frx_vertex.xyz += snoise(world) * (0.02 + 0.03 * frx_smoothedRainGradient + 0.04 * frx_smoothedThunderGradient) * vec3(1.0, 0.5, 1.0);
}
