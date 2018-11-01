#include <stdlib.h>

typedef struct {
  float x;
  float y;
  float z;
  float radius;
} Prim;

typedef struct {
  Prim* data;
  int cap;
  int len;
} PrimVec;

PrimVec* new_primvec_cap(int cap);
PrimVec* new_primvec();
void primvec_extend(PrimVec* v);
Prim primvec_get(PrimVec* v, int index);
void primvec_set(PrimVec* v, int index, Prim elem);
void primvec_push(PrimVec* v, Prim elem);