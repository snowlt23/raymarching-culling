#version 430

#define WIDTH 512
#define HEIGHT 512
#define MIN_DIST 1.0
#define MAX_DIST 10.0

#define ADAPTIVE_SAMPLE 4
#define VOXEL_RESOLUTION 64
#define VOXEL_LIST_NUM 32
#define VOXEL_X_S 0.0
#define VOXEL_X_E 1.0
#define VOXEL_Y_S 0.0
#define VOXEL_Y_E 1.0
#define VOXEL_Z_S 0.0
#define VOXEL_Z_E 10.0

layout(local_size_x = 1, local_size_y = 1) in;
layout(location = 1) uniform float gtime;

struct Prim {
  float x;
  float y;
  float z;
  float radius;
};

layout(std430, binding = 0) readonly buffer _primvoxel {
  Prim data[];
} primvoxel;
layout(std430, binding = 1) readonly buffer _indexvoxel {
  int data[];
} indexvoxel;

float sdSphere(vec3 p, float r) {
  return length(p) - r;
}
float sdPlane(vec3 p) {
	return p.y;
}

float smin( float a, float b, float k )
{
    float h = max(k-abs(a-b), 0.0);
    return min(a, b) - h*h*0.25/k;
}

bool in_voxel_range(int x) {
  return 0 <= x && x < VOXEL_RESOLUTION;
}

float sdf(vec3 pos) {
  float step = (VOXEL_Z_E - VOXEL_Z_S) / VOXEL_RESOLUTION;
  int xp = int(-pos.x / ((VOXEL_X_E - VOXEL_X_S) / VOXEL_RESOLUTION));
  int yp = int(-pos.y / ((VOXEL_Y_E - VOXEL_Y_S) / VOXEL_RESOLUTION));
  int zp = int(pos.z / ((VOXEL_Z_E - VOXEL_Z_S) / VOXEL_RESOLUTION));
  float d = step;
  if (in_voxel_range(xp) && in_voxel_range(yp) && in_voxel_range(zp)) {
    int iindex = zp*VOXEL_RESOLUTION*VOXEL_RESOLUTION + yp*VOXEL_RESOLUTION + xp;
    int pindex = zp*VOXEL_RESOLUTION*VOXEL_RESOLUTION*VOXEL_LIST_NUM + yp*VOXEL_RESOLUTION*VOXEL_LIST_NUM + xp*VOXEL_LIST_NUM;
    int primlen = indexvoxel.data[iindex];
    for (int i=0; i<primlen; i++) {
      // return 0.0;
      Prim prim = primvoxel.data[pindex+i];
      d = smin(d, sdSphere(pos + vec3(prim.x, prim.y, -prim.z), prim.radius), 0.01);
    }
  }
  d = min(d, sdPlane(pos + vec3(0.0, 0.5, 0.0)));
  return d;
}

// float sdf(vec3 pos) {
//   // float d = 1000.0;
//   // for (int i=0; i<gPrimLen; i++) {
//   //   d = min(d, sdSphere(pos + vec3(gPrimVec.data[i].x, gPrimVec.data[i].y, gPrimVec.data[i].z), gPrimVec.data[i].radius));
//   // }
//   // d = min(d, sdPlane(pos + vec3(0.0, 0.5, 0.0)));
//   // return d;
//   return min(sdSphere(pos, 0.5), sdPlane(pos + vec3(0.0, 0.5, 0.0)));
// }

// vec3 getNormal(vec3 p) {
//   const float d = 0.0001;
//   return normalize(vec3(
//     sdf(p+vec3(d, 0.0, 0.0)) - sdf(p+vec3(-d, 0.0, 0.0)),
//     sdf(p+vec3(0.0, d, 0.0)) - sdf(p+vec3(0.0, -d, 0.0)),
//     sdf(p+vec3(0.0, 0.0, d)) - sdf(p+vec3(0.0, 0.0, -d))
//   ));
// }

vec3 getNormal(vec3 p)
{
    const float h = 0.0001;
    const vec2 k = vec2(1,-1);
    return normalize(k.xyy*sdf(p + k.xyy*h) +
                     k.yyx*sdf(p + k.yyx*h) +
                     k.yxy*sdf(p + k.yxy*h) +
                     k.xxx*sdf(p + k.xxx*h));
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

float castRay(vec3 ro, vec3 rd, int step) {
  float t = MIN_DIST;
  for (int i=0; i<step; i++) {
    float precis = 0.0005*t;
    float res = sdf(ro+rd*t);
    if (res<precis || t>MAX_DIST) break;
    t += res;
  }
  if (t>MAX_DIST) t = -MIN_DIST;
  return t;
}

vec3 color(vec3 ro, vec3 rd, float t, vec3 lig) {
  if (t < -0.5) {
    return vec3(0.5, 0.7, 1.0)*exp(0.0005*t*t);
  }

  vec3 pos = ro+rd*t;
  vec3 mate = vec3(0.3);
  vec3 nor = getNormal(pos);
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
  return mate;
}

vec3 reflectVector(vec3 d, vec3 n) {
  return normalize(d - dot(d, n) * n * 2.0);
}

vec3 render(vec3 ro, vec3 rd, int step, inout float t) {
  vec3 lig = normalize(vec3(sin(gtime*2), 0.3, cos(gtime*2)));
  t = castRay(ro, rd, step);
  vec3 col = color(ro, rd, t, lig);

  // reflection
  // if (!(t < -0.5)) {
  //   vec3 ro2 = ro+rd*t;
  //   vec3 rd2 = reflectVector(rd, getNormal(ro2));
  //   float t2 = castRay(ro2, rd2, 128);
  //   vec3 col2 = color(ro2, rd2, t2, lig);
  //   col += col2*0.5;
  //   col /= 1.5;
  // }

  return col;
}
