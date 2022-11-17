uniform sampler2D uDepthBuffer;
uniform int preWidth;
uniform int preHeight;
vec2 coord2uv(ivec2 coord) {
  return vec2(coord) / vec2(preWidth, preHeight);
}
void main(){
  ivec2 coord = ivec2(gl_FragCoord);
  ivec2 preCoord = coord * 2;

  float a = texture2D(uDepthBuffer, coord2uv(preCoord)).x;
  float b = texture2D(uDepthBuffer, coord2uv(preCoord + ivec2(1, 0))).x;
  float c = texture2D(uDepthBuffer, coord2uv(preCoord + ivec2(0, 1))).x;
  float d = texture2D(uDepthBuffer, coord2uv(preCoord + ivec2(1, 1))).x;
  
  float minDepth = min(min(a, b), min(c, d));

  gl_FragData[0] = vec4(vec3(minDepth), 1.0);
}