#version 430

#define WIDTH 1920
#define HEIGHT 1080
#define MAX_STEP 128
#define MIN_DIST 1.0
#define MAX_DIST 10.0

#define ADAPTIVE_SAMPLE 4

layout(local_size_x = 1, local_size_y = 1) in;
layout(location = 1) uniform float gtime;

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
  float t = MIN_DIST;
  for (int i=0; i<MAX_STEP; i++) {
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

#define SAMPLE_NUM 8

vec3 render(vec3 ro, vec3 rd) {
  vec3 lig = normalize(vec3(sin(gtime), 0.3, cos(gtime)));
  float t = castRay(ro, rd);
  vec3 col = color(ro, rd, t, lig);

  // // reflection
  // vec3 ro2 = ro+rd*t;
  // vec3 rd2 = getNormal(ro2);
  // float t2 = castRay(ro2, rd2);
  // vec3 col2 = color(ro2, rd2, t2, lig);
  // col += col2*0.1;

  return col;
}
