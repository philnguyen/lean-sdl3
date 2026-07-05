/* Shims for Sdl/Power.lean (SDL_power.h). */
#include "util.h"

/* Lean-owned maker (see Sdl/Power.lean). */
extern lean_object *lean_sdl_mk_power_info(uint32_t state, int32_t seconds, int32_t percent);

/* Sdl.getPowerInfo : IO PowerInfo -- C: SDL_GetPowerInfo.
 * SDL_POWERSTATE_ERROR (-1) is the failure sentinel: throw on it. Both out
 * params are requested; SDL fills -1 for an unknown seconds/percent, which the
 * maker turns into `none`. */
LEAN_EXPORT lean_obj_res lean_sdl_get_power_info(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int seconds = -1, percent = -1;
    SDL_PowerState st = SDL_GetPowerInfo(&seconds, &percent);
    if (st == SDL_POWERSTATE_ERROR) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_mk_power_info((uint32_t)st, (int32_t)seconds, (int32_t)percent));
}
