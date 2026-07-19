#include "util.h"

#include <stdlib.h>

_Thread_local int lean_sdl_thread_ready = 0;

/* Lean's generated entry point runs `main` through `lean_run_main`, which by
   default moves it onto a spawned thread (stack-size control) — macOS's cocoa
   video driver then refuses to create a device ("No available video device";
   AppKit requires the process's primary thread). Image-load constructors run
   on the primary thread before `main`, so opt out here for every binary that
   links these bindings. An explicit LEAN_MAIN_USE_THREAD in the environment
   is not overwritten. Applied on all POSIX platforms — some Linux video
   setups care about the primary thread too, and consistency costs nothing.
   Skipped on Windows (no setenv; win32 video has no such constraint). */
#ifndef _WIN32
__attribute__((constructor))
static void lean_sdl_force_main_thread(void) {
    setenv("LEAN_MAIN_USE_THREAD", "0", 0 /* don't overwrite */);
}
#endif

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

/* ByteArray.push of 4 little-endian bytes in one runtime call. Hot-path
 * packing helper for the per-frame SDL_FPoint[]/SDL_FRect[]/SDL_Vertex[]/int[]
 * buffers in Sdl/Render.lean (pure @[extern]; byte-order explicit, so the
 * result is identical on any host). */
LEAN_EXPORT lean_object *lean_sdl_byte_array_push_u32le(lean_obj_arg b, uint32_t v) {
    size_t sz = lean_sarray_size(b);
    if (lean_is_exclusive(b) && lean_sarray_capacity(b) >= sz + 4) {
        uint8_t *p = lean_sarray_cptr(b) + sz;
        p[0] = (uint8_t)v;
        p[1] = (uint8_t)(v >> 8);
        p[2] = (uint8_t)(v >> 16);
        p[3] = (uint8_t)(v >> 24);
        lean_sarray_set_size(b, sz + 4);
        return b;
    }
    /* Shared or full: fall back to the runtime's copy/grow push. */
    lean_object *r = lean_byte_array_push(b, (uint8_t)v);
    r = lean_byte_array_push(r, (uint8_t)(v >> 8));
    r = lean_byte_array_push(r, (uint8_t)(v >> 16));
    return lean_byte_array_push(r, (uint8_t)(v >> 24));
}
