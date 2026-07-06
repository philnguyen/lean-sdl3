/* Implementation of the callback primitives. See ffi/callbacks.h. */
#include "callbacks.h"

SDL_Mutex *lean_sdl_cb_mutex;

/* Runs at image load, before main and before any Lean initializer.
 * SDL_CreateMutex is documented safe before SDL_Init. */
__attribute__((constructor)) static void lean_sdl_cb_init(void) {
    lean_sdl_cb_mutex = SDL_CreateMutex();
}

/* ---------- Primitive 1: gen-key registry ---------- */

uint64_t lean_sdl_cb_register(sdl_cb_registry *r, lean_obj_arg fn, uintptr_t aux) {
    lean_mark_mt(fn);
    sdl_cb_entry *e = malloc(sizeof(sdl_cb_entry));
    e->fn = fn;
    e->aux = aux;
    SDL_LockMutex(lean_sdl_cb_mutex);
    e->key = ++r->next_key;
    e->next = r->head;
    r->head = e;
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    return e->key;
}

bool lean_sdl_cb_set_aux(sdl_cb_registry *r, uint64_t key, uintptr_t aux) {
    bool found = false;
    SDL_LockMutex(lean_sdl_cb_mutex);
    for (sdl_cb_entry *e = r->head; e; e = e->next) {
        if (e->key == key) {
            e->aux = aux;
            found = true;
            break;
        }
    }
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    return found;
}

lean_object *lean_sdl_cb_acquire(sdl_cb_registry *r, uint64_t key) {
    lean_object *fn = NULL;
    SDL_LockMutex(lean_sdl_cb_mutex);
    for (sdl_cb_entry *e = r->head; e; e = e->next) {
        if (e->key == key) {
            lean_inc(e->fn);
            fn = e->fn;
            break;
        }
    }
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    return fn;
}

/* Unlink the first entry matching `pred`-style comparison on key or aux. */
static sdl_cb_entry *lean_sdl_cb_unlink(sdl_cb_registry *r, bool by_aux, uint64_t key, uintptr_t aux) {
    sdl_cb_entry *found = NULL;
    SDL_LockMutex(lean_sdl_cb_mutex);
    for (sdl_cb_entry **p = &r->head; *p; p = &(*p)->next) {
        sdl_cb_entry *e = *p;
        if (by_aux ? (e->aux == aux) : (e->key == key)) {
            *p = e->next;
            found = e;
            break;
        }
    }
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    return found;
}

bool lean_sdl_cb_take(sdl_cb_registry *r, uint64_t key, lean_object **fn, uintptr_t *aux) {
    sdl_cb_entry *e = lean_sdl_cb_unlink(r, false, key, 0);
    if (!e) return false;
    *fn = e->fn;
    *aux = e->aux;
    free(e);
    return true;
}

bool lean_sdl_cb_take_by_aux(sdl_cb_registry *r, uintptr_t aux, lean_object **fn, uint64_t *key) {
    sdl_cb_entry *e = lean_sdl_cb_unlink(r, true, 0, aux);
    if (!e) return false;
    *fn = e->fn;
    *key = e->key;
    free(e);
    return true;
}

/* ---------- Primitive 2: locked slot ---------- */

void lean_sdl_slot_set(sdl_cb_slot *s, lean_obj_arg fn) {
    lean_mark_mt(fn);
    SDL_LockMutex(lean_sdl_cb_mutex);
    lean_object *old = s->fn;
    s->fn = fn;
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    if (old) lean_dec(old);
}

void lean_sdl_slot_clear(sdl_cb_slot *s) {
    SDL_LockMutex(lean_sdl_cb_mutex);
    lean_object *old = s->fn;
    s->fn = NULL;
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    if (old) lean_dec(old);
}

lean_object *lean_sdl_slot_acquire(sdl_cb_slot *s) {
    SDL_LockMutex(lean_sdl_cb_mutex);
    lean_object *fn = s->fn;
    if (fn) lean_inc(fn);
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    return fn;
}

/* ---------- IO-result consumption ---------- */

bool lean_sdl_io_bool_or(lean_object *res, bool dflt) {
    bool v = dflt;
    if (lean_io_result_is_ok(res)) v = lean_unbox(lean_io_result_get_value(res)) != 0;
    lean_dec(res);
    return v;
}

uint32_t lean_sdl_io_u32_or(lean_object *res, uint32_t dflt) {
    uint32_t v = dflt;
    if (lean_io_result_is_ok(res)) v = lean_unbox_uint32(lean_io_result_get_value(res));
    lean_dec(res);
    return v;
}

uint64_t lean_sdl_io_u64_or(lean_object *res, uint64_t dflt) {
    uint64_t v = dflt;
    if (lean_io_result_is_ok(res)) v = lean_unbox_uint64(lean_io_result_get_value(res));
    lean_dec(res);
    return v;
}

void lean_sdl_io_ignore(lean_object *res) {
    lean_dec(res);
}

/* ---------- Property cleanup ---------- */

void lean_sdl_cleanup_dec(void *userdata, void *value) {
    (void)userdata;
    if (value) {
        lean_sdl_ensure_thread();
        lean_dec((lean_object *)value);
    }
}
