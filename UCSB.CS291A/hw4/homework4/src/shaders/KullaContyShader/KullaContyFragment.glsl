#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform vec3 uLightDir;
uniform bool wft;

uniform sampler2D uAlbedoMap;
uniform vec3 uEdgetint;
uniform float uMetallic;
uniform float uRoughness;
uniform sampler2D uBRDFLut;
uniform sampler2D uEavgLut;
uniform samplerCube uCubeTexture;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

const float PI = 3.14159265359;
const float TWO_PI = PI * 2.0;
const float INV_PI = 1.0 / PI;
const float INV_TWO_PI = 0.5 / PI;

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


//https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
vec3 AverageFresnel(vec3 r, vec3 g)
{
    return vec3(0.087237) + 0.0230685*g - 0.0864902*g*g + 0.0774594*g*g*g
           + 0.782654*r - 0.136432*r*r + 0.278708*r*r*r
           + 0.19744*g*r + 0.0360605*g*g*r - 0.2586*g*r*r;
}

vec3 MultiScatterBRDF(float NdotL, float NdotV)
{
  vec3 albedo = texture2D(uAlbedoMap, vTextureCoord).rgb;

  vec3 E_o = vec3(texture2D(uBRDFLut, vec2(NdotL, uRoughness)).z);
  vec3 E_i = vec3(texture2D(uBRDFLut, vec2(NdotV, uRoughness)).z);

  vec3 E_avg = texture2D(uEavgLut, vec2(0.5, uRoughness)).xyz;
  vec3 F_avg = AverageFresnel(albedo, uEdgetint);

  vec3 fms = (vec3(1.0) - E_o) * (vec3(1.0) - E_i) / (PI * (vec3(1.0) - E_avg));

  // ERRATA: one more F_avg in the numerator, see page 15 in the 
  // https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
  vec3 fadd = F_avg * F_avg * E_avg / (1.0 - F_avg * (1.0 - E_avg));
  fms = fadd * fms;

  return fms;
  
}

vec3 ImportanceSampleGGX(vec2 Xi, vec3 N, float roughness) {
    float a = roughness * roughness;

    float cosTheta = sqrt((1.0 - Xi.x) / (1.0 + (a * a - 1.0) * Xi.x));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    float phi = 2.0 * PI * Xi.y;

    vec3 H = vec3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);

    vec3 up = abs(N.z) < 0.9 ? vec3(0, 0, 1) : vec3(1, 0, 0);
    vec3 X = cross(up, N);
    vec3 Y = cross(N, X);

    return X * H.x + Y * H.y + N * H.z;
}

vec3 SampleHemisphereCos(vec2 uv) {
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  return dir;
}

vec3 SampleHemisphereUniform(vec2 uv) {
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  return dir;
}

vec3 integrateFms(vec3 N, vec3 V, float roughness) {
  const int sample_count = 1024;

  float NoV = max(dot(N, V), 0.0);
  vec3 sum = vec3(0.0);

  const int sample_side = int(sqrt(float(sample_count)));
  for (int i = 0; i < sample_side; i++) {
    for (int j = 0; j < sample_side; j++) {
      float u = float(i) / float(sample_side);
      float v = float(j) / float(sample_side);

      vec3 L = SampleHemisphereUniform(vec2(u, v));
      float pdf = INV_TWO_PI;
      // vec3 L = SampleHemisphereCos(vec2(u, v));
      // float pdf = L.z / PI;

      float NoL = L.z;

      vec3 Fms = MultiScatterBRDF(NoL, NoV);

      sum += Fms * NoL / pdf;
    }
  }

  return sum / float(sample_count);
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
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0);
    vec3 Fmicro = numerator / max(denominator, 0.001); 
    
    vec3 Fms = MultiScatterBRDF(NdotL, NdotV);
    vec3 BRDF = Fmicro + Fms;
    
    color += BRDF * radiance * NdotL;
  }
  else {
    float A = texture2D(uBRDFLut, vec2(NdotV, uRoughness)).x;
    float B = texture2D(uBRDFLut, vec2(NdotV, uRoughness)).y;
    vec3 BRDF = F0 * A + B;
    color += BRDF;
    color += integrateFms(N, V, uRoughness);
  }
  
  color = color / (color + vec3(1.0));
  color = pow(color, vec3(1.0/2.2)); 
  gl_FragColor = vec4(color, 1.0);
}