/* Shims for Sdl/Dialog.lean (SDL_dialog.h).
 *
 * File dialogs use the one-shot closure-as-userdata primitive
 * (docs/DESIGN.md "Callbacks" #3): the userdata is a small heap context
 * holding the owned, mt-marked Lean closure plus heap copies of the filter
 * array (SDL requires the filters to stay valid until the callback runs).
 * The trampoline consumes the closure and frees the context — SDL guarantees
 * the callback fires exactly once (synchronously on validation errors,
 * possibly later and on another thread otherwise). */
#include "util.h"
#include "callbacks.h"

/* Lean-owned maker (Sdl/Dialog.lean): kind 0 = error, 1 = cancelled,
 * 2 = selected; filter_index < 0 encodes `none`. Keep in sync with the
 * generated prototype in .lake/build/ir/Sdl/Dialog.c. */
extern lean_object *lean_sdl_mk_dialog_result(
    uint8_t kind, lean_object *err, lean_object *paths, int32_t filter_index);

typedef struct {
    lean_object *fn;               /* owned, mt-marked: DialogResult -> IO Unit */
    SDL_DialogFileFilter *filters; /* heap copies, or NULL */
    int nfilters;
} lean_sdl_dialog_ctx;

/* Build the context. `fn` is owned; `names`/`patterns` are borrowed parallel
 * `Array String` (same length; the Lean wrapper guarantees it). */
static lean_sdl_dialog_ctx *lean_sdl_dialog_ctx_new(
        lean_obj_arg fn, b_lean_obj_arg names, b_lean_obj_arg patterns) {
    lean_mark_mt(fn);
    lean_sdl_dialog_ctx *ctx = malloc(sizeof(lean_sdl_dialog_ctx));
    ctx->fn = fn;
    size_t n = lean_array_size(names);
    if (n == 0) {
        ctx->filters = NULL;
        ctx->nfilters = 0;
    } else {
        ctx->filters = SDL_calloc(n, sizeof(SDL_DialogFileFilter));
        for (size_t i = 0; i < n; i++) {
            ctx->filters[i].name =
                SDL_strdup(lean_string_cstr(lean_array_get_core(names, i)));
            ctx->filters[i].pattern =
                SDL_strdup(lean_string_cstr(lean_array_get_core(patterns, i)));
        }
        ctx->nfilters = (int)n;
    }
    return ctx;
}

/* Free the filters and the context (the closure is consumed by lean_apply). */
static void lean_sdl_dialog_ctx_free(lean_sdl_dialog_ctx *ctx) {
    for (int i = 0; i < ctx->nfilters; i++) {
        SDL_free((void *)ctx->filters[i].name);
        SDL_free((void *)ctx->filters[i].pattern);
    }
    SDL_free(ctx->filters);
    free(ctx);
}

/* One-shot trampoline. filelist: NULL = error (SDL_GetError is still valid
 * here), empty = cancelled, else NULL-terminated path array. filter = selected
 * filter index or -1 for unknown/none. */
static void SDLCALL lean_sdl_dialog_tramp(void *userdata,
                                          const char *const *filelist, int filter) {
    lean_sdl_dialog_ctx *ctx = (lean_sdl_dialog_ctx *)userdata;
    lean_sdl_ensure_thread();
    lean_object *result;
    if (!filelist) {
        const char *msg = SDL_GetError();
        result = lean_sdl_mk_dialog_result(0,
            lean_sdl_mk_string((msg && *msg) ? msg : "SDL: unknown error"),
            lean_alloc_array(0, 0), -1);
    } else if (!filelist[0]) {
        result = lean_sdl_mk_dialog_result(1, lean_mk_string(""),
            lean_alloc_array(0, 0), -1);
    } else {
        result = lean_sdl_mk_dialog_result(2, lean_mk_string(""),
            lean_sdl_string_array(filelist), (int32_t)filter);
    }
    lean_sdl_io_ignore(lean_apply_2(ctx->fn, result, lean_box(0)));
    lean_sdl_dialog_ctx_free(ctx);
}

/* Borrowed `Option String` -> C string or NULL. */
static const char *lean_sdl_option_cstr(b_lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL;
    return lean_string_cstr(lean_ctor_get(opt, 0));
}

/* Borrowed `Option Window` -> SDL_Window* or NULL. Windows are finalizer-only,
 * so a live reference always has a live pointer. */
static SDL_Window *lean_sdl_option_window(b_lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL;
    return (SDL_Window *)lean_sdl_holder_of(lean_ctor_get(opt, 0))->ptr;
}

/* Sdl.showOpenFileDialogRaw -- C: SDL_ShowOpenFileDialog (void; errors are
 * delivered through the callback). */
LEAN_EXPORT lean_obj_res lean_sdl_show_open_file_dialog(
        lean_obj_arg fn, b_lean_obj_arg win_opt,
        b_lean_obj_arg names, b_lean_obj_arg patterns,
        b_lean_obj_arg default_location, uint8_t allow_many, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_dialog_ctx *ctx = lean_sdl_dialog_ctx_new(fn, names, patterns);
    SDL_ShowOpenFileDialog(lean_sdl_dialog_tramp, ctx,
        lean_sdl_option_window(win_opt), ctx->filters, ctx->nfilters,
        lean_sdl_option_cstr(default_location), allow_many != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.showSaveFileDialogRaw -- C: SDL_ShowSaveFileDialog */
LEAN_EXPORT lean_obj_res lean_sdl_show_save_file_dialog(
        lean_obj_arg fn, b_lean_obj_arg win_opt,
        b_lean_obj_arg names, b_lean_obj_arg patterns,
        b_lean_obj_arg default_location, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_dialog_ctx *ctx = lean_sdl_dialog_ctx_new(fn, names, patterns);
    SDL_ShowSaveFileDialog(lean_sdl_dialog_tramp, ctx,
        lean_sdl_option_window(win_opt), ctx->filters, ctx->nfilters,
        lean_sdl_option_cstr(default_location));
    return lean_sdl_unit_ok();
}

/* Sdl.showOpenFolderDialogRaw -- C: SDL_ShowOpenFolderDialog */
LEAN_EXPORT lean_obj_res lean_sdl_show_open_folder_dialog(
        lean_obj_arg fn, b_lean_obj_arg win_opt,
        b_lean_obj_arg default_location, uint8_t allow_many, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_mark_mt(fn);
    lean_sdl_dialog_ctx *ctx = malloc(sizeof(lean_sdl_dialog_ctx));
    ctx->fn = fn;
    ctx->filters = NULL;
    ctx->nfilters = 0;
    SDL_ShowOpenFolderDialog(lean_sdl_dialog_tramp, ctx,
        lean_sdl_option_window(win_opt),
        lean_sdl_option_cstr(default_location), allow_many != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.showFileDialogWithPropertiesRaw -- C: SDL_ShowFileDialogWithProperties */
LEAN_EXPORT lean_obj_res lean_sdl_show_file_dialog_with_properties(
        uint32_t type, lean_obj_arg fn, b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(props);
    if (!h->ptr) {
        lean_dec(fn);
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    }
    lean_mark_mt(fn);
    lean_sdl_dialog_ctx *ctx = malloc(sizeof(lean_sdl_dialog_ctx));
    ctx->fn = fn;
    ctx->filters = NULL;
    ctx->nfilters = 0;
    SDL_ShowFileDialogWithProperties((SDL_FileDialogType)type,
        lean_sdl_dialog_tramp, ctx, (SDL_PropertiesID)(uintptr_t)h->ptr);
    return lean_sdl_unit_ok();
}
