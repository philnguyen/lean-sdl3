/* Shims for Sdl/Clipboard.lean (SDL_clipboard.h).
 *
 * All functions are main-thread-only and require the video subsystem. No
 * external classes and no Lean-structure makers: every binding takes/returns
 * scalars, strings, a ByteArray, or an Array String, so C never lays out a
 * Lean structure.
 *
 * SDL-allocated results (GetClipboardText / GetPrimarySelectionText /
 * GetClipboardData / GetClipboardMimeTypes) are copied into fresh Lean objects
 * and then SDL_free'd. GetClipboardMimeTypes returns a NULL-terminated char**
 * in a SINGLE allocation: the individual strings are NOT separately freed. */
#include "util.h"

/* Sdl.setClipboardText (text : @& String) : IO Unit -- C: SDL_SetClipboardText. */
LEAN_EXPORT lean_obj_res lean_sdl_set_clipboard_text(b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetClipboardText(lean_string_cstr(text)));
}

/* Sdl.getClipboardText : IO String -- C: SDL_GetClipboardText (SDL-malloc'd;
 * copy then SDL_free; "" on failure is indistinguishable from an empty
 * clipboard per the SDL contract; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_clipboard_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *s = SDL_GetClipboardText();
    if (!s) return lean_sdl_throw();
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(str);
}

/* Sdl.hasClipboardText : IO Bool -- C: SDL_HasClipboardText. */
LEAN_EXPORT lean_obj_res lean_sdl_has_clipboard_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasClipboardText()));
}

/* Sdl.setPrimarySelectionText (text : @& String) : IO Unit
 * -- C: SDL_SetPrimarySelectionText. */
LEAN_EXPORT lean_obj_res lean_sdl_set_primary_selection_text(
        b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetPrimarySelectionText(lean_string_cstr(text)));
}

/* Sdl.getPrimarySelectionText : IO String -- C: SDL_GetPrimarySelectionText
 * (same copy/free/contract as getClipboardText). */
LEAN_EXPORT lean_obj_res lean_sdl_get_primary_selection_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *s = SDL_GetPrimarySelectionText();
    if (!s) return lean_sdl_throw();
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(str);
}

/* Sdl.hasPrimarySelectionText : IO Bool -- C: SDL_HasPrimarySelectionText. */
LEAN_EXPORT lean_obj_res lean_sdl_has_primary_selection_text(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasPrimarySelectionText()));
}

/* Sdl.clearClipboardData : IO Unit -- C: SDL_ClearClipboardData. */
LEAN_EXPORT lean_obj_res lean_sdl_clear_clipboard_data(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_ClearClipboardData());
}

/* Sdl.getClipboardData (mimeType : @& String) : IO ByteArray
 * -- C: SDL_GetClipboardData (SDL-malloc'd; copy into a fresh sarray then
 * SDL_free; NULL, i.e. no data for that mime type, -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_clipboard_data(
        b_lean_obj_arg mime_type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t size = 0;
    void *data = SDL_GetClipboardData(lean_string_cstr(mime_type), &size);
    if (!data) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, size, size);
    if (size) SDL_memcpy(lean_sarray_cptr(arr), data, size);
    SDL_free(data);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.hasClipboardData (mimeType : @& String) : IO Bool
 * -- C: SDL_HasClipboardData. */
LEAN_EXPORT lean_obj_res lean_sdl_has_clipboard_data(
        b_lean_obj_arg mime_type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasClipboardData(lean_string_cstr(mime_type))));
}

/* Sdl.getClipboardMimeTypes : IO (Array String)
 * -- C: SDL_GetClipboardMimeTypes (NULL-terminated char** in a SINGLE
 * allocation; copy each string into the Array via lean_sdl_string_array, then
 * SDL_free the array only -- NOT the individual strings; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_clipboard_mime_types(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t count = 0;
    char **types = SDL_GetClipboardMimeTypes(&count);
    if (!types) return lean_sdl_throw();
    lean_object *arr = lean_sdl_string_array((char const *const *)types);
    SDL_free(types);
    return lean_io_result_mk_ok(arr);
}

/* ==================== Clipboard data provider ====================
 * One-shot-style heap context (docs/DESIGN.md "Callbacks" #3 variant with an
 * SDL-managed lifetime): SDL guarantees exactly one cleanup invocation when
 * the offer is replaced, cleared, or the video subsystem quits. The context
 * additionally retains the last ByteArray handed out: SDL memcpys the buffer
 * immediately (verified in SDL_clipboard.c), the retention is belt-and-braces
 * for platform paths. */

typedef struct {
    lean_object *fn;   /* owned, mt-marked: String -> IO ByteArray */
    lean_object *last; /* last provided ByteArray (mt-marked), or NULL */
} lean_sdl_clipboard_ctx;

/* Guards ctx->last: data requests may fire concurrently on any thread. */
static SDL_SpinLock lean_sdl_clipboard_lock;

/* May fire on any thread whenever someone requests a mime type; with
 * text-only or headless backends it can fire synchronously inside
 * SDL_SetClipboardData / SDL_GetClipboardData. NULL return = no data. */
static const void *SDLCALL lean_sdl_clipboard_data_tramp(
        void *userdata, const char *mime_type, size_t *size) {
    lean_sdl_clipboard_ctx *ctx = (lean_sdl_clipboard_ctx *)userdata;
    lean_sdl_ensure_thread();
    *size = 0;
    lean_inc(ctx->fn);
    lean_object *res = lean_apply_2(ctx->fn, lean_sdl_mk_string(mime_type), lean_box(0));
    if (!lean_io_result_is_ok(res)) { /* exception -> no data for this request */
        lean_dec(res);
        return NULL;
    }
    lean_object *ba = lean_io_result_get_value(res);
    lean_inc(ba);
    lean_dec(res);
    /* The ByteArray's refcount is touched from whichever threads request or
     * clean up, so it must be atomic; the slot swap itself is under a lock
     * (two concurrent requests must not both dec the same old value). */
    lean_mark_mt(ba);
    SDL_LockSpinlock(&lean_sdl_clipboard_lock);
    lean_object *old = ctx->last;
    ctx->last = ba;
    SDL_UnlockSpinlock(&lean_sdl_clipboard_lock);
    if (old) lean_dec(old);
    *size = lean_sarray_size(ba);
    return lean_sarray_cptr(ba);
}

static void SDLCALL lean_sdl_clipboard_cleanup_tramp(void *userdata) {
    lean_sdl_clipboard_ctx *ctx = (lean_sdl_clipboard_ctx *)userdata;
    lean_sdl_ensure_thread();
    lean_dec(ctx->fn);
    SDL_LockSpinlock(&lean_sdl_clipboard_lock);
    lean_object *last = ctx->last;
    ctx->last = NULL;
    SDL_UnlockSpinlock(&lean_sdl_clipboard_lock);
    if (last) lean_dec(last);
    free(ctx);
}

/* Sdl.setClipboardDataRaw -- C: SDL_SetClipboardData.
 * SDL's two pre-installation failure modes (no video, empty mime list) are
 * checked here first, so after the call SDL owns the context: any later
 * failure runs (or already ran) the cleanup — never dec `fn` on that path.
 * SDL copies the mime-type list during the call (SDL_SaveClipboardMimeTypes),
 * so borrowed string pointers suffice. */
LEAN_EXPORT lean_obj_res lean_sdl_set_clipboard_data(
        lean_obj_arg fn, b_lean_obj_arg mime_types, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t n = lean_array_size(mime_types);
    if (n == 0) {
        lean_dec(fn);
        return lean_sdl_throw_msg("SDL: setClipboardData requires at least one mime type");
    }
    if (!SDL_WasInit(SDL_INIT_VIDEO)) {
        lean_dec(fn);
        return lean_sdl_throw_msg("SDL: setClipboardData requires the video subsystem");
    }
    lean_mark_mt(fn);
    lean_sdl_clipboard_ctx *ctx = malloc(sizeof(lean_sdl_clipboard_ctx));
    if (!ctx) { lean_dec(fn); return lean_sdl_throw_msg("SDL: out of memory"); }
    ctx->fn = fn;
    ctx->last = NULL;
    const char **mimes = SDL_malloc(n * sizeof(const char *));
    if (!mimes) {
        lean_dec(fn);
        free(ctx);
        return lean_sdl_throw_msg("SDL: out of memory");
    }
    for (size_t i = 0; i < n; i++)
        mimes[i] = lean_string_cstr(lean_array_get_core(mime_types, i));
    bool ok = SDL_SetClipboardData(lean_sdl_clipboard_data_tramp,
                                   lean_sdl_clipboard_cleanup_tramp, ctx, mimes, n);
    SDL_free(mimes);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}
