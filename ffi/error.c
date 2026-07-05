/* Shims for Sdl/Error.lean (SDL_error.h). */
#include "util.h"

/* Sdl.getError : IO String -- C: SDL_GetError */
LEAN_EXPORT lean_obj_res lean_sdl_get_error(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_mk_string(SDL_GetError()));
}

/* Sdl.clearError : IO Unit -- C: SDL_ClearError */
LEAN_EXPORT lean_obj_res lean_sdl_clear_error(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_ClearError();
    return lean_sdl_unit_ok();
}

/* Sdl.setError (message : @& String) : IO Unit -- C: SDL_SetError */
LEAN_EXPORT lean_obj_res lean_sdl_set_error(b_lean_obj_arg message, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetError("%s", lean_string_cstr(message));
    return lean_sdl_unit_ok();
}
