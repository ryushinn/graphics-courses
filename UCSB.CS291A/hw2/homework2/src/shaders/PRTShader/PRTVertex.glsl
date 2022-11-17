attribute vec3 aVertexPosition;
attribute mat3 aPrecomputeLT;


uniform mat3 uPrecomputeRL;
uniform mat3 uPrecomputeGL;
uniform mat3 uPrecomputeBL;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

varying vec3 vColor;

void main(void) {

  vColor = vec3(0.0);
  for (int i = 0; i < 3; ++i) {
    vColor += vec3(
                    dot(uPrecomputeRL[i], aPrecomputeLT[i]),
                    dot(uPrecomputeGL[i], aPrecomputeLT[i]),
                    dot(uPrecomputeBL[i], aPrecomputeLT[i]));
  }
  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix *
                vec4(aVertexPosition, 1.0);
}