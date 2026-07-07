/* Shims for Sdl/Storage.lean (SDL_storage.h).
 *
 * One external class:
 *   - lean_sdl_storage : OWNED ROOT, owner NULL. Both Storage.close and the
 *     finalizer run SDL_CloseStorage. SDL frees the container EVEN when
 *     SDL_CloseStorage returns false ("the error is only for informational
 *     purposes"), so close NULLs the ptr unconditionally and then throws on a
 *     false result; the finalizer ignores the result.
 *
 * A Properties argument arrives as an Option Properties (box(0) = NULL/0, or a
 * ctor wrapping a Properties external whose holder ptr encodes an
 * SDL_PropertiesID as (void*)(uintptr_t)id — see ffi/properties.c). PathInfo is
 * built through the filesystem module's exported maker; enumeration and glob
 * mirror ffi/filesystem.c exactly (synchronous borrowed-closure trampoline;
 * single-allocation char** result). SDL_OpenStorage (custom interface) is
 * skipped. */
#include "util.h"
#include "callbacks.h"

/* Lean-owned maker (see Sdl/Filesystem.lean; reused here). Signature confirmed
 * against ffi/filesystem.c / .lake/build/ir/Sdl/Filesystem.c. */
extern lean_object *lean_sdl_mk_path_info(
    uint32_t type, uint64_t size, int64_t create_ns, int64_t modify_ns, int64_t access_ns);

/* Owned root: finalizer closes the storage (bool result ignored). */
SDL_DEFINE_CLASS(lean_sdl_storage, SDL_CloseStorage((SDL_Storage *)self))

/* Register the class. Called from Sdl/Storage.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_storage_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_storage_class_init();
    return lean_sdl_unit_ok();
}

/* Extract an SDL_PropertiesID from an owned `Option Properties` (0 for none).
 * `*out_err` is set to a thrown result if the wrapped handle was destroyed. */
static bool lean_sdl_props_of_opt(lean_obj_arg props_opt, SDL_PropertiesID *id,
                                  lean_obj_res *out_err) {
    *id = 0;
    *out_err = NULL;
    if (!lean_is_scalar(props_opt)) {
        lean_object *p = lean_ctor_get(props_opt, 0);
        sdl_holder *h = lean_sdl_holder_of(p);
        if (!h->ptr) {
            *out_err = lean_sdl_throw_msg("SDL: handle used after destroy/release");
            return false;
        }
        *id = (SDL_PropertiesID)(uintptr_t)h->ptr;
    }
    return true;
}

/* ==================== Opening ==================== */

/* Sdl.Storage.openTitleRaw (override : Option String) (props : Option Properties)
 * : IO Storage -- C: SDL_OpenTitleStorage (NULL override -> default root). */
LEAN_EXPORT lean_obj_res lean_sdl_open_title_storage(
        lean_obj_arg override_opt, lean_obj_arg props_opt, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PropertiesID pid;
    lean_obj_res err;
    if (!lean_sdl_props_of_opt(props_opt, &pid, &err)) {
        lean_dec(override_opt);
        lean_dec(props_opt);
        return err;
    }
    const char *ov = NULL;
    if (!lean_is_scalar(override_opt))
        ov = lean_string_cstr(lean_ctor_get(override_opt, 0));
    SDL_Storage *st = SDL_OpenTitleStorage(ov, pid);
    lean_dec(override_opt);
    lean_dec(props_opt);
    if (!st) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_storage_class, st, NULL));
}

/* Sdl.Storage.openUserRaw (org app : @& String) (props : Option Properties)
 * : IO Storage -- C: SDL_OpenUserStorage. */
LEAN_EXPORT lean_obj_res lean_sdl_open_user_storage(
        b_lean_obj_arg org, b_lean_obj_arg app, lean_obj_arg props_opt, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PropertiesID pid;
    lean_obj_res err;
    if (!lean_sdl_props_of_opt(props_opt, &pid, &err)) {
        lean_dec(props_opt);
        return err;
    }
    SDL_Storage *st = SDL_OpenUserStorage(lean_string_cstr(org), lean_string_cstr(app), pid);
    lean_dec(props_opt);
    if (!st) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_storage_class, st, NULL));
}

/* Sdl.Storage.openFile (path : @& String) : IO Storage
 * -- C: SDL_OpenFileStorage (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_file_storage(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Storage *st = SDL_OpenFileStorage(lean_string_cstr(path));
    if (!st) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_storage_class, st, NULL));
}

/* ==================== Methods ==================== */

/* Sdl.Storage.close : IO Unit -- C: SDL_CloseStorage. SDL frees the container
 * even on a false result, so the ptr is NULLed unconditionally (else the
 * finalizer would double-close); a false result still throws (informational,
 * e.g. files still in flight). */
LEAN_EXPORT lean_obj_res lean_sdl_close_storage(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_Storage *st = (SDL_Storage *)h->ptr;
    h->ptr = NULL;
    if (!SDL_CloseStorage(st)) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.Storage.ready : IO Bool -- C: SDL_StorageReady (no error state). */
LEAN_EXPORT lean_obj_res lean_sdl_storage_ready(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    return lean_io_result_mk_ok(lean_box(SDL_StorageReady(st) ? 1 : 0));
}

/* Sdl.Storage.getFileSize (path : @& String) : IO UInt64
 * -- C: SDL_GetStorageFileSize (false -> throw; escapes rejected). */
LEAN_EXPORT lean_obj_res lean_sdl_get_storage_file_size(
        b_lean_obj_arg self, b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    Uint64 len = 0;
    if (!SDL_GetStorageFileSize(st, lean_string_cstr(path), &len)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)len));
}

/* Sdl.Storage.readFile (path : @& String) : IO ByteArray -- C:
 * SDL_ReadStorageFile. Size the buffer from SDL_GetStorageFileSize, read
 * straight into the sarray's data pointer (no double copy). */
LEAN_EXPORT lean_obj_res lean_sdl_read_storage_file(
        b_lean_obj_arg self, b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    const char *p = lean_string_cstr(path);
    Uint64 len = 0;
    if (!SDL_GetStorageFileSize(st, p, &len)) return lean_sdl_throw();
    size_t n = (size_t)len;
    lean_object *arr = lean_alloc_sarray(1, n, n);
    if (!SDL_ReadStorageFile(st, p, lean_sarray_cptr(arr), len)) {
        lean_dec(arr);
        return lean_sdl_throw();
    }
    return lean_io_result_mk_ok(arr);
}

/* Sdl.Storage.writeFile (path : @& String) (data : @& ByteArray) : IO Unit
 * -- C: SDL_WriteStorageFile. */
LEAN_EXPORT lean_obj_res lean_sdl_write_storage_file(
        b_lean_obj_arg self, b_lean_obj_arg path, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    size_t n = lean_sarray_size(data);
    SDL_BOOL_TO_IO(SDL_WriteStorageFile(st, lean_string_cstr(path),
                                        lean_sarray_cptr((lean_object *)data), (Uint64)n));
}

/* Sdl.Storage.createDirectory (path : @& String) : IO Unit
 * -- C: SDL_CreateStorageDirectory. */
LEAN_EXPORT lean_obj_res lean_sdl_create_storage_directory(
        b_lean_obj_arg self, b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    SDL_BOOL_TO_IO(SDL_CreateStorageDirectory(st, lean_string_cstr(path)));
}

/* Sdl.Storage.removePath (path : @& String) : IO Unit -- C: SDL_RemoveStoragePath. */
LEAN_EXPORT lean_obj_res lean_sdl_remove_storage_path(
        b_lean_obj_arg self, b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    SDL_BOOL_TO_IO(SDL_RemoveStoragePath(st, lean_string_cstr(path)));
}

/* Sdl.Storage.renamePath (oldpath newpath : @& String) : IO Unit
 * -- C: SDL_RenameStoragePath. */
LEAN_EXPORT lean_obj_res lean_sdl_rename_storage_path(
        b_lean_obj_arg self, b_lean_obj_arg oldpath, b_lean_obj_arg newpath, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    SDL_BOOL_TO_IO(SDL_RenameStoragePath(st, lean_string_cstr(oldpath),
                                         lean_string_cstr(newpath)));
}

/* Sdl.Storage.copyFile (oldpath newpath : @& String) : IO Unit
 * -- C: SDL_CopyStorageFile. */
LEAN_EXPORT lean_obj_res lean_sdl_copy_storage_file(
        b_lean_obj_arg self, b_lean_obj_arg oldpath, b_lean_obj_arg newpath, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    SDL_BOOL_TO_IO(SDL_CopyStorageFile(st, lean_string_cstr(oldpath),
                                       lean_string_cstr(newpath)));
}

/* Sdl.Storage.getPathInfo (path : @& String) : IO PathInfo
 * -- C: SDL_GetStoragePathInfo (false -> throw, e.g. missing file). */
LEAN_EXPORT lean_obj_res lean_sdl_get_storage_path_info(
        b_lean_obj_arg self, b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    SDL_PathInfo info;
    if (!SDL_GetStoragePathInfo(st, lean_string_cstr(path), &info)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_path_info(
        (uint32_t)info.type, (uint64_t)info.size,
        (int64_t)info.create_time, (int64_t)info.modify_time, (int64_t)info.access_time));
}

/* Sdl.Storage.spaceRemaining : IO UInt64
 * -- C: SDL_GetStorageSpaceRemaining (no error state). */
LEAN_EXPORT lean_obj_res lean_sdl_get_storage_space_remaining(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Storage, st, self);
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)SDL_GetStorageSpaceRemaining(st)));
}

/* Sdl.Storage.globDirectoryRaw (path : Option String) (pattern : Option String)
 * (flags) : IO (Array String) -- C: SDL_GlobStorageDirectory. NULL path = root;
 * single NULL-terminated allocation copied into an Array String then SDL_freed. */
LEAN_EXPORT lean_obj_res lean_sdl_glob_storage_directory(
        b_lean_obj_arg self, lean_obj_arg path_opt, lean_obj_arg pattern_opt,
        uint32_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *sh = lean_sdl_holder_of(self);
    if (!sh->ptr) {
        lean_dec(path_opt);
        lean_dec(pattern_opt);
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    }
    lean_object *pathp = lean_sdl_option_take(path_opt);
    lean_object *pat = lean_sdl_option_take(pattern_opt);
    int count = 0;
    char **res = SDL_GlobStorageDirectory((SDL_Storage *)sh->ptr,
                                          pathp ? lean_string_cstr(pathp) : NULL,
                                          pat ? lean_string_cstr(pat) : NULL,
                                          (SDL_GlobFlags)flags, &count);
    if (pathp) lean_dec(pathp);
    if (pat) lean_dec(pat);
    if (!res) return lean_sdl_throw();
    lean_object *arr = lean_sdl_string_array((char const *const *)res);
    SDL_free(res);
    return lean_io_result_mk_ok(arr);
}

/* ---- Directory enumeration (synchronous borrowed-closure callback; mirrors
 * ffi/filesystem.c). Closure: String -> String -> IO UInt32
 * (dirname, fname, EnumerationResult.val). A Lean exception maps to
 * SDL_ENUM_FAILURE, aborting the walk and surfacing as an IO error. */
static SDL_EnumerationResult SDLCALL lean_sdl_storage_enum_tramp(
        void *userdata, const char *dirname, const char *fname) {
    lean_object *fn = (lean_object *)userdata;
    lean_inc(fn);
    lean_object *res = lean_apply_3(fn, lean_sdl_mk_string(dirname),
                                    lean_sdl_mk_string(fname), lean_box(0));
    if (!lean_io_result_is_ok(res))
        SDL_SetError("Lean directory-enumeration callback raised an exception");
    return (SDL_EnumerationResult)lean_sdl_io_u32_or(res, (uint32_t)SDL_ENUM_FAILURE);
}

/* Sdl.Storage.enumerateDirectoryRaw (path : @& String) (cb) : IO Unit
 * -- C: SDL_EnumerateStorageDirectory. */
LEAN_EXPORT lean_obj_res lean_sdl_enumerate_storage_directory(
        b_lean_obj_arg self, b_lean_obj_arg path, lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *sh = lean_sdl_holder_of(self);
    if (!sh->ptr) {
        lean_dec(fn);
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    }
    bool ok = SDL_EnumerateStorageDirectory((SDL_Storage *)sh->ptr,
                                             lean_string_cstr(path),
                                             lean_sdl_storage_enum_tramp, fn);
    lean_dec(fn);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}
