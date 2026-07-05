/* Shims for Sdl/Locale.lean (SDL_locale.h). */
#include "util.h"

/* Lean-owned maker (see Sdl/Locale.lean). Consumes the owned string objects. */
extern lean_object *lean_sdl_mk_locale(lean_object *language, lean_object *country);

/* Sdl.getPreferredLocales : IO (Array Locale) -- C: SDL_GetPreferredLocales.
 * NULL means failure (including no info available): throw. The result is a
 * single allocation; build the Array Locale via the maker, then SDL_free once. */
LEAN_EXPORT lean_obj_res lean_sdl_get_preferred_locales(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_Locale **locales = SDL_GetPreferredLocales(&count);
    if (!locales) return lean_sdl_throw();
    lean_object *arr = lean_alloc_array((size_t)count, (size_t)count);
    for (int i = 0; i < count; i++) {
        lean_object *language = lean_sdl_mk_string(locales[i]->language);
        lean_object *country = lean_sdl_option_string(locales[i]->country);
        lean_array_set_core(arr, (size_t)i, lean_sdl_mk_locale(language, country));
    }
    SDL_free(locales);
    return lean_io_result_mk_ok(arr);
}
