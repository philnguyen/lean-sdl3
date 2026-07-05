/* Shims for Sdl/Hints.lean (SDL_hints.h). */
#include "util.h"

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
