/* Shims for Sdl/AsyncIO.lean (SDL_asyncio.h).
 *
 * Two external classes:
 *   - lean_sdl_asyncio       : CONSUMABLE (GPU-command-buffer archetype), owner
 *     always NULL. `close` NULLs the holder ptr on success so later use throws.
 *     The FINALIZER does NOT close: closing needs a queue and spawns an async
 *     task, so a dropped unclosed AsyncIO leaks its OS handle (documented; the
 *     user must always call close).
 *   - lean_sdl_asyncioqueue  : OWNED ROOT (leaf), owner NULL. Both destroy and
 *     the finalizer run SDL_DestroyAsyncIOQueue; destroy NULLs the ptr.
 *
 * Buffer lifetime: SDL needs read/write buffers to outlive the task, but Lean
 * ByteArrays can move/collect. So the shim mallocs a staging buffer for every
 * read and write (userdata is a plain uint64 tag cast to void*, never freeable
 * memory). When an outcome is retrieved, a completed READ's bytes are copied
 * into a fresh ByteArray and the staging buffer is freed; a WRITE/CLOSE outcome
 * frees the staging buffer (if any) and reports buffer=none. loadFileAsync
 * outcomes are READs whose SDL-allocated buffer takes the same copy+free path.
 * The outcome's asyncio pointer is deliberately not exposed. */
#include "util.h"

/* Lean-owned maker (see Sdl/AsyncIO.lean). Scalars cross unboxed even mixed
 * with the object `buffer` param; confirmed against .lake/build/ir. */
extern lean_object *lean_sdl_mk_asyncio_outcome(
    uint32_t task_type, uint32_t result, lean_object *buffer,
    uint64_t offset, uint64_t bytes_requested, uint64_t bytes_transferred,
    uint64_t userdata);

/* Consumable: finalizer does not close (needs a queue + async task). */
SDL_DEFINE_CLASS(lean_sdl_asyncio, (void)0)

/* Owned root leaf: finalizer destroys the queue. */
SDL_DEFINE_CLASS(lean_sdl_asyncioqueue, SDL_DestroyAsyncIOQueue((SDL_AsyncIOQueue *)self))

/* Register both classes. Called from Sdl/AsyncIO.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_asyncio_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_asyncio_class_init();
    lean_sdl_asyncioqueue_class_init();
    return lean_sdl_unit_ok();
}

/* The single outcome-conversion helper (used by getResult and waitResult).
 * Builds the Lean AsyncIOOutcome, handling the buffer copy/free switch. */
static lean_object *lean_sdl_outcome_of(const SDL_AsyncIOOutcome *o) {
    lean_object *buf = lean_sdl_none();
    switch (o->type) {
    case SDL_ASYNCIO_TASK_READ:
        if (o->result == SDL_ASYNCIO_COMPLETE && o->buffer) {
            size_t n = (size_t)o->bytes_transferred;
            lean_object *arr = lean_alloc_sarray(1, n, n);
            if (n) SDL_memcpy(lean_sarray_cptr(arr), o->buffer, n);
            buf = lean_sdl_some(arr);
        }
        if (o->buffer) SDL_free(o->buffer);
        break;
    case SDL_ASYNCIO_TASK_WRITE:
        if (o->buffer) SDL_free(o->buffer);
        break;
    case SDL_ASYNCIO_TASK_CLOSE:
    default:
        break;
    }
    return lean_sdl_mk_asyncio_outcome(
        (uint32_t)o->type, (uint32_t)o->result, buf,
        (uint64_t)o->offset, (uint64_t)o->bytes_requested,
        (uint64_t)o->bytes_transferred, (uint64_t)(uintptr_t)o->userdata);
}

/* ==================== AsyncIO ==================== */

/* Sdl.AsyncIO.fromFile (file mode : String) : IO AsyncIO
 * -- C: SDL_AsyncIOFromFile (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_asyncio_from_file(
        b_lean_obj_arg file, b_lean_obj_arg mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AsyncIO *aio = SDL_AsyncIOFromFile(lean_string_cstr(file), lean_string_cstr(mode));
    if (!aio) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_asyncio_class, aio, NULL));
}

/* Sdl.AsyncIO.getSize : IO Int64 -- C: SDL_GetAsyncIOSize (negative -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_asyncio_size(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIO, aio, self);
    Sint64 sz = SDL_GetAsyncIOSize(aio);
    if (sz < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)sz));
}

/* Sdl.AsyncIO.read (offset size : UInt64) (queue) (userdata : UInt64) : IO Unit
 * -- C: SDL_ReadAsyncIO. The shim owns a malloc'd staging buffer until the task
 * completes; on a failed *start* it is freed immediately. */
LEAN_EXPORT lean_obj_res lean_sdl_read_asyncio(
        b_lean_obj_arg self, uint64_t offset, uint64_t size,
        b_lean_obj_arg queue, uint64_t userdata, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIO, aio, self);
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, queue);
    void *staging = SDL_malloc(size ? (size_t)size : 1);
    if (!staging) return lean_sdl_throw();
    if (!SDL_ReadAsyncIO(aio, staging, offset, size, q, (void *)(uintptr_t)userdata)) {
        SDL_free(staging);
        return lean_sdl_throw();
    }
    return lean_sdl_unit_ok();
}

/* Sdl.AsyncIO.write (data : @& ByteArray) (offset) (queue) (userdata) : IO Unit
 * -- C: SDL_WriteAsyncIO. The shim copies `data` into a malloc'd staging buffer
 * that it owns until completion; a failed *start* frees it immediately. */
LEAN_EXPORT lean_obj_res lean_sdl_write_asyncio(
        b_lean_obj_arg self, b_lean_obj_arg data, uint64_t offset,
        b_lean_obj_arg queue, uint64_t userdata, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIO, aio, self);
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, queue);
    size_t n = lean_sarray_size(data);
    void *staging = SDL_malloc(n ? n : 1);
    if (!staging) return lean_sdl_throw();
    if (n) SDL_memcpy(staging, lean_sarray_cptr((lean_object *)data), n);
    if (!SDL_WriteAsyncIO(aio, staging, offset, (Uint64)n, q, (void *)(uintptr_t)userdata)) {
        SDL_free(staging);
        return lean_sdl_throw();
    }
    return lean_sdl_unit_ok();
}

/* Sdl.AsyncIO.close (flush : Bool) (queue) (userdata) : IO Unit
 * -- C: SDL_CloseAsyncIO. On true the handle is consumed (ptr NULLed) so later
 * use throws; on false the close never started and the handle stays valid. */
LEAN_EXPORT lean_obj_res lean_sdl_close_asyncio(
        b_lean_obj_arg self, uint8_t flush, b_lean_obj_arg queue,
        uint64_t userdata, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, queue);
    if (!SDL_CloseAsyncIO((SDL_AsyncIO *)h->ptr, flush != 0, q,
                          (void *)(uintptr_t)userdata))
        return lean_sdl_throw();
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* ==================== AsyncIOQueue ==================== */

/* Sdl.AsyncIOQueue.create : IO AsyncIOQueue -- C: SDL_CreateAsyncIOQueue. */
LEAN_EXPORT lean_obj_res lean_sdl_create_asyncio_queue(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AsyncIOQueue *q = SDL_CreateAsyncIOQueue();
    if (!q) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_asyncioqueue_class, q, NULL));
}

/* Sdl.AsyncIOQueue.destroy : IO Unit -- C: SDL_DestroyAsyncIOQueue (consumes
 * the handle; ptr NULLed so later use throws). */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_asyncio_queue(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_DestroyAsyncIOQueue((SDL_AsyncIOQueue *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.AsyncIOQueue.getResult : IO (Option AsyncIOOutcome)
 * -- C: SDL_GetAsyncIOResult (false = no completed task = none, NOT an error). */
LEAN_EXPORT lean_obj_res lean_sdl_get_asyncio_result(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, self);
    SDL_AsyncIOOutcome outcome;
    SDL_zero(outcome);
    if (!SDL_GetAsyncIOResult(q, &outcome))
        return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_outcome_of(&outcome)));
}

/* Sdl.AsyncIOQueue.waitResult (timeoutMs : Int32) : IO (Option AsyncIOOutcome)
 * -- C: SDL_WaitAsyncIOResult (false on timeout/spurious/signal = none). */
LEAN_EXPORT lean_obj_res lean_sdl_wait_asyncio_result(
        b_lean_obj_arg self, int32_t timeout_ms, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, self);
    SDL_AsyncIOOutcome outcome;
    SDL_zero(outcome);
    if (!SDL_WaitAsyncIOResult(q, &outcome, (Sint32)timeout_ms))
        return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_outcome_of(&outcome)));
}

/* Sdl.AsyncIOQueue.signal : IO Unit -- C: SDL_SignalAsyncIOQueue. */
LEAN_EXPORT lean_obj_res lean_sdl_signal_asyncio_queue(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, self);
    SDL_SignalAsyncIOQueue(q);
    return lean_sdl_unit_ok();
}

/* Sdl.loadFileAsync (file : @& String) (queue) (userdata) : IO Unit
 * -- C: SDL_LoadFileAsync. A missing file fails immediately (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_load_file_async(
        b_lean_obj_arg file, b_lean_obj_arg queue, uint64_t userdata, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AsyncIOQueue, q, queue);
    if (!SDL_LoadFileAsync(lean_string_cstr(file), q, (void *)(uintptr_t)userdata))
        return lean_sdl_throw();
    return lean_sdl_unit_ok();
}
