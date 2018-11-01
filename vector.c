#include "raycull.h"

PrimVec* new_primvec_cap(int cap) {
  PrimVec* v = malloc(sizeof(PrimVec));
  v->data = malloc(cap*sizeof(Prim));
  v->cap = cap;
  v->len = 0;
  return v;
}
PrimVec* new_primvec() {
  return new_primvec_cap(256);
}

void primvec_extend(PrimVec* v) {
  if (v->cap < v->len+1) {
    v->data = realloc(v->data, v->cap*2*sizeof(Prim));
    v->cap *= 2;
  }
}

Prim primvec_get(PrimVec* v, int index) {
  return v->data[index];
}
void primvec_set(PrimVec* v, int index, Prim elem) {
  v->data[index] = elem;
}

void primvec_push(PrimVec* v, Prim elem) {
  primvec_extend(v);
  primvec_set(v, v->len++, elem);
}
