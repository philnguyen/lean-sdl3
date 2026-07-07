/* Shims for Sdl/System.lean (SDL_system.h).
 *
 * Only the cross-platform, macOS-relevant subset: SDL_IsTablet, SDL_IsTV,
 * SDL_GetSandbox. No external classes. Sandbox crosses as its raw Uint32,
 * decoded by the total Sandbox.ofVal (version-open). */
#include "util.h"

/* Sdl.isTablet : IO Bool -- C: SDL_IsTablet (infallible; false if unknown). */
LEAN_EXPORT lean_obj_res lean_sdl_is_tablet(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsTablet()));
}

/* Sdl.isTV : IO Bool -- C: SDL_IsTV (infallible; false if unknown). */
LEAN_EXPORT lean_obj_res lean_sdl_is_tv(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsTV()));
}

/* Sdl.getSandboxRaw : IO UInt32 -- C: SDL_GetSandbox (0 == SDL_SANDBOX_NONE,
 * a valid result; decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_sandbox(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetSandbox()));
}
