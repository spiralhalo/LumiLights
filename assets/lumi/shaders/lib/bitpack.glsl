/*******************************************************
 *  lumi:shaders/lib/bitpack.glsl
 *******************************************************/

float bit_pack(float a, float b, float c, float d, float e, float f, float g, float h) {
	float x = 0;
	x += a * 1.;
	x += b * 2.;
	x += c * 4.;
	x += d * 8.;
	x += e * 16.;
	x += f * 32.;
	x += g * 64.;
	x += h * 128.;
	return x / 255.;
}

float bit_unpack(float source, int index) {
	return float((uint(source * 255.) >> index) & 1u);
}
