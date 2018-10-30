layout(rgba32f, binding = 1) uniform image2D img_output;
layout(rgba32f, binding = 2) uniform image2D pos_buffer;

void main() {
  ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
  vec2 pixel = vec2(float(pixel_coords.x) / HEIGHT, float(pixel_coords.y) / HEIGHT) * ADAPTIVE_SAMPLE;

  vec2 pos = pixel - vec2(float(WIDTH)/float(HEIGHT)/2, 0.5);
  vec3 camPos = vec3(0.0, 0.0, 3.0);
  vec3 camDir = vec3(0.0, 0.0, -1.0);
  vec3 camUp = vec3(0.0, 1.0, 0.0);
  vec3 camSide = cross(camDir, camUp);
  float focus = 1.8;
  vec3 rayDir = normalize(camSide*pos.x + camUp*pos.y + camDir*focus);

  float t;
  vec3 col = render(camPos, rayDir, 128, t);
  // col = pow(col, vec3(0.4545));
  imageStore(img_output, pixel_coords, vec4(col, 1.0));
  imageStore(pos_buffer, pixel_coords, vec4(t, 0.0, 0.0, 0.0));
}
