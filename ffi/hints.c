/* Shims for Sdl/Hints.lean (SDL_hints.h). */
#include "util.h"
#include "callbacks.h"

/* Sdl.setHint -- C: SDL_SetHint */
LEAN_EXPORT lean_obj_res lean_sdl_set_hint(
        b_lean_obj_arg name, b_lean_obj_arg value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetHint(lean_string_cstr(name), lean_string_cstr(value)));
}

/* Sdl.setHintWithPriority -- C: SDL_SetHintWithPriority */
LEAN_EXPORT lean_obj_res lean_sdl_set_hint_with_priority(
        b_lean_obj_arg name, b_lean_obj_arg value, uint32_t priority, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetHintWithPriority(lean_string_cstr(name),
                                           lean_string_cstr(value),
                                           (SDL_HintPriority)priority));
}

/* Sdl.resetHint -- C: SDL_ResetHint */
LEAN_EXPORT lean_obj_res lean_sdl_reset_hint(b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_ResetHint(lean_string_cstr(name)));
}

/* Sdl.resetHints -- C: SDL_ResetHints */
LEAN_EXPORT lean_obj_res lean_sdl_reset_hints(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_ResetHints();
    return lean_sdl_unit_ok();
}

/* Sdl.getHint : IO (Option String) -- C: SDL_GetHint.
 * NULL is `none` (not an error). The returned pointer is SDL-owned, so copy
 * it into a Lean string before returning. */
LEAN_EXPORT lean_obj_res lean_sdl_get_hint(b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetHint(lean_string_cstr(name));
    return lean_io_result_mk_ok(lean_sdl_option_string(s));
}

/* Sdl.getHintBoolean -- C: SDL_GetHintBoolean */
LEAN_EXPORT lean_obj_res lean_sdl_get_hint_boolean(
        b_lean_obj_arg name, uint8_t default_value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box(SDL_GetHintBoolean(lean_string_cstr(name), default_value != 0)));
}

/* ---- Hint callbacks (gen-key registry; docs/DESIGN.md "Callbacks" #1).
 * Entry aux = an SDL_strdup'd copy of the hint name, needed again for
 * SDL_RemoveHintCallback (SDL identifies a callback by name + fn + userdata).
 * SDL_AddHintCallback invokes the callback synchronously during registration
 * (initial value) on this Lean thread; the entry is registered first, so the
 * trampoline finds it. */

static sdl_cb_registry lean_sdl_hint_registry;

/* Registered closure: String -> Option String -> Option String -> IO Unit
 * (name, oldValue, newValue). */
static void SDLCALL lean_sdl_hint_tramp(void *userdata, const char *name,
                                        const char *old_value, const char *new_value) {
    uint64_t key = (uint64_t)(uintptr_t)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_cb_acquire(&lean_sdl_hint_registry, key);
    if (!fn) return;
    lean_sdl_io_ignore(lean_apply_4(fn, lean_sdl_mk_string(name),
        lean_sdl_option_string(old_value), lean_sdl_option_string(new_value),
        lean_box(0)));
}

/* Sdl.addHintCallbackRaw -- C: SDL_AddHintCallback */
LEAN_EXPORT lean_obj_res lean_sdl_add_hint_callback(
        b_lean_obj_arg name, lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *name_copy = SDL_strdup(lean_string_cstr(name));
    uint64_t key = lean_sdl_cb_register(&lean_sdl_hint_registry, fn, (uintptr_t)name_copy);
    if (!SDL_AddHintCallback(name_copy, lean_sdl_hint_tramp, (void *)(uintptr_t)key)) {
        lean_object *f;
        uintptr_t aux;
        if (lean_sdl_cb_take(&lean_sdl_hint_registry, key, &f, &aux)) {
            lean_dec(f);
            SDL_free((void *)aux);
        }
        return lean_sdl_throw();
    }
    return lean_io_result_mk_ok(lean_box_uint64(key));
}

/* Sdl.removeHintCallbackRaw -- C: SDL_RemoveHintCallback (void; our bool =
 * "was registered"). */
LEAN_EXPORT lean_obj_res lean_sdl_remove_hint_callback(uint64_t key, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_object *fn;
    uintptr_t aux;
    bool had = lean_sdl_cb_take(&lean_sdl_hint_registry, key, &fn, &aux);
    if (had) {
        SDL_RemoveHintCallback((const char *)aux, lean_sdl_hint_tramp,
                               (void *)(uintptr_t)key);
        lean_dec(fn);
        SDL_free((void *)aux);
    }
    return lean_io_result_mk_ok(lean_box(had ? 1 : 0));
}
