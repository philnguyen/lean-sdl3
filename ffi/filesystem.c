/* Shims for Sdl/Filesystem.lean (SDL_filesystem.h). */
#include "util.h"
#include "callbacks.h"

/* Lean-owned maker (see Sdl/Filesystem.lean). */
extern lean_object *lean_sdl_mk_path_info(
    uint32_t type, uint64_t size, int64_t create_ns, int64_t modify_ns, int64_t access_ns);

/* Sdl.getBasePath : IO String -- C: SDL_GetBasePath (SDL-owned static; copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_base_path(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *p = SDL_GetBasePath();
    if (!p) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(p));
}

/* Sdl.getPrefPathRaw (org app : @& String) : IO String -- C: SDL_GetPrefPath.
 * Result is caller-owned: copy into a Lean string then SDL_free. */
LEAN_EXPORT lean_obj_res lean_sdl_get_pref_path(
        b_lean_obj_arg org, b_lean_obj_arg app, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *p = SDL_GetPrefPath(lean_string_cstr(org), lean_string_cstr(app));
    if (!p) return lean_sdl_throw();
    lean_object *s = lean_mk_string(p);
    SDL_free(p);
    return lean_io_result_mk_ok(s);
}

/* Sdl.getUserFolderRaw (folder : UInt32) : IO String -- C: SDL_GetUserFolder.
 * Result is SDL-owned; copy it. */
LEAN_EXPORT lean_obj_res lean_sdl_get_user_folder(uint32_t folder, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *p = SDL_GetUserFolder((SDL_Folder)folder);
    if (!p) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(p));
}

/* Sdl.createDirectory (path : @& String) : IO Unit -- C: SDL_CreateDirectory */
LEAN_EXPORT lean_obj_res lean_sdl_create_directory(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_CreateDirectory(lean_string_cstr(path)));
}

/* Sdl.removePath (path : @& String) : IO Unit -- C: SDL_RemovePath */
LEAN_EXPORT lean_obj_res lean_sdl_remove_path(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_RemovePath(lean_string_cstr(path)));
}

/* Sdl.renamePath (oldpath newpath : @& String) : IO Unit -- C: SDL_RenamePath */
LEAN_EXPORT lean_obj_res lean_sdl_rename_path(
        b_lean_obj_arg oldpath, b_lean_obj_arg newpath, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_RenamePath(lean_string_cstr(oldpath), lean_string_cstr(newpath)));
}

/* Sdl.copyFile (oldpath newpath : @& String) : IO Unit -- C: SDL_CopyFile */
LEAN_EXPORT lean_obj_res lean_sdl_copy_file(
        b_lean_obj_arg oldpath, b_lean_obj_arg newpath, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_CopyFile(lean_string_cstr(oldpath), lean_string_cstr(newpath)));
}

/* Sdl.getPathInfo (path : @& String) : IO PathInfo -- C: SDL_GetPathInfo.
 * false means the path doesn't exist (or another failure): throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_path_info(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PathInfo info;
    if (!SDL_GetPathInfo(lean_string_cstr(path), &info)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_path_info(
        (uint32_t)info.type, (uint64_t)info.size,
        (int64_t)info.create_time, (int64_t)info.modify_time, (int64_t)info.access_time));
}

/* Sdl.globDirectoryRaw (path) (pattern : Option String) (flags) : IO (Array String)
 * -- C: SDL_GlobDirectory. `pattern_opt` is an owned Option String (none = no
 * filter). The result is a single NULL-terminated allocation: copy into an
 * Array String, then SDL_free once. */
LEAN_EXPORT lean_obj_res lean_sdl_glob_directory(
        b_lean_obj_arg path, lean_obj_arg pattern_opt, uint32_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_object *pat = lean_sdl_option_take(pattern_opt);
    int count = 0;
    char **res = SDL_GlobDirectory(lean_string_cstr(path),
                                   pat ? lean_string_cstr(pat) : NULL,
                                   (SDL_GlobFlags)flags, &count);
    if (pat) lean_dec(pat);
    if (!res) return lean_sdl_throw();
    lean_object *arr = lean_sdl_string_array((char const *const *)res);
    SDL_free(res);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.getCurrentDirectory : IO String -- C: SDL_GetCurrentDirectory.
 * Result is caller-owned: copy then SDL_free. */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_directory(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *p = SDL_GetCurrentDirectory();
    if (!p) return lean_sdl_throw();
    lean_object *s = lean_mk_string(p);
    SDL_free(p);
    return lean_io_result_mk_ok(s);
}

/* ---- Directory enumeration (synchronous borrowed-closure callback;
 * docs/DESIGN.md "Callbacks", synchronous case). */

/* Closure: String -> String -> IO UInt32 (dirname, fname,
 * EnumerationResult.val). A Lean exception maps to SDL_ENUM_FAILURE, which
 * aborts the walk and surfaces as an IO error from the shim. */
static SDL_EnumerationResult SDLCALL lean_sdl_enum_dir_tramp(
        void *userdata, const char *dirname, const char *fname) {
    lean_object *fn = (lean_object *)userdata;
    lean_inc(fn); /* keep the borrow alive across the consuming apply */
    lean_object *res = lean_apply_3(fn, lean_sdl_mk_string(dirname),
                                    lean_sdl_mk_string(fname), lean_box(0));
    if (!lean_io_result_is_ok(res))
        SDL_SetError("Lean directory-enumeration callback raised an exception");
    return (SDL_EnumerationResult)lean_sdl_io_u32_or(res, (uint32_t)SDL_ENUM_FAILURE);
}

/* Sdl.enumerateDirectoryRaw -- C: SDL_EnumerateDirectory */
LEAN_EXPORT lean_obj_res lean_sdl_enumerate_directory(
        b_lean_obj_arg path, lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    bool ok = SDL_EnumerateDirectory(lean_string_cstr(path),
                                     lean_sdl_enum_dir_tramp, fn);
    lean_dec(fn);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}
