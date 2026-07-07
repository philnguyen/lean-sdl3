/* Shims for Sdl/Process.lean (SDL_process.h).
 *
 * One module-local external class:
 *   - lean_sdl_process : OWNED ROOT. Finalizer (and the manual Process.destroy)
 *     run SDL_DestroyProcess; holder owner is always NULL. Destroying does NOT
 *     stop the child, only releases the SDL tracking object (and closes piped
 *     streams).
 *
 * getInput/getOutput hand out BORROWED IOStreams (lean_sdl_iostream_borrowed,
 * owner = the inc'd process external), never closed from Lean. closeInput does
 * the double-close-safe dance: detach the stdin stream from the process's
 * SDL_PROP_PROCESS_STDIN_POINTER property BEFORE closing it, so a later
 * SDL_DestroyProcess (which unconditionally SDL_CloseIO's that property) does
 * not double-free. read crosses (bytes, exitcode) through the Lean maker
 * lean_sdl_mk_process_read. */
#include "util.h"
#include "classes.h"

/* Lean-owned maker (Sdl/Process.lean): pairs stdout bytes with the exit code. */
extern lean_object *lean_sdl_mk_process_read(lean_object *data, int32_t exitcode);

/* Owned root: finalizer destroys the SDL process object. */
SDL_DEFINE_CLASS(lean_sdl_process, SDL_DestroyProcess((SDL_Process *)self))

/* Register the class. Called from Sdl/Process.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_process_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_process_class_init();
    return lean_sdl_unit_ok();
}

/* Sdl.createProcessRaw (args : @& Array String) (pipeStdio : Bool) : IO Process
 * -- C: SDL_CreateProcess. Build a NULL-terminated argv of borrowed cstrs (SDL
 * copies them for posix_spawn); NULL process -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_create_process(
        b_lean_obj_arg args, uint8_t pipe_stdio, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t n = lean_array_size(args);
    const char **argv = malloc((n + 1) * sizeof(char *));
    if (!argv) return lean_sdl_throw_msg("SDL: out of memory building argv");
    for (size_t i = 0; i < n; i++)
        argv[i] = lean_string_cstr(lean_array_get_core(args, i));
    argv[n] = NULL;
    SDL_Process *p = SDL_CreateProcess(argv, pipe_stdio != 0);
    free(argv);
    if (!p) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_process_class, p, NULL));
}

/* Sdl.createProcessWithProperties (props : @& Properties) : IO Process
 * -- C: SDL_CreateProcessWithProperties (holder ptr encodes an
 * SDL_PropertiesID; NULL process -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_create_process_with_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(props);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_Process *p =
        SDL_CreateProcessWithProperties((SDL_PropertiesID)(uintptr_t)h->ptr);
    if (!p) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_process_class, p, NULL));
}

/* Sdl.Process.getProperties : IO Properties -- C: SDL_GetProcessProperties.
 * Borrowed Properties tied to the process (owner = inc'd process external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_process_properties(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    SDL_PropertiesID id = SDL_GetProcessProperties(p);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Process.read : IO (ByteArray x Int32) -- C: SDL_ReadProcess (blocks to
 * exit; NULL -> throw). Copy the SDL-owned buffer into a fresh sarray, free it,
 * pair with the exitcode via the Lean maker. */
LEAN_EXPORT lean_obj_res lean_sdl_read_process(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    size_t datasize = 0;
    int exitcode = 0;
    void *data = SDL_ReadProcess(p, &datasize, &exitcode);
    if (!data) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, datasize, datasize);
    if (datasize) SDL_memcpy(lean_sarray_cptr(arr), data, datasize);
    SDL_free(data);
    return lean_io_result_mk_ok(lean_sdl_mk_process_read(arr, (int32_t)exitcode));
}

/* Sdl.Process.getInput : IO IOStream -- C: SDL_GetProcessInput. Borrowed stream
 * (owner = inc'd process); NULL -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_process_input(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    SDL_IOStream *io = SDL_GetProcessInput(p);
    if (!io) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_iostream_borrowed(io, (lean_object *)self));
}

/* Sdl.Process.getOutput : IO IOStream -- C: SDL_GetProcessOutput. Borrowed
 * stream (owner = inc'd process); NULL -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_process_output(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    SDL_IOStream *io = SDL_GetProcessOutput(p);
    if (!io) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_iostream_borrowed(io, (lean_object *)self));
}

/* Sdl.Process.closeInput : IO Unit -- C: SDL_CloseIO on the stdin stream, made
 * double-close-safe. SDL_DestroyProcess unconditionally SDL_CloseIO's whatever
 * SDL_PROP_PROCESS_STDIN_POINTER holds, so: fetch the stream, clear that
 * property, THEN close it. Afterwards SDL_GetProcessInput returns NULL and the
 * binding throws. Throws if there was no piped stdin. */
LEAN_EXPORT lean_obj_res lean_sdl_close_process_input(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    SDL_IOStream *io = SDL_GetProcessInput(p);
    if (!io) return lean_sdl_throw();
    SDL_SetPointerProperty(SDL_GetProcessProperties(p),
                           SDL_PROP_PROCESS_STDIN_POINTER, NULL);
    if (!SDL_CloseIO(io)) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.Process.kill (force : Bool) : IO Unit -- C: SDL_KillProcess. */
LEAN_EXPORT lean_obj_res lean_sdl_kill_process(
        b_lean_obj_arg self, uint8_t force, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    SDL_BOOL_TO_IO(SDL_KillProcess(p, force != 0));
}

/* Sdl.Process.wait (block : Bool) : IO (Option Int32) -- C: SDL_WaitProcess.
 * false (still running, only possible when !block) -> none; true -> some
 * exitcode (a negative signal number if killed by a signal). */
LEAN_EXPORT lean_obj_res lean_sdl_wait_process(
        b_lean_obj_arg self, uint8_t block, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Process, p, self);
    int exitcode = 0;
    if (!SDL_WaitProcess(p, block != 0, &exitcode))
        return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(
        lean_sdl_some(lean_box_uint32((uint32_t)(int32_t)exitcode)));
}

/* Sdl.Process.destroy : IO Unit -- C: SDL_DestroyProcess. Manual destroy: NULL
 * the ptr so the finalizer skips and later use throws. Does NOT stop the
 * child. */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_process(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_DestroyProcess((SDL_Process *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}
