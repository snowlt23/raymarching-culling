#version 430

layout(local_size_x = 1, local_size_y = 1) in;
layout(rgba32f, binding = 0) uniform image2D img_output;
layout(location = 1) uniform float gtime;

uint rand(in vec2 co) {
  return uint(fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453) * 4294967294.0) + 1u;
}

float xorshift(inout uint y) {
  y = y ^ (y << 13);
  y = y ^ (y << 17);
  y = y ^ (y << 5);
  return float(y) * 2.3283064e-10;
}

float sdSphere(vec3 p, float r) {
  return length(p) - r;
}
float sdPlane( vec3 p ) {
	return p.y;
}

float sdf(vec3 pos) {
  return min(sdSphere(pos, 0.5), sdPlane(pos + vec3(0.0, 0.5, 0.0)));
}

vec3 getNormal(vec3 p) {
  const float d = 0.0001;
  return normalize(vec3(
    sdf(p+vec3(d, 0.0, 0.0)) - sdf(p+vec3(-d, 0.0, 0.0)),
    sdf(p+vec3(0.0, d, 0.0)) - sdf(p+vec3(0.0, -d, 0.0)),
    sdf(p+vec3(0.0, 0.0, d)) - sdf(p+vec3(0.0, 0.0, -d))
  ));
}

float squareLength(vec3 p) {
  return abs(p.x*p.x + p.y*p.y + p.z*p.z);
}

vec3 randomInSphere(inout uint y, vec3 nor) {
  vec3 d = 2.0 * vec3(xorshift(y), xorshift(y), xorshift(y)) - vec3(1, 1, 1);
  if (dot(nor, d) < 0.5) {
    return -d;
  } else {
    return d;
  }
}

float softshadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  for (float t=mint; t<maxt; ) {
    float h = sdf(ro+rd*t);
    if (h<0.001) return 0.05;
    res = min(res, k*h/t);
    t += h;
  }
  return clamp(res, 0.05, 1.0);
}

float calcAO(vec3 p, vec3 n) {
  float occ = 0.0;
  float sca = 1.0;
  for (int i=0; i<5; i++) {
    float h = 0.001 + 0.15*float(i)/4.0;
    float d = sdf(p + h*n);
    occ += (h-d)*sca;
    sca *= 0.95;
  }
  return clamp(1.0 - 1.5*occ, 0.0, 1.0);
}

float castRay(vec3 ro, vec3 rd) {
  float tmin = 1.0;
  float tmax = 20.0;
  float t = tmin;
  for (int i=0; i<64; i++) {
    float precis = 0.0005*t;
    float res = sdf(ro+rd*t);
    if (res<precis || t>tmax) break;
    t += res;
  }
  if (t>tmax) t = -1.0;
  return t;
}

#define MAX_STEP 256
#define MAX_DIST 40

vec3 render(vec3 ro, vec3 rd) {
  vec3 light = normalize(vec3(1.0, 1.0, 1.0));
  float t = 0.0;
  for (int i=0; i<MAX_STEP; i++) {
    float precis = 0.0005*t;
    float res = sdf(ro+rd*t);
    if (t>MAX_DIST) break;
    if (res<precis) {
      vec3 pos = ro+rd*t;
      vec3 mate = vec3(0.3);
      vec3 nor = getNormal(pos);
      float lx = sin(gtime);
      float lz = cos(gtime);
      vec3 lig = normalize(vec3(lx, 0.3, lz));
      vec3 hal = normalize(lig-rd);
      float dif = clamp(dot(nor, lig), 0.0, 1.0) * softshadow(pos, lig, 1.0, 5.0, 2);
      float spe = pow(clamp(dot(nor, hal), 0.0, 1.0), 16.0) * dif * (0.04 + 0.96*pow(clamp(1.0+dot(hal,rd), 0.0, 1.0), 5.0));
      vec3 col = mate * 4.0*dif*vec3(1.0, 0.7, 0.5);
      col += 12.0*spe*vec3(1.0, 0.7, 0.5);
      float occ = calcAO(pos, nor);
      float amb = clamp(0.5+0.5*nor.y, 0.0, 1.0);
      col += mate+amb*occ*vec3(0.0, 0.08, 0.1);
      col *= vec3(0.5, 0.7, 1.0)*exp(0.0005*t*t);
      return col;
    }
    t += res;
  }
  return vec3(0.5, 0.7, 1.0)*exp(0.0005*t*t);
}

// vec3 render(vec3 ro, vec3 rd, int seed) {
//   uint y = rand(vec2(gl_GlobalInvocationID.xy) / 512.0 * seed);

//   float t = castRay(ro, rd);
//   vec3 col = color(t);;
//   ro = ro+rd*t;
//   rd = getNormal(ro) + randomInSphere(y, getNormal(ro));

//   for (int i=0; i<MAX_STEP; i++) {
//     t = castRay(ro, rd);
//     ro = ro+rd*t;
//     rd = getNormal(ro) + randomInSphere(y, getNormal(ro));
//     col *= 0.5*color(t);
//     if (t < 0.0 || t > MAX_DIST) {
//       break;
//     }
//   }
//   return col;
// }

void main() {
  ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
  vec4 pixel = vec4(float(pixel_coords.x) / 512.0, float(pixel_coords.y) / 512.0, 0.0, 1.0);

  vec2 pos = (pixel_coords*2.0 - 512.0) / 512.0;
  vec3 camPos = vec3(0.0, 0.0, 3.0);
  vec3 camDir = vec3(0.0, 0.0, -1.0);
  vec3 camUp = vec3(0.0, 1.0, 0.0);
  vec3 camSide = cross(camDir, camUp);
  float focus = 1.8;

  vec3 rayDir = normalize(camSide*pos.x + camUp*pos.y + camDir*focus);

  // vec3 col = render(camPos, rayDir, 1);
  // int samplenum = 4;
  // for (int i=2; i<=samplenum; i++) {
  //   col += render(camPos, rayDir, i);
  // }
  // col /= samplenum;
  vec3 col = render(camPos, rayDir);
  // col = pow(col, vec3(0.4545));
  imageStore(img_output, pixel_coords, vec4(col, 1.0));
}
