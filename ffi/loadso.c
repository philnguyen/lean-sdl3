/* Shims for Sdl/LoadSo.lean (SDL_loadso.h).
 *
 * One module-local external class:
 *   - lean_sdl_shared_object : OWNED ROOT. Finalizer (and the manual
 *     SharedObject.unload) run SDL_UnloadObject; holder owner is always NULL.
 *
 * Partial binding: SDL_LoadFunction is exposed only as an existence check
 * (hasFunction) because a raw C function pointer cannot be called from Lean. */
#include "util.h"

/* Owned root: finalizer unloads the object. */
SDL_DEFINE_CLASS(lean_sdl_shared_object, SDL_UnloadObject((SDL_SharedObject *)self))

/* Register the class. Called from Sdl/LoadSo.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_loadso_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_shared_object_class_init();
    return lean_sdl_unit_ok();
}

/* Sdl.loadObject (sofile : @& String) : IO SharedObject -- C: SDL_LoadObject
 * (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_load_object(b_lean_obj_arg sofile, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SharedObject *so = SDL_LoadObject(lean_string_cstr(sofile));
    if (!so) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_shared_object_class, so, NULL));
}

/* Sdl.SharedObject.hasFunction (name : @& String) : IO Bool
 * -- C: SDL_LoadFunction (non-NULL -> true; NULL -> false, NOT a throw). */
LEAN_EXPORT lean_obj_res lean_sdl_has_function(
        b_lean_obj_arg self, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_SharedObject, so, self);
    SDL_FunctionPointer fn = SDL_LoadFunction(so, lean_string_cstr(name));
    return lean_io_result_mk_ok(lean_box(fn != NULL));
}

/* Sdl.SharedObject.unload : IO Unit -- C: SDL_UnloadObject. Manual destroy:
 * NULL the ptr so the finalizer skips and later use throws. */
LEAN_EXPORT lean_obj_res lean_sdl_unload_object(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_UnloadObject((SDL_SharedObject *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}
