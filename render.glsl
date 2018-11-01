layout(rgba32f, binding = 2) uniform image2D adapttex;
layout(rgba32f, binding = 3) uniform image2D pos_buffer;
layout(rgba32f, binding = 4) uniform image2D img_output;

// #define DEBUG_ADAPTIVE

bool is_nearly(vec4 a, vec4 b) {
  float ax = (a.x + a.y + a.z) / 3.0;
  float bx = (b.x + b.y + b.z) / 3.0;
  if (abs(bx - ax) < 0.01) {
    return true;
  } else {
    return false;
  }
}

bool is_nearly_rect(vec4 a) {
  ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
  for (int i=0; i<ADAPTIVE_SAMPLE; i++) {
    for (int j=0; j<ADAPTIVE_SAMPLE; j++) {
      if (!is_nearly(a, imageLoad(adapttex, pixel_coords+ivec2(i, j)))) {
        return false;
      }
    }
  }
  return true;
}

bool is_nearly_dist(float a) {
  ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
  for (int i=0; i<ADAPTIVE_SAMPLE; i++) {
    for (int j=0; j<ADAPTIVE_SAMPLE; j++) {
      if (!(abs(imageLoad(pos_buffer, pixel_coords+ivec2(i, j)).x - a) < 0.1)) {
        return false;
      }
    }
  }
  return true;
}

void main() {
  ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy)*ADAPTIVE_SAMPLE;
  vec2 pixel = vec2(float(pixel_coords.x) / HEIGHT, float(pixel_coords.y) / HEIGHT);

  vec4 a = imageLoad(adapttex, pixel_coords / ADAPTIVE_SAMPLE);
  if (is_nearly_rect(a)) {
    for (int i=0; i<ADAPTIVE_SAMPLE; i++) {
      for (int j=0; j<ADAPTIVE_SAMPLE; j++) {
        imageStore(img_output, pixel_coords+ivec2(i, j), a);
        #ifdef DEBUG_ADAPTIVE
          imageStore(img_output, pixel_coords+ivec2(i, j), vec4(0.5, 0.0, 0.0, 1.0));
        #endif
      }
    }
    return;
  }


  float startt = imageLoad(pos_buffer, pixel_coords/ADAPTIVE_SAMPLE).x;
  if (is_nearly_dist(startt)) {
    for (int i=0; i<ADAPTIVE_SAMPLE; i++) {
      for (int j=0; j<ADAPTIVE_SAMPLE; j++) {
        vec2 pos = pixel + vec2((float(i)/HEIGHT), float(j)/HEIGHT) - vec2(float(WIDTH)/float(HEIGHT)/2, 0.5);
        vec3 camPos = vec3(0.0, 0.0, 0.0);
        vec3 camDir = vec3(0.0, 0.0, 1.0);
        vec3 camUp = vec3(0.0, 1.0, 0.0);
        vec3 camSide = cross(camDir, camUp);
        float focus = 1.8;
        vec3 rayDir = normalize(camSide*pos.x + camUp*pos.y + camDir*focus);
        camPos = camPos + rayDir*(startt * ((i+j)/(ADAPTIVE_SAMPLE*2)));

        float t;
        vec3 col = render(camPos, rayDir, 16, t);
        // col = pow(col, vec3(0.4545));
        imageStore(img_output, pixel_coords+ivec2(i, j), vec4(col, 1.0));

        #ifdef DEBUG_ADAPTIVE
          imageStore(img_output, pixel_coords+ivec2(i, j), vec4(0.0, 0.5, 0.0, 1.0));
        #endif
      }
    }
    return;
  }

  for (int i=0; i<ADAPTIVE_SAMPLE; i++) {
    for (int j=0; j<ADAPTIVE_SAMPLE; j++) {
      vec2 pos = pixel + vec2((float(i)/HEIGHT), float(j)/HEIGHT) - vec2(float(WIDTH)/float(HEIGHT)/2, 0.5);
      vec3 camPos = vec3(0.0, 0.0, 0.0);
      vec3 camDir = vec3(0.0, 0.0, 1.0);
      vec3 camUp = vec3(0.0, 1.0, 0.0);
      vec3 camSide = cross(camDir, camUp);
      float focus = 1.8;
      vec3 rayDir = normalize(camSide*pos.x + camUp*pos.y + camDir*focus);

      float t;
      vec3 col = render(camPos, rayDir, 64, t);
      // col = pow(col, vec3(0.4545));
      imageStore(img_output, pixel_coords+ivec2(i, j), vec4(col, 1.0));

      #ifdef DEBUG_ADAPTIVE
        imageStore(img_output, pixel_coords+ivec2(i, j), vec4(0.0, 0.0, 0.5, 1.0));
      #endif
    }
  }
}
