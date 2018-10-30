#include <stdio.h>
#include <stdbool.h>
// #define GL_GLEXT_PROTOTYPES
// #include <GL/gl.h>
#include <GL/glew.h>
// #include "glext.h"
#include <GLFW/glfw3.h>
#include <time.h>
#include "raycull.h"

#define WIDTH 512
#define HEIGHT 512
#define ADAPTIVE_SAMPLE 4

const char* vertex_shader =
"#version 430\n"
"layout(location = 0) in vec3 vp;"
"out vec2 uv;"
"void main() {"
"  gl_Position = vec4(vp, 1.0);"
"  uv = (vp.xy + 1.0) / 2.0;"
"}";
const char* fragment_shader =
"#version 430\n"
"layout(binding = 0, location = 1) uniform sampler2D texture;"
"in vec2 uv;"
"out vec4 frag_colour;"
"void main() {"
"  frag_colour = texture2D(texture, uv);"
"}";

char* adaptivesrc =
#include "adaptive.gen.glsl"
;
char* rendersrc =
#include "render.gen.glsl"
;

void print_shader_info_log(GLuint shader_index) {
  int max_length = 2048;
  int actual_length = 0;
  char shader_log[2048];
  glGetShaderInfoLog(shader_index, max_length, &actual_length, shader_log);
  printf("shader info log for GL index %u:\n%s\n", shader_index, shader_log);
}

bool debug_shader(GLuint shader_index) {
  int params = -1;
  glGetShaderiv(shader_index, GL_COMPILE_STATUS, &params);
  if (GL_TRUE != params) {
    fprintf(stderr, "ERROR: GL shader index %i did not compile\n", shader_index);
    print_shader_info_log(shader_index);
    return false; // or exit or something
  }
  return true;
}

GLuint create_quad_vao() {
  float points[] = {
    -1.0, 1.0, 0.0,
    1.0, 1.0, 0.0,
    -1.0, -1.0, 0.0,
    1.0, -1.0, 0.0,
  };
  GLuint vbo;
  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, 12*sizeof(float), points, GL_STATIC_DRAW);
  GLuint vao;
  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);
  glEnableVertexAttribArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);
  return vao;
}

GLuint create_quad_shader() {
  GLuint vs = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vs, 1, &vertex_shader, NULL);
  glCompileShader(vs);
  debug_shader(vs);
  GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fs, 1, &fragment_shader, NULL);
  glCompileShader(fs);
  debug_shader(fs);
  GLuint shader_programme = glCreateProgram();
  glAttachShader(shader_programme, fs);
  glAttachShader(shader_programme, vs);
  glLinkProgram(shader_programme);
  return shader_programme;
}

GLuint create_texture(int w, int h) {
  GLuint tex;
  glGenTextures(1, &tex);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, tex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, w, h, 0, GL_RGBA, GL_FLOAT,
   NULL);
  glBindImageTexture(0, tex, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
  return tex;
}
void bind_texture(GLuint unit, GLuint tex) {
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, tex);
  glBindImageTexture(unit, tex, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
}

GLuint compute_shader(char* src) {
  GLuint shader = glCreateShader(GL_COMPUTE_SHADER);
  const char* srctmp = src;
  glShaderSource(shader, 1, &srctmp, NULL);
  glCompileShader(shader);
  debug_shader(shader);
  GLuint program = glCreateProgram();
  glAttachShader(program, shader);
  glLinkProgram(program);
  return program;
}

GLuint gen_ssbo(size_t size, void* buffer) {
  GLuint ssbo;
  glGenBuffers(1, &ssbo);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
  glBufferData(GL_SHADER_STORAGE_BUFFER, size, buffer, GL_STATIC_DRAW);
  return ssbo;
}

void bind_ssbo(int index, GLuint ssbo) {
  glBindBufferBase(GL_SHADER_STORAGE_BUFFER, index, ssbo);
}

void del_ssbo(GLuint ssbo) {
  GLuint tmp = ssbo;
  glDeleteBuffers(1, &tmp);
}

Prim init_prim(float x, float y, float z, float radius) {
  Prim p;
  p.x = x;
  p.y = y;
  p.z = z;
  p.radius = radius;
  return p;
}

GLuint gen_prim_ssbo(PrimVec* pv) {
  return gen_ssbo(sizeof(Prim) * pv->len, pv->data);
}

int main() {
  if (!glfwInit()) {
    fprintf(stderr, "ERROR: could not start GLFW3\n");
    return 1;
  }

  // uncomment these lines if on Apple OS X
  /*glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);*/

  GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "Hello Triangle", NULL, NULL);
  if (!window) {
    fprintf(stderr, "ERROR: could not open window with GLFW3\n");
    glfwTerminate();
    return 1;
  }
  glfwMakeContextCurrent(window);
  glewInit();

  GLuint quad_vao = create_quad_vao();
  GLuint quad_shader= create_quad_shader();
  GLuint adapttex = create_texture(WIDTH/ADAPTIVE_SAMPLE, HEIGHT/ADAPTIVE_SAMPLE);
  GLuint postex = create_texture(WIDTH/ADAPTIVE_SAMPLE, HEIGHT/ADAPTIVE_SAMPLE);
  GLuint rendertex = create_texture(WIDTH, HEIGHT);
  GLuint adaptiveprog = compute_shader(adaptivesrc);
  GLuint renderprog = compute_shader(rendersrc);

  PrimVec* pv = new_primvec();

  float time = 0.0;
  GLuint primssbo = gen_prim_ssbo(pv);
  while(!glfwWindowShouldClose(window)) {
    glUseProgram(adaptiveprog);
    bind_ssbo(0, primssbo);
    bind_texture(1, adapttex);
    bind_texture(2, postex);
    glUniform1f(1, time);
    glUniform1i(2, pv->len);
    glDispatchCompute(WIDTH/ADAPTIVE_SAMPLE, HEIGHT/ADAPTIVE_SAMPLE, 1);
    glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

    glUseProgram(renderprog);
    bind_ssbo(0, primssbo);
    bind_texture(1, adapttex);
    bind_texture(2, postex);
    bind_texture(3, rendertex);
    glUniform1f(1, time);
    glUniform1i(2, pv->len);
    glDispatchCompute(WIDTH/ADAPTIVE_SAMPLE, HEIGHT/ADAPTIVE_SAMPLE, 1);
    glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(quad_shader);
    glBindVertexArray(quad_vao);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, rendertex);
    glUniform1i(1, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glfwPollEvents();
    if (GLFW_PRESS == glfwGetKey(window, GLFW_KEY_ESCAPE)) {
      glfwSetWindowShouldClose(window, 1);
    }
    if (GLFW_PRESS == glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT)) {
      double xpos, ypos;
      glfwGetCursorPos(window, &xpos, &ypos);
      primvec_push(pv, init_prim(1.0 - xpos / HEIGHT - 0.5, ypos / HEIGHT - 0.5, 0.0, 0.1));
      del_ssbo(primssbo);
      primssbo = gen_prim_ssbo(pv);
    }
    glfwSwapBuffers(window);
    time += clock() / CLOCKS_PER_SEC / 1000.0;
  }
}
