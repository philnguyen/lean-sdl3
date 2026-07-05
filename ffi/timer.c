/* Shims for Sdl/Timer.lean (SDL_timer.h). */
#include "util.h"

/* Sdl.getTicks : IO UInt64 -- C: SDL_GetTicks */
LEAN_EXPORT lean_obj_res lean_sdl_get_ticks(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint64(SDL_GetTicks()));
}

/* Sdl.getTicksNS : IO UInt64 -- C: SDL_GetTicksNS */
LEAN_EXPORT lean_obj_res lean_sdl_get_ticks_ns(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint64(SDL_GetTicksNS()));
}

/* Sdl.getPerformanceCounter : IO UInt64 -- C: SDL_GetPerformanceCounter */
LEAN_EXPORT lean_obj_res lean_sdl_get_performance_counter(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint64(SDL_GetPerformanceCounter()));
}

/* Sdl.getPerformanceFrequency : IO UInt64 -- C: SDL_GetPerformanceFrequency */
LEAN_EXPORT lean_obj_res lean_sdl_get_performance_frequency(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint64(SDL_GetPerformanceFrequency()));
}

/* Sdl.delay (ms : UInt32) -- C: SDL_Delay */
LEAN_EXPORT lean_obj_res lean_sdl_delay(uint32_t ms, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Delay(ms);
    return lean_sdl_unit_ok();
}

/* Sdl.delayNS (ns : UInt64) -- C: SDL_DelayNS */
LEAN_EXPORT lean_obj_res lean_sdl_delay_ns(uint64_t ns, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DelayNS(ns);
    return lean_sdl_unit_ok();
}

/* Sdl.delayPrecise (ns : UInt64) -- C: SDL_DelayPrecise */
LEAN_EXPORT lean_obj_res lean_sdl_delay_precise(uint64_t ns, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DelayPrecise(ns);
    return lean_sdl_unit_ok();
}
