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

/* ffi/pixels.c -- holder ptr is an SDL_Palette*, owner as usual. The borrowed
 * class backs palettes owned by another handle (e.g. a surface's palette). */
extern lean_external_class *lean_sdl_palette_class;
extern lean_external_class *lean_sdl_palette_borrowed_class;

/* ffi/iostream.c -- holder ptr is an SDL_IOStream*, owner as usual (the source
 * ByteArray for ioFromConstMem). Consumed by surface.c's *_IO loaders/savers. */
extern lean_external_class *lean_sdl_iostream_class;

/* ffi/surface.c -- holder ptr is an SDL_Surface*, owner as usual. The borrowed
 * class backs surfaces owned by another handle (e.g. a window's surface from
 * SDL_GetWindowSurface). */
extern lean_external_class *lean_sdl_surface_class;
extern lean_external_class *lean_sdl_surface_borrowed_class;

/* Wrap a borrowed SDL_Surface* whose lifetime is tied to `owner` (an owned
 * ref to the owning handle's external object, e.g. a window). The wrapped
 * surface is never destroyed by the finalizer. */
static inline lean_object *lean_sdl_wrap_surface_borrowed(
        SDL_Surface *surf, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_surface_borrowed_class, surf, owner);
}

/* ffi/video.c -- holder ptr is an SDL_Window*, owner is NULL for top-level
 * windows or an owned ref to the parent window's external for popup windows.
 * Windows are finalizer-only (no manual destroy). Each window created through
 * the binding stores its external object as a non-owning pointer property
 * (LEAN_SDL_WINDOW_PROP) on the window's properties, so SDL_Window* -> external
 * lookups (GetWindowFromID, GetGrabbedWindow, GetMouseFocus, ...) return the
 * same handle. */
extern lean_external_class *lean_sdl_window_class;

/* The non-owning property key storing a window's Lean external. */
#define LEAN_SDL_WINDOW_PROP "lean_sdl.window"

/* SDL_Window* -> Option Window: the same external the window was created with.
 * Foreign windows (not created via this binding) yield none. Sound because a
 * window's external and the SDL_Window are destroyed together (finalizer-only),
 * and SDL_DestroyWindow destroys the properties with the window. */
static inline lean_object *lean_sdl_window_option(SDL_Window *win) {
    if (!win) return lean_sdl_none();
    lean_object *ext = (lean_object *)SDL_GetPointerProperty(
        SDL_GetWindowProperties(win), LEAN_SDL_WINDOW_PROP, NULL);
    if (!ext) return lean_sdl_none();
    lean_inc(ext);
    return lean_sdl_some(ext);
}

#ifdef __cplusplus
}
#endif
