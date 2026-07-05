#include "util.h"

_Thread_local int lean_sdl_thread_ready = 0;

void lean_sdl_holder_foreach(void *data, b_lean_obj_arg fn) {
    sdl_holder *h = (sdl_holder *)data;
    if (h->owner) {
        lean_inc(fn);
        lean_inc(h->owner);
        lean_object *r = lean_apply_1((lean_object *)fn, h->owner);
        lean_dec(r);
    }
}

lean_object *lean_sdl_wrap(lean_external_class *cls, void *ptr, lean_object *owner) {
    sdl_holder *h = (sdl_holder *)malloc(sizeof(sdl_holder));
    h->ptr = ptr;
    h->owner = owner;
    return lean_alloc_external(cls, h);
}
