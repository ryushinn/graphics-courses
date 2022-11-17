#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 50
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10
#define W_LIGHT 5.0

#define BIAS 2e-3

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

varying vec4 vPos;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    // 0.75 -> 0.5 for uniform distribution
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

// Another sample generation for test
void uniformDiskSamples2(const in vec2 randomSeed) {
  const float sampleSize = 10.0;
  const int sampleSizeInt = 10;
  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sampleY;

  float angleStep = PI2 / sampleSize;
  float radiusStep = 1.0 / sampleSize;

  for (int i = 0; i < sampleSizeInt * sampleSizeInt; i++) {
    angle += float(i / sampleSizeInt) * angleStep;
    radius += float(i - (i / sampleSizeInt) * sampleSizeInt) * radiusStep;
    if (radius > 1.0)
      radius -= 1.0;

    poissonDisk[i] = vec2(cos(angle), sin(angle)) * pow(radius, 0.5);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
  float filterSize = 0.05;

  // if no blocker, return zReceiver
  float zBlocker = zReceiver;
  float num_blockers = 1.0;

	for (int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i++) {
    float z = unpack(texture2D(shadowMap, uv + filterSize * poissonDisk[i]));
    if(zReceiver > z + BIAS){
      zBlocker += z;
      num_blockers += 1.0;
    }
  }

  return zBlocker / num_blockers;
}

float PCF(sampler2D shadowMap, vec4 coords) {
  poissonDiskSamples(coords.xy);
  float filterSize = 0.005;
  float occluded = 0.0;
  for (int i = 0; i < PCF_NUM_SAMPLES; i++) {
    // divide px!
    // float r = sqrt(pow(poissonDisk[i].x , 2.0) + pow(poissonDisk[i].y , 2.0));
    // float px = 2.0 / (3.0 * PI * pow(r, 2.0 / 3.0));

    if(coords.z > BIAS + unpack(texture2D(shadowMap, coords.xy + filterSize * poissonDisk[i])))
      // occluded += 1.0 / (PI * px * float(PCF_NUM_SAMPLES)) ;
      occluded += 1.0 / (float(PCF_NUM_SAMPLES)) ;
  }
  return 1.0 - occluded;
}

float PCSS(sampler2D shadowMap, vec4 coords){
  poissonDiskSamples(coords.xy);

  // STEP 1: avgblocker depth
  float zBlocker = findBlocker(shadowMap, coords.xy, coords.z);
  
  // STEP 2: penumbra size
  float wPenumbra = (coords.z - zBlocker) / zBlocker * W_LIGHT;
  float filterSize = wPenumbra * 0.01;

  // STEP 3: filtering
  float occluded = 0.0;
  for (int i = 0; i < PCF_NUM_SAMPLES; i++) {
    if(coords.z > BIAS + unpack(texture2D(shadowMap, coords.xy + filterSize * poissonDisk[i])))
      occluded += 1.0 / float(PCF_NUM_SAMPLES);
  }
  
  return 1.0 - occluded;
}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  float d = unpack(texture2D(shadowMap, shadowCoord.xy));
  if (shadowCoord.z > d + BIAS) return 0.0;
  return 1.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {
  vec3 shadowCoord = ((vPositionFromLight.xyz + 1.0) / 2.0);
  float visibility = 1.0;
  // visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
  // visibility = PCF(uShadowMap, vec4(shadowCoord, 1.0));
  visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
  // gl_FragColor = vec4(phongColor, 1.0);

  // DEBUG:
  // gl_FragColor = vec4(vec3(visibility), 1.0);
  // gl_FragColor = vec4(unpack(texture2D(uShadowMap, ((vPos.xy/vPos.w + 1.0) / 2.0))));
}