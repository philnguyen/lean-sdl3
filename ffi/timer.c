/* Shims for Sdl/Timer.lean (SDL_timer.h). */
#include "util.h"
#include "callbacks.h"

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

/* ---- Timer callbacks (gen-key registry; docs/DESIGN.md "Callbacks" #1).
 *
 * Entry aux = the SDL_TimerID (set after SDL_AddTimer returns; a callback
 * firing in between still finds its entry by key). The registry entry is
 * dropped by whichever side retires the timer first: the trampoline when the
 * callback returns 0 / throws, or lean_sdl_remove_timer. Both take-under-
 * mutex, so exactly one side decs the closure. */

static sdl_cb_registry lean_sdl_timer_registry;

/* Registered closure: UInt32 -> UInt32 -> IO UInt32 (idVal, interval, next). */
static Uint32 SDLCALL lean_sdl_timer_tramp(void *userdata, SDL_TimerID id, Uint32 interval) {
    uint64_t key = (uint64_t)(uintptr_t)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_cb_acquire(&lean_sdl_timer_registry, key);
    if (!fn) return 0; /* removed; SDL allows one trailing invocation */
    lean_object *res = lean_apply_3(fn, lean_box_uint32(id), lean_box_uint32(interval), lean_box(0));
    Uint32 next = lean_sdl_io_u32_or(res, 0); /* a Lean exception cancels the timer */
    if (next == 0) {
        lean_object *f;
        uintptr_t aux;
        if (lean_sdl_cb_take(&lean_sdl_timer_registry, key, &f, &aux)) lean_dec(f);
    }
    return next;
}

/* Registered closure: UInt32 -> UInt64 -> IO UInt64 (idVal, intervalNS, next). */
static Uint64 SDLCALL lean_sdl_timer_ns_tramp(void *userdata, SDL_TimerID id, Uint64 interval) {
    uint64_t key = (uint64_t)(uintptr_t)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_cb_acquire(&lean_sdl_timer_registry, key);
    if (!fn) return 0;
    lean_object *res = lean_apply_3(fn, lean_box_uint32(id), lean_box_uint64(interval), lean_box(0));
    Uint64 next = lean_sdl_io_u64_or(res, 0);
    if (next == 0) {
        lean_object *f;
        uintptr_t aux;
        if (lean_sdl_cb_take(&lean_sdl_timer_registry, key, &f, &aux)) lean_dec(f);
    }
    return next;
}

/* Register first, SDL-add second, then record the id; on SDL failure take the
 * entry back out. `fn` is owned. */
static lean_obj_res lean_sdl_add_timer_common(lean_obj_arg fn, bool ns, uint64_t interval) {
    uint64_t key = lean_sdl_cb_register(&lean_sdl_timer_registry, fn, 0);
    void *ud = (void *)(uintptr_t)key;
    SDL_TimerID id = ns ? SDL_AddTimerNS(interval, lean_sdl_timer_ns_tramp, ud)
                        : SDL_AddTimer((Uint32)interval, lean_sdl_timer_tramp, ud);
    if (!id) {
        lean_object *f;
        uintptr_t aux;
        if (lean_sdl_cb_take(&lean_sdl_timer_registry, key, &f, &aux)) lean_dec(f);
        return lean_sdl_throw();
    }
    /* False only if the callback already self-canceled -- fine either way. */
    lean_sdl_cb_set_aux(&lean_sdl_timer_registry, key, (uintptr_t)id);
    return lean_io_result_mk_ok(lean_box_uint32(id));
}

/* Sdl.addTimerRaw : UInt32 -> (UInt32 -> UInt32 -> IO UInt32) -> IO UInt32
 * -- C: SDL_AddTimer */
LEAN_EXPORT lean_obj_res lean_sdl_add_timer(uint32_t interval_ms, lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_add_timer_common(fn, false, interval_ms);
}

/* Sdl.addTimerNSRaw : UInt64 -> (UInt32 -> UInt64 -> IO UInt64) -> IO UInt32
 * -- C: SDL_AddTimerNS */
LEAN_EXPORT lean_obj_res lean_sdl_add_timer_ns(uint64_t interval_ns, lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_add_timer_common(fn, true, interval_ns);
}

/* Sdl.removeTimerRaw : UInt32 -> IO Bool -- C: SDL_RemoveTimer */
LEAN_EXPORT lean_obj_res lean_sdl_remove_timer(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_object *fn;
    uint64_t key;
    bool had = lean_sdl_cb_take_by_aux(&lean_sdl_timer_registry, (uintptr_t)id, &fn, &key);
    bool ok = SDL_RemoveTimer((SDL_TimerID)id);
    if (had) lean_dec(fn);
    return lean_io_result_mk_ok(lean_box(ok ? 1 : 0));
}
