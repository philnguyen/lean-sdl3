/* Shared machinery for the lean-sdl3 C shims. See docs/DESIGN.md. */
#pragma once
#include <lean/lean.h>
#include <SDL3/SDL.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------- Lean-runtime thread registration ----------
 * Exported by the Lean runtime but not declared in lean.h as of v4.31.0.
 * Guarded so a future toolchain that declares them won't conflict. */
#ifndef LEAN_SDL_HAVE_THREAD_DECLS
extern void lean_initialize_thread(void);
extern void lean_finalize_thread(void);
#endif

extern _Thread_local int lean_sdl_thread_ready;

/* Every @[extern] shim entry runs on a Lean-managed thread; mark it ready so
 * a synchronous callback (e.g. a hint callback during SetHint) never
 * re-initializes an already-initialized Lean thread. */
#define SDL_SHIM_PROLOGUE() (lean_sdl_thread_ready = 1)

/* Every callback trampoline that may run on an SDL-owned thread (timer,
 * audio, dialog...) starts with this. lean_finalize_thread is never called:
 * SDL threads are long-lived (bounded, documented TLS leak). */
static inline void lean_sdl_ensure_thread(void) {
    if (!lean_sdl_thread_ready) {
        lean_initialize_thread();
        lean_sdl_thread_ready = 1;
    }
}

/* ---------- IO results and errors ---------- */

static inline lean_obj_res lean_sdl_unit_ok(void) {
    return lean_io_result_mk_ok(lean_box(0));
}

static inline lean_obj_res lean_sdl_throw_msg(char const *msg) {
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string(msg)));
}

/* IO error carrying SDL_GetError(). */
static inline lean_obj_res lean_sdl_throw(void) {
    char const *msg = SDL_GetError();
    return lean_sdl_throw_msg((msg && *msg) ? msg : "SDL: unknown error");
}

/* bool-returning SDL call -> IO Unit */
#define SDL_BOOL_TO_IO(call) \
    do { if (!(call)) return lean_sdl_throw(); return lean_sdl_unit_ok(); } while (0)

/* ---------- Option / String / Array helpers ---------- */

static inline lean_object *lean_sdl_none(void) { return lean_box(0); }

static inline lean_object *lean_sdl_some(lean_object *v) {
    lean_object *o = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(o, 0, v);
    return o;
}

static inline lean_object *lean_sdl_mk_string(char const *s) {
    return lean_mk_string(s ? s : "");
}

static inline lean_object *lean_sdl_option_string(char const *s) {
    return s ? lean_sdl_some(lean_mk_string(s)) : lean_sdl_none();
}

/* NULL-terminated char* array -> Array String */
static inline lean_object *lean_sdl_string_array(char const *const *xs) {
    size_t n = 0;
    if (xs) while (xs[n]) n++;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_mk_string(xs[i]));
    return arr;
}

/* Consume an owned `Option a`, returning the owned payload or NULL. */
static inline lean_object *lean_sdl_option_take(lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL; /* none = lean_box(0) */
    lean_object *v = lean_ctor_get(opt, 0);
    lean_inc(v);
    lean_dec(opt);
    return v;
}

/* ---------- Ownership holder (docs/DESIGN.md "Ownership") ----------
 * Every external class wraps a heap-allocated sdl_holder. `owner` is an
 * owned reference to the parent handle's external object (or NULL): the
 * parent's finalizer cannot run before the child's (RC ordering). */
typedef struct {
    void        *ptr;   /* SDL object; NULL after manual destroy/consume */
    lean_object *owner; /* owned ref to parent external, or NULL */
} sdl_holder;

/* foreach: propagate mark_mt/mark_persistent into `owner` (NOT an ordering
 * mechanism). Shared by all holder-based classes. */
void lean_sdl_holder_foreach(void *data, b_lean_obj_arg fn);

/* Allocate a holder and wrap it in an external object. Takes ownership of
 * `owner` (pass NULL for root handles). */
lean_object *lean_sdl_wrap(lean_external_class *cls, void *ptr, lean_object *owner);

static inline sdl_holder *lean_sdl_holder_of(b_lean_obj_arg o) {
    return (sdl_holder *)lean_get_external_data(o);
}

/* Use-after-destroy guard: fetch the SDL pointer or throw. */
#define SDL_GET_OR_THROW(T, var, obj) \
    T *var = (T *)lean_sdl_holder_of(obj)->ptr; \
    if (!var) return lean_sdl_throw_msg("SDL: handle used after destroy/release")

/* Define an owned external class over sdl_holder. DESTROY_STMT may use
 * `self` (a void*). Registration must be called from the module's Lean
 * `initialize` block (main thread, deterministic). */
#define SDL_DEFINE_CLASS(name, DESTROY_STMT)                                   \
    static void name##_finalize(void *data) {                                  \
        sdl_holder *h = (sdl_holder *)data;                                    \
        void *self = h->ptr;                                                   \
        (void)self;                                                            \
        if (h->ptr) { DESTROY_STMT; }                                          \
        if (h->owner) lean_dec(h->owner);                                      \
        free(h);                                                               \
    }                                                                          \
    lean_external_class *name##_class = NULL;                                  \
    static void name##_class_init(void) {                                      \
        name##_class =                                                         \
            lean_register_external_class(name##_finalize, lean_sdl_holder_foreach); \
    }

/* Borrowed variant: never destroys `ptr`, only releases the owner ref. */
#define SDL_DEFINE_BORROWED_CLASS(name) SDL_DEFINE_CLASS(name, (void)0)

#ifdef __cplusplus
}
#endif
