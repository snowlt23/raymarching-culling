#!/bin/sh
cat raymarch.glsl adaptive.glsl | ./glsl-to-str.sh > adaptive.gen.glsl
cat raymarch.glsl render.glsl | ./glsl-to-str.sh > render.gen.glsl
gcc -Wall main.c -Iinclude -L. -lopengl32 -lglfw3 -lglew32
