/* Shims for Sdl/Properties.lean (SDL_properties.h).
 *
 * A Properties handle wraps an SDL_PropertiesID (a nonzero Uint32) stored as
 * `(void *)(uintptr_t)id` in the holder's `ptr` (owner is always NULL here).
 * Two external classes over the same Lean type:
 *   - lean_sdl_properties          : owned  (SDL_CreateProperties)  -> destroy
 *   - lean_sdl_properties_borrowed : borrowed (SDL_GetGlobalProperties) -> no destroy
 */
#include "util.h"

/* Owned: destroy on finalize. `self` is the holder's void* ptr. */
SDL_DEFINE_CLASS(lean_sdl_properties,
    SDL_DestroyProperties((SDL_PropertiesID)(uintptr_t)self))
/* Borrowed (global properties): never destroyed. */
SDL_DEFINE_BORROWED_CLASS(lean_sdl_properties_borrowed)

/* Register both classes. Called from Sdl/Properties.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_properties_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_properties_class_init();
    lean_sdl_properties_borrowed_class_init();
    return lean_sdl_unit_ok();
}

/* SDL_GET_OR_THROW stores a T* in ptr; a Properties handle instead encodes a
 * SDL_PropertiesID as (void *)(uintptr_t)id. Load it (throwing if the handle
 * was destroyed/released, i.e. ptr == NULL) into a fresh SDL_PropertiesID. */
#define SDL_PROPS_OR_THROW(id, obj)                                            \
    SDL_PropertiesID id;                                                       \
    do {                                                                       \
        sdl_holder *_h = lean_sdl_holder_of(obj);                             \
        if (!_h->ptr)                                                          \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
        id = (SDL_PropertiesID)(uintptr_t)_h->ptr;                            \
    } while (0)

/* Sdl.getGlobalProperties : IO Properties -- C: SDL_GetGlobalProperties */
LEAN_EXPORT lean_obj_res lean_sdl_get_global_properties(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PropertiesID id = SDL_GetGlobalProperties();
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_properties_borrowed_class, (void *)(uintptr_t)id, NULL));
}

/* Sdl.createProperties : IO Properties -- C: SDL_CreateProperties */
LEAN_EXPORT lean_obj_res lean_sdl_create_properties(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PropertiesID id = SDL_CreateProperties();
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_properties_class, (void *)(uintptr_t)id, NULL));
}

/* Sdl.Properties.copyProperties -- C: SDL_CopyProperties */
LEAN_EXPORT lean_obj_res lean_sdl_copy_properties(
        b_lean_obj_arg src, b_lean_obj_arg dst, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(s, src);
    SDL_PROPS_OR_THROW(d, dst);
    SDL_BOOL_TO_IO(SDL_CopyProperties(s, d));
}

/* Sdl.Properties.lockProperties -- C: SDL_LockProperties */
LEAN_EXPORT lean_obj_res lean_sdl_lock_properties(b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_BOOL_TO_IO(SDL_LockProperties(id));
}

/* Sdl.Properties.unlockProperties -- C: SDL_UnlockProperties */
LEAN_EXPORT lean_obj_res lean_sdl_unlock_properties(b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_UnlockProperties(id);
    return lean_sdl_unit_ok();
}

/* Sdl.Properties.setStringProperty -- C: SDL_SetStringProperty */
LEAN_EXPORT lean_obj_res lean_sdl_set_string_property(
        b_lean_obj_arg props, b_lean_obj_arg name, b_lean_obj_arg value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_BOOL_TO_IO(SDL_SetStringProperty(id, lean_string_cstr(name), lean_string_cstr(value)));
}

/* Sdl.Properties.setNumberProperty -- C: SDL_SetNumberProperty */
LEAN_EXPORT lean_obj_res lean_sdl_set_number_property(
        b_lean_obj_arg props, b_lean_obj_arg name, int64_t value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_BOOL_TO_IO(SDL_SetNumberProperty(id, lean_string_cstr(name), (Sint64)value));
}

/* Sdl.Properties.setFloatProperty -- C: SDL_SetFloatProperty */
LEAN_EXPORT lean_obj_res lean_sdl_set_float_property(
        b_lean_obj_arg props, b_lean_obj_arg name, float value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_BOOL_TO_IO(SDL_SetFloatProperty(id, lean_string_cstr(name), value));
}

/* Sdl.Properties.setBooleanProperty -- C: SDL_SetBooleanProperty */
LEAN_EXPORT lean_obj_res lean_sdl_set_boolean_property(
        b_lean_obj_arg props, b_lean_obj_arg name, uint8_t value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_BOOL_TO_IO(SDL_SetBooleanProperty(id, lean_string_cstr(name), value != 0));
}

/* Sdl.Properties.hasProperty -- C: SDL_HasProperty */
LEAN_EXPORT lean_obj_res lean_sdl_has_property(
        b_lean_obj_arg props, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    return lean_io_result_mk_ok(lean_box(SDL_HasProperty(id, lean_string_cstr(name))));
}

/* Sdl.Properties.getPropertyTypeRaw -- C: SDL_GetPropertyType */
LEAN_EXPORT lean_obj_res lean_sdl_get_property_type(
        b_lean_obj_arg props, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetPropertyType(id, lean_string_cstr(name))));
}

/* Sdl.Properties.getStringProperty -- C: SDL_GetStringProperty.
 * The returned pointer may be invalidated by a later call (unless locked), so
 * copy it into a Lean string immediately. */
LEAN_EXPORT lean_obj_res lean_sdl_get_string_property(
        b_lean_obj_arg props, b_lean_obj_arg name, b_lean_obj_arg default_value,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    const char *s = SDL_GetStringProperty(id, lean_string_cstr(name),
                                          lean_string_cstr(default_value));
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.Properties.getNumberProperty -- C: SDL_GetNumberProperty */
LEAN_EXPORT lean_obj_res lean_sdl_get_number_property(
        b_lean_obj_arg props, b_lean_obj_arg name, int64_t default_value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    Sint64 v = SDL_GetNumberProperty(id, lean_string_cstr(name), (Sint64)default_value);
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)v));
}

/* Sdl.Properties.getFloatProperty -- C: SDL_GetFloatProperty */
LEAN_EXPORT lean_obj_res lean_sdl_get_float_property(
        b_lean_obj_arg props, b_lean_obj_arg name, float default_value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    return lean_io_result_mk_ok(
        lean_box_float32(SDL_GetFloatProperty(id, lean_string_cstr(name), default_value)));
}

/* Sdl.Properties.getBooleanProperty -- C: SDL_GetBooleanProperty */
LEAN_EXPORT lean_obj_res lean_sdl_get_boolean_property(
        b_lean_obj_arg props, b_lean_obj_arg name, uint8_t default_value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    return lean_io_result_mk_ok(
        lean_box(SDL_GetBooleanProperty(id, lean_string_cstr(name), default_value != 0)));
}

/* Sdl.Properties.clearProperty -- C: SDL_ClearProperty */
LEAN_EXPORT lean_obj_res lean_sdl_clear_property(
        b_lean_obj_arg props, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PROPS_OR_THROW(id, props);
    SDL_BOOL_TO_IO(SDL_ClearProperty(id, lean_string_cstr(name)));
}

/* Sdl.Properties.destroy -- C: SDL_DestroyProperties (manual; leaf type).
 * Throws on the borrowed global-properties class; otherwise destroys and
 * NULLs the ptr so later use is an IO error. */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_properties(b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(props);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    if (lean_get_external_class(props) == lean_sdl_properties_borrowed_class)
        return lean_sdl_throw_msg("SDL: cannot destroy borrowed Properties");
    SDL_DestroyProperties((SDL_PropertiesID)(uintptr_t)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}
