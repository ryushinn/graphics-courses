#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;
uniform int uWidth;
uniform int uHeight;

const int maxLevel = 8;
uniform sampler2D uGDepthMipmap[maxLevel];

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 albedo = GetGBufferDiffuse(uv);
  vec3 n = normalize(GetGBufferNormalWorld(uv));
  vec3 brdf = albedo / M_PI * max(0.0, dot(n, wi));
  return brdf;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  return uLightRadiance * GetGBufferuShadow(uv);
}

#define MAX_STEPS 100
#define SS_STEP 0.01
#define BIAS 1e-3
#define THR 0.5
#define FINE_STEPS 5

float GBufferDepthFetch(vec2 uv, int lod) {
  float depth;
  if (lod == 0) {
    depth = texture2D(uGDepth, uv).x;
  }
  if (lod == 1) {
    depth = texture2D(uGDepthMipmap[0], uv).x;
  }
  if (lod == 2) {
    depth = texture2D(uGDepthMipmap[1], uv).x;
  }
  if (lod == 3) {
    depth = texture2D(uGDepthMipmap[2], uv).x;
  }
  if (lod == 4) {
    depth = texture2D(uGDepthMipmap[3], uv).x;
  }
  if (lod == 5) {
    depth = texture2D(uGDepthMipmap[4], uv).x;
  }
  if (lod == 6) {
    depth = texture2D(uGDepthMipmap[5], uv).x;
  }
  if (lod == 7) {
    depth = texture2D(uGDepthMipmap[6], uv).x;
  }
  if (lod == 8) {
    depth = texture2D(uGDepthMipmap[7], uv).x;
  }
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}
bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {

  // set marchStep to one pixel
  float marchStep = 1.0;
  float ss_step = length(GetScreenCoordinate(ori) - 
                                GetScreenCoordinate(ori + marchStep * dir));
  if (ss_step <= 1e-9)
    return false;
  marchStep *= SS_STEP / ss_step;

  // initialize
  int level = 0;
  vec3 cur = ori;

  // ray marching
  for (int i = 0; i < MAX_STEPS; i++) {
    cur = cur + float(level + 1) * marchStep * dir;
    vec2 uv = GetScreenCoordinate(cur);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
      break;

    if (GetDepth(cur) >= GBufferDepthFetch(uv, level) + BIAS) {
      if (level == 0) {
        // get rid of false intersections caused by the "depth shell"
        if (abs(GetDepth(cur) - GBufferDepthFetch(uv, level)) > THR)
          return false;
        hitPos = cur;
        return true;
      }
      cur = cur - float(level + 1) * marchStep * dir;
      level--;
    }
    else {
      if (level < maxLevel) level++;
    }
  }
  return false;
}

#define SAMPLE_NUM 8

void main() {
  float s = InitRand(gl_FragCoord.xy);
  vec4 white= vec4(1.0, 1.0, 1.0, 1.0);
  // original
  /*
  vec3 L = vec3(0.0);
  L = GetGBufferDiffuse(GetScreenCoordinate(vPosWorld.xyz));
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
  */

  // direct lighting
  vec2 uv = GetScreenCoordinate(vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - vPosWorld.xyz);
  vec3 directLighting = EvalDiffuse(wi, wo, uv) * EvalDirectionalLight(uv);

  // indirect lighting
  vec3 indirectLighting = vec3(0.0, 0.0, 0.0);

  vec3 n = normalize(GetGBufferNormalWorld(uv));
  vec3 b1, b2;
  LocalBasis(n, b1, b2);
  b1 = normalize(b1);
  b2 = normalize(b2);
  for (int i = 0; i < SAMPLE_NUM; i++) {
    float pdf;
    vec3 dir = SampleHemisphereCos(s, pdf);
    vec3 dir_WS = n * dir.z + b1 * dir.x + b2 * dir.y;
    vec3 hitPos;
    if (RayMarch(vPosWorld.xyz, dir_WS, hitPos)) {
      vec2 hit_uv = GetScreenCoordinate(hitPos);
      vec3 hit_wi = normalize(hitPos - vPosWorld.xyz);
      vec3 Li = EvalDiffuse(wi, -hit_wi, hit_uv) * EvalDirectionalLight(hit_uv);
      indirectLighting += EvalDiffuse(hit_wi, wo, uv) * Li / pdf;
    }
  }
  indirectLighting /= float(SAMPLE_NUM);

  vec3 color = pow(directLighting, vec3(1.0/2.2));

  // // test ray march
  // vec3 color = vec3(0.0, 0.0, 0.0);
  // vec2 uv = GetScreenCoordinate(vPosWorld.xyz);
  // vec3 V = normalize(uCameraPos - vPosWorld.xyz);
  // vec3 N = GetGBufferNormalWorld(uv);
  // vec3 R = reflect(-V, N);
  // vec3 hitPos;
  // if (RayMarch(vPosWorld.xyz, R, hitPos)) {
  //   color += GetGBufferDiffuse(GetScreenCoordinate(hitPos));
  // }
  // color = pow(color, vec3(1.0/2.2));
  gl_FragColor = vec4(color, 1.0);
  // gl_FragColor = vec4(vec3(GBufferDepthFetch(uv, 8)), 1.0);
}
