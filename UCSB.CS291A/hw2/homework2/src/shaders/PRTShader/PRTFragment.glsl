#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 albedo;

varying vec3 vColor;

void main(void) {
    
    float gamma = 1.0 / 2.2;
    vec3 color_gamma = vec3(pow(vColor.x, gamma), pow(vColor.y, gamma), pow(vColor.z, gamma));
    
    gl_FragColor = vec4(color_gamma, 1.0);
}