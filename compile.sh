#!/bin/sh
cat compute.glsl | ./glsl-to-str.sh > compute.gen.glsl
gcc -Wall main.c -Iinclude -L. -lopengl32 -lglfw3 -lglew32
