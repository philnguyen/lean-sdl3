/* Shims for Sdl/Log.lean (SDL_log.h). */
#include "util.h"
#include "callbacks.h"

/* Sdl.setLogPriorities -- C: SDL_SetLogPriorities */
LEAN_EXPORT lean_obj_res lean_sdl_set_log_priorities(uint32_t priority, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetLogPriorities((SDL_LogPriority)priority);
    return lean_sdl_unit_ok();
}

/* Sdl.setLogPriority -- C: SDL_SetLogPriority */
LEAN_EXPORT lean_obj_res lean_sdl_set_log_priority(
        uint32_t category, uint32_t priority, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetLogPriority((int)category, (SDL_LogPriority)priority);
    return lean_sdl_unit_ok();
}

/* Sdl.getLogPriorityRaw -- C: SDL_GetLogPriority */
LEAN_EXPORT lean_obj_res lean_sdl_get_log_priority(uint32_t category, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetLogPriority((int)category)));
}

/* Sdl.resetLogPriorities -- C: SDL_ResetLogPriorities */
LEAN_EXPORT lean_obj_res lean_sdl_reset_log_priorities(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_ResetLogPriorities();
    return lean_sdl_unit_ok();
}

/* Sdl.setLogPriorityPrefix -- C: SDL_SetLogPriorityPrefix.
 * `prefix_opt` is an owned `Option String`; `none` (NULL prefix) resets the
 * default. `lean_sdl_option_take` yields an owned payload we must dec. */
LEAN_EXPORT lean_obj_res lean_sdl_set_log_priority_prefix(
        uint32_t priority, lean_obj_arg prefix_opt, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_object *s = lean_sdl_option_take(prefix_opt);
    bool ok = SDL_SetLogPriorityPrefix((SDL_LogPriority)priority,
                                       s ? lean_string_cstr(s) : NULL);
    if (s) lean_dec(s);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.log -- C: SDL_Log (message passed as a "%s" argument, never a format). */
LEAN_EXPORT lean_obj_res lean_sdl_log(b_lean_obj_arg msg, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Log("%s", lean_string_cstr(msg));
    return lean_sdl_unit_ok();
}

/* Sdl.logMessage -- C: SDL_LogMessage (message passed as a "%s" argument). */
LEAN_EXPORT lean_obj_res lean_sdl_log_message(
        uint32_t category, uint32_t priority, b_lean_obj_arg msg, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_LogMessage((int)category, (SDL_LogPriority)priority, "%s", lean_string_cstr(msg));
    return lean_sdl_unit_ok();
}

/* ---- Log output function (locked slot; docs/DESIGN.md "Callbacks" #2).
 * SDL keeps exactly one output function; ours is a static slot. Restoring
 * goes through SDL_GetDefaultLogOutputFunction, not NULL. */

static sdl_cb_slot lean_sdl_log_output_slot;

/* Registered closure: UInt32 -> UInt32 -> String -> IO Unit
 * (category, priority, message). */
static void SDLCALL lean_sdl_log_output_tramp(void *userdata, int category,
                                              SDL_LogPriority priority,
                                              const char *message) {
    (void)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_slot_acquire(&lean_sdl_log_output_slot);
    if (!fn) return; /* reset mid-dispatch */
    lean_sdl_io_ignore(lean_apply_4(fn, lean_box_uint32((uint32_t)category),
        lean_box_uint32((uint32_t)priority), lean_sdl_mk_string(message),
        lean_box(0)));
}

/* Sdl.setLogOutputFunctionRaw -- C: SDL_SetLogOutputFunction */
LEAN_EXPORT lean_obj_res lean_sdl_set_log_output_function(lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_slot_set(&lean_sdl_log_output_slot, fn);
    SDL_SetLogOutputFunction(lean_sdl_log_output_tramp, NULL);
    return lean_sdl_unit_ok();
}

/* Sdl.resetLogOutputFunction -- C: SDL_SetLogOutputFunction with
 * SDL_GetDefaultLogOutputFunction. SDL is unhooked before the slot is
 * cleared; a trampoline mid-flight already holds its own closure ref. */
LEAN_EXPORT lean_obj_res lean_sdl_reset_log_output_function(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetLogOutputFunction(SDL_GetDefaultLogOutputFunction(), NULL);
    lean_sdl_slot_clear(&lean_sdl_log_output_slot);
    return lean_sdl_unit_ok();
}
