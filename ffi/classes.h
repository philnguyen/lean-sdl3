/* Cross-module external-class sharing.
 *
 * SDL_DEFINE_CLASS / SDL_DEFINE_BORROWED_CLASS (ffi/util.h) define the class
 * pointer as a non-static global in the module that owns the type. A module
 * that hands out a handle of another module's type (e.g. surface.c wrapping
 * a borrowed Properties from SDL_GetSurfaceProperties) includes this header
 * instead of forward-declaring locally. Add an extern block here whenever a
 * class gains a cross-module consumer. */
#pragma once
#include "util.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ffi/properties.c -- holder ptr encodes an SDL_PropertiesID, owner as usual. */
extern lean_external_class *lean_sdl_properties_class;
extern lean_external_class *lean_sdl_properties_borrowed_class;

/* Wrap a borrowed SDL_PropertiesID whose lifetime is tied to `owner` (an
 * owned ref to the owning handle's external object, or NULL for
 * process-global properties). */
static inline lean_object *lean_sdl_wrap_properties_borrowed(
        SDL_PropertiesID id, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_properties_borrowed_class,
                         (void *)(uintptr_t)id, owner);
}

#ifdef __cplusplus
}
#endif
