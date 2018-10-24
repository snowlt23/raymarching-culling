#include <stdio.h>
#include <stdbool.h>
// #define GL_GLEXT_PROTOTYPES
// #include <GL/gl.h>
#include <GL/glew.h>
// #include "glext.h"
#include <GLFW/glfw3.h>

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

char* raysrc =
#include "compute.gen.glsl"
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
void bind_texture(GLuint tex) {
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, tex);
  glBindImageTexture(0, tex, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
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

  GLFWwindow* window = glfwCreateWindow(512, 512, "Hello Triangle", NULL, NULL);
  if (!window) {
    fprintf(stderr, "ERROR: could not open window with GLFW3\n");
    glfwTerminate();
    return 1;
  }
  glfwMakeContextCurrent(window);
  glewInit();

  GLuint quad_vao = create_quad_vao();
  GLuint quad_shader= create_quad_shader();
  GLuint tex = create_texture(512, 512);
  GLuint rayprog = compute_shader(raysrc);

  float time = 0.0;
  while(!glfwWindowShouldClose(window)) {
    bind_texture(tex);
    glUseProgram(rayprog);
    glUniform1f(1, time);
    glDispatchCompute(512, 512, 1);
    glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(quad_shader);
    glBindVertexArray(quad_vao);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex);
    glUniform1i(1, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glfwPollEvents();
    if (GLFW_PRESS == glfwGetKey(window, GLFW_KEY_ESCAPE)) {
      glfwSetWindowShouldClose(window, 1);
    }
    glfwSwapBuffers(window);
    time += 0.005;
  }
}
