/* Lean-closure-as-SDL-callback machinery (docs/DESIGN.md "Callbacks").
 *
 * Three primitives:
 *
 * 1. Gen-key registry (`sdl_cb_registry`): for many-instance callbacks whose
 *    SDL userdata must never be freeable memory (AddTimer, AddEventWatch,
 *    AddHintCallback). Userdata is a nonzero monotone uint64 key into a
 *    mutex-guarded list. Entries are registered BEFORE the SDL add-call (a
 *    timer callback can fire before SDL_AddTimer returns); trampolines
 *    find+inc under the mutex, then apply outside it. At most one trailing
 *    trampoline invocation can happen after removal (it sees no entry and
 *    no-ops), matching SDL's own remove semantics.
 *
 * 2. Locked slot (`sdl_cb_slot`): for single-instance global callbacks
 *    (SetLogOutputFunction, SetEventFilter, SetRelativeMouseTransform) and,
 *    in M9, per-stream audio callbacks. Replace/clear under the mutex; a
 *    trampoline that already acquired (inc'd) the old closure finishes safely.
 *
 * 3. One-shot closure-as-userdata (dialogs): the owned, mt-marked closure IS
 *    the userdata; the trampoline's lean_apply consumes it. No registry entry
 *    to leak or free. Implemented in ffi/dialog.c directly.
 *
 * Synchronous callbacks invoked inside one of our shims (hint callback during
 * SDL_AddHintCallback, property/directory enumeration, SDL_FilterEvents) pass
 * the closure pointer itself as userdata, borrowed for the duration of the
 * shim call — no registry, no mt-marking needed.
 *
 * Every trampoline that can run on an SDL-owned thread starts with
 * lean_sdl_ensure_thread() (ffi/util.h). lean_finalize_thread is never called.
 */
#pragma once
#include "util.h"

#ifdef __cplusplus
extern "C" {
#endif

/* One process-global mutex guards every registry and slot (callback
 * (un)registration is rare; contention is negligible). Created at image load
 * by a constructor in callbacks.c — valid before any shim runs. Never held
 * across an SDL call or a lean_apply. */
extern SDL_Mutex *lean_sdl_cb_mutex;

/* ---------- Primitive 1: gen-key registry ---------- */

typedef struct sdl_cb_entry {
    uint64_t key;      /* nonzero monotone key; the SDL userdata */
    lean_object *fn;   /* owned, lean_mark_mt'd Lean closure */
    uintptr_t aux;     /* domain-specific: SDL_TimerID, strdup'd hint name... */
    struct sdl_cb_entry *next;
} sdl_cb_entry;

/* Zero-initialization is a valid empty registry (define as a static global). */
typedef struct {
    sdl_cb_entry *head;
    uint64_t next_key;
} sdl_cb_registry;

/* mt-mark `fn` (owned) and insert it; returns the new entry's key. */
uint64_t lean_sdl_cb_register(sdl_cb_registry *r, lean_obj_arg fn, uintptr_t aux);

/* Set `aux` on a live entry (e.g. the SDL_TimerID learned only after
 * SDL_AddTimer returns). False if the entry is already gone. */
bool lean_sdl_cb_set_aux(sdl_cb_registry *r, uint64_t key, uintptr_t aux);

/* Find by key and return the closure with +1 refcount (for lean_apply to
 * consume), or NULL if removed. */
lean_object *lean_sdl_cb_acquire(sdl_cb_registry *r, uint64_t key);

/* Atomically unlink by key. On true, *fn is the owned closure (caller decs
 * after the SDL remove-call) and *aux the entry's aux. */
bool lean_sdl_cb_take(sdl_cb_registry *r, uint64_t key, lean_object **fn, uintptr_t *aux);

/* Atomically unlink the first entry whose aux matches. On true, *fn as above
 * and *key the entry's key (for the SDL remove-call's userdata). */
bool lean_sdl_cb_take_by_aux(sdl_cb_registry *r, uintptr_t aux, lean_object **fn, uint64_t *key);

/* ---------- Primitive 2: locked slot ---------- */

/* Zero-initialization is a valid empty slot. */
typedef struct {
    lean_object *fn; /* owned, lean_mark_mt'd, or NULL */
} sdl_cb_slot;

/* mt-mark `fn` (owned) and store it, dec'ing any previous closure (outside
 * the lock; a finalizer cascade must not run under lean_sdl_cb_mutex). */
void lean_sdl_slot_set(sdl_cb_slot *s, lean_obj_arg fn);

/* Clear the slot, dec'ing the previous closure if any. Call only after the
 * SDL-side callback has been unhooked (a trampoline mid-flight that already
 * acquired the closure still finishes safely). */
void lean_sdl_slot_clear(sdl_cb_slot *s);

/* Current closure with +1 refcount, or NULL if empty. */
lean_object *lean_sdl_slot_acquire(sdl_cb_slot *s);

/* ---------- IO-result consumption for trampolines ----------
 * Consume (dec) an io_result from lean_apply_*; on error yield `dflt`.
 * A Lean exception inside an SDL callback has nowhere to propagate, so
 * trampolines map it to a conservative default (documented per binding). */
bool     lean_sdl_io_bool_or(lean_object *res, bool dflt);
uint32_t lean_sdl_io_u32_or(lean_object *res, uint32_t dflt);
uint64_t lean_sdl_io_u64_or(lean_object *res, uint64_t dflt);
/* Unit-returning callback: just consume, ignoring errors. */
void     lean_sdl_io_ignore(lean_object *res);

/* ---------- Owned Lean objects in SDL properties ----------
 * SDL_CleanupPropertyCallback that lean_dec's the stored value. Lets an owned
 * Lean object ride an SDL property (e.g. the per-window hit-test closure):
 * SDL then guarantees exactly one cleanup on overwrite, clear, or property
 * destruction. May fire on any thread; store only mt-marked objects. */
void lean_sdl_cleanup_dec(void *userdata, void *value);

#ifdef __cplusplus
}
#endif
