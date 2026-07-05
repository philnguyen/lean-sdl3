/* Shims for Sdl/Misc.lean (SDL_misc.h). */
#include "util.h"

/* Sdl.openURL (url : @& String) : IO Unit -- C: SDL_OpenURL */
LEAN_EXPORT lean_obj_res lean_sdl_open_url(b_lean_obj_arg url, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_OpenURL(lean_string_cstr(url)));
}
