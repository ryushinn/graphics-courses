#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform vec3 uLightDir;

uniform sampler2D uAlbedoMap;
uniform float uMetallic;
uniform float uRoughness;
uniform sampler2D uBRDFLut;
uniform sampler2D uEavgLut;
uniform samplerCube uCubeTexture;

uniform bool wft;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a2 = pow(roughness, 4.0);
    float NoH = max(dot(N, H), 0.0);

    float numerator = a2;
    float denominator = NoH * NoH * (a2 - 1.0) + 1.0;
    denominator = PI * denominator * denominator;

    return numerator / denominator;
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float a = roughness;
    float k = (a * a) / 2.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NoV = max(dot(N, V), 0.0);
    float NoL = max(dot(N, L), 0.0);

    float ggx1 = GeometrySchlickGGX(NoV, roughness);
    float ggx2 = GeometrySchlickGGX(NoL, roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(vec3 F0, vec3 V, vec3 H)
{
    float VoH = max(dot(V, H), 0.0);
    float a = pow(1.0 - VoH, 5.0);
    return mix(F0, vec3(1.0), a);
}

void main(void) {
  vec3 albedo = texture2D(uAlbedoMap, vTextureCoord).rgb;

  vec3 N = normalize(vNormal);
  vec3 V = normalize(uCameraPos - vFragPos);
  float NdotV = max(dot(N, V), 0.0);
  vec3 L = normalize(uLightDir);
  vec3 H = normalize(V + L);
  float NdotL = max(dot(N, L), 0.0); 

  vec3 color = vec3(0.0);

  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo, uMetallic);
  if (!wft) {
    vec3 radiance = uLightRadiance;

    float NDF = DistributionGGX(N, H, uRoughness);   
    float G   = GeometrySmith(N, V, L, uRoughness); 
    vec3 F = fresnelSchlick(F0, V, H); 
        
    vec3 numerator    = NDF * G * F; 
    float denominator = max((4.0 * NdotL * NdotV), 0.001);
    vec3 BRDF = numerator / denominator;

    color += BRDF * radiance * NdotL;
  }
  else {
    float A = texture2D(uBRDFLut, vec2(NdotV, uRoughness)).x;
    float B = texture2D(uBRDFLut, vec2(NdotV, uRoughness)).y;
    vec3 BRDF = F0 * A + B;
    color += BRDF;
  }


  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0/2.2)); 
  gl_FragColor = vec4(color, 1.0);
}