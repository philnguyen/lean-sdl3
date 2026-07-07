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
 * ByteArray for ioFromConstMem). Consumed by surface.c's *_IO loaders/savers.
 * The borrowed class backs streams owned by another handle (e.g. a process's
 * stdin/stdout from SDL_GetProcessInput/Output): the finalizer never closes the
 * stream, only decs the owner, and IOStream.close throws on it. Every other
 * IOStream read/write/status/seek shim works on it unchanged (they deref the
 * holder ptr generically). */
extern lean_external_class *lean_sdl_iostream_class;
extern lean_external_class *lean_sdl_iostream_borrowed_class;

/* Wrap a borrowed SDL_IOStream* whose lifetime is tied to `owner` (an owned
 * ref to the owning handle's external object, e.g. a process). Never closed by
 * the finalizer. */
static inline lean_object *lean_sdl_wrap_iostream_borrowed(
        SDL_IOStream *io, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_iostream_borrowed_class, io, owner);
}

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

/* ffi/render.c -- holder ptr is an SDL_Renderer*, owner is an owned ref to the
 * creating Window's external (or the Surface's external for the software
 * renderer). Renderers are finalizer-only (no manual destroy). Each renderer
 * created through the binding stores its external object as a non-owning
 * pointer property (LEAN_SDL_RENDERER_PROP) on the renderer's properties, so
 * SDL_Renderer* -> external lookups (GetRenderer) return the same handle. */
extern lean_external_class *lean_sdl_renderer_class;

/* ffi/render.c -- holder ptr is an SDL_Texture*, owner is an owned ref to the
 * creating Renderer's external. Textures are owned leaves (manual
 * Texture.destroy exposed). Each texture created through the binding stores its
 * external object as a non-owning pointer property (LEAN_SDL_TEXTURE_PROP) on
 * the texture's properties, so SDL_Texture* -> external lookups
 * (GetRenderTarget) return the same handle. */
extern lean_external_class *lean_sdl_texture_class;

/* Non-owning property keys storing a renderer's / texture's Lean external. */
#define LEAN_SDL_RENDERER_PROP "lean_sdl.renderer"
#define LEAN_SDL_TEXTURE_PROP  "lean_sdl.texture"

/* SDL_Renderer* -> Option Renderer: the same external the renderer was created
 * with. Foreign renderers (not created via this binding) yield none. Sound for
 * the same reason as windows: the external and the SDL_Renderer are destroyed
 * together (finalizer-only), and SDL_DestroyRenderer destroys the properties
 * with the renderer. */
static inline lean_object *lean_sdl_renderer_option(SDL_Renderer *r) {
    if (!r) return lean_sdl_none();
    lean_object *ext = (lean_object *)SDL_GetPointerProperty(
        SDL_GetRendererProperties(r), LEAN_SDL_RENDERER_PROP, NULL);
    if (!ext) return lean_sdl_none();
    lean_inc(ext);
    return lean_sdl_some(ext);
}

/* SDL_Texture* -> Option Texture: the same external the texture was created
 * with. Foreign textures yield none. Sound because the property dies inside
 * SDL_DestroyTexture (whether via the finalizer or a manual Texture.destroy),
 * and a live external always has a live SDL_Texture (destroy NULLs the ptr and
 * the guard rejects use). */
static inline lean_object *lean_sdl_texture_option(SDL_Texture *t) {
    if (!t) return lean_sdl_none();
    lean_object *ext = (lean_object *)SDL_GetPointerProperty(
        SDL_GetTextureProperties(t), LEAN_SDL_TEXTURE_PROP, NULL);
    if (!ext) return lean_sdl_none();
    lean_inc(ext);
    return lean_sdl_some(ext);
}

/* ffi/joystick.c -- holder ptr is an SDL_Joystick*, owner always NULL.
 * Joysticks are internally refcounted by SDL: every handle the binding hands
 * out took its own SDL_OpenJoystick reference, so finalizer/close are always
 * balanced and independent handles never alias each other's lifetime. */
extern lean_external_class *lean_sdl_joystick_class;

/* ffi/camera.c -- holder ptr is an SDL_Surface* (a camera frame), owner is an
 * owned ref to the frame's Camera external. RELEASE-TO-SOURCE archetype: the
 * finalizer returns the frame to its camera via
 * SDL_ReleaseCameraFrame(owner->ptr, ptr) rather than destroying the surface;
 * RC ordering (the frame owns a camera ref) keeps the camera alive until every
 * frame is released. The produced Lean values are plain `Surface`s, usable by
 * every Surface shim (which read the holder ptr generically). The Camera itself
 * (lean_sdl_camera_class) is finalizer-only and stays module-local. Declared
 * here because Camera.releaseFrame must class-check a frame it receives typed as
 * a Surface. */
extern lean_external_class *lean_sdl_camera_frame_class;

/* ffi/gpu.c -- SDL3 GPU core external classes. All resource children hold an
 * owned ref to the device external ({ptr, deviceExt}); the finalizer reads the
 * device pointer from the owner holder. Exported here for ffi/gpu_pipeline.c
 * (shaders/pipelines/render+compute passes), which wraps textures/buffers/
 * samplers of these types and reads the device from a command buffer's owner. */
extern lean_external_class *lean_sdl_gpu_device_class;
extern lean_external_class *lean_sdl_gpu_buffer_class;
extern lean_external_class *lean_sdl_gpu_texture_class;
/* Borrowed swapchain-texture class: {ptr, cmdBufExt}; finalize decs owner only;
 * release/setName throw on it. Same Lean `Gpu.Texture` type, distinct class. */
extern lean_external_class *lean_sdl_gpu_texture_borrowed_class;
extern lean_external_class *lean_sdl_gpu_sampler_class;
/* Consumable command buffer: {ptr, deviceExt}; finalize decs owner only. */
extern lean_external_class *lean_sdl_gpu_cmdbuf_class;

/* Wrap a freshly-created owned GPU child; `owner` is consumed (an inc'd device
 * external). Read the device pointer from the owner holder in the finalizer. */
static inline lean_object *lean_sdl_wrap_gpu_buffer(SDL_GPUBuffer *b, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_gpu_buffer_class, b, owner);
}
static inline lean_object *lean_sdl_wrap_gpu_texture(SDL_GPUTexture *t, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_gpu_texture_class, t, owner);
}
static inline lean_object *lean_sdl_wrap_gpu_sampler(SDL_GPUSampler *s, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_gpu_sampler_class, s, owner);
}

/* Wrap a borrowed swapchain texture whose lifetime is tied to `owner` (an
 * inc'd command-buffer external). Never released by the finalizer. */
static inline lean_object *lean_sdl_wrap_gpu_texture_borrowed(
        SDL_GPUTexture *t, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_gpu_texture_borrowed_class, t, owner);
}

/* ffi/ttf.c -- holder ptr is a TTF_Font*, owner is NULL for file-opened fonts,
 * an inc'd IOStream external for openFontIO (keeps a const-mem stream and its
 * backing ByteArray alive), or an inc'd source Font external for copyFont (the
 * copy shares the original's font data source). Fonts are finalizer-only
 * (TTF_CloseFont; no manual close -- Texts and fallback configs reference fonts,
 * same rationale as Window/Renderer). Exported for ffi/ttf_text.c (agent B),
 * which class-checks Font arguments. TTF_Font is forward-declared so this header
 * need not pull in SDL_ttf.h. */
typedef struct TTF_Font TTF_Font;
extern lean_external_class *lean_sdl_ttf_font_class;

/* Wrap a freshly-opened owned TTF_Font*; `owner` is consumed (NULL, an inc'd
 * IOStream external, or an inc'd source Font external). */
static inline lean_object *lean_sdl_wrap_ttf_font(TTF_Font *f, lean_object *owner) {
    return lean_sdl_wrap(lean_sdl_ttf_font_class, f, owner);
}

#ifdef __cplusplus
}
#endif
