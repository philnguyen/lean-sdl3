/* Shims for Sdl/Camera.lean (SDL_camera.h).
 *
 * Two external classes:
 *   - lean_sdl_camera        : OWNED ROOT, finalizer-only. Finalizer runs
 *     SDL_CloseCamera; holder owner is always NULL. There is NO manual close:
 *     frames hold an owned ref to the camera, and RC ordering guarantees every
 *     frame is released before the camera closes. SDL_Camera is not internally
 *     refcounted, so there is no "re-open by id".
 *   - lean_sdl_camera_frame  : RELEASE-TO-SOURCE (see classes.h). The holder ptr
 *     is an SDL_Surface* owned by the camera; the holder owner is the Camera
 *     external (inc'd at acquire time). The finalizer returns the frame to its
 *     camera via SDL_ReleaseCameraFrame(owner->ptr, ptr) rather than destroying
 *     it. The produced Lean values are plain `Surface`s usable by every Surface
 *     shim (they read the holder ptr generically). Camera.releaseFrame is a
 *     manual release that NULLs the ptr, so later Surface ops throw.
 *
 * CameraID is a plain Uint32 on the Lean side (sdl_id); its shims take the raw
 * id. CameraSpec crosses the boundary through the @[export]ed maker
 * lean_sdl_mk_camera_spec (flattened scalars; C never lays out the Lean
 * struct). CameraPosition crosses as its raw Uint32 (decoded by the total
 * CameraPosition.ofVal?); CameraPermissionState crosses as its raw int (-1/0/1)
 * boxed as Int32 and decoded by CameraPermissionState.ofInt?. */
#include "util.h"
#include "classes.h"

/* Lean-owned makers (the Lean compiler owns constructor layout). */
extern lean_object *lean_sdl_mk_camera_spec(uint32_t format, uint32_t colorspace,
    int32_t width, int32_t height, int32_t num, int32_t den);
extern lean_object *lean_sdl_mk_surface_timestamp(lean_object *s, uint64_t ts);

/* Owned root: finalizer closes the camera. */
SDL_DEFINE_CLASS(lean_sdl_camera, SDL_CloseCamera((SDL_Camera *)self))

/* Release-to-source: finalizer hands the frame back to its owning camera. The
 * owner (a Camera external) is guaranteed live by RC ordering, so its holder
 * ptr is non-NULL here (the camera has no manual close). */
SDL_DEFINE_CLASS(lean_sdl_camera_frame,
    SDL_ReleaseCameraFrame((SDL_Camera *)lean_sdl_holder_of(h->owner)->ptr,
                           (SDL_Surface *)self))

/* Register both classes. Called from Sdl/Camera.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_camera_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_camera_class_init();
    lean_sdl_camera_frame_class_init();
    return lean_sdl_unit_ok();
}

/* Build a CameraSpec Lean value from an SDL_CameraSpec. */
static lean_object *lean_sdl_camera_spec_of(const SDL_CameraSpec *s) {
    return lean_sdl_mk_camera_spec(
        (uint32_t)s->format, (uint32_t)s->colorspace,
        s->width, s->height, s->framerate_numerator, s->framerate_denominator);
}

/* ==================== Drivers ==================== */

/* Sdl.getNumCameraDrivers : IO Int32 -- C: SDL_GetNumCameraDrivers. */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_camera_drivers(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumCameraDrivers()));
}

/* Sdl.getCameraDriver (index : Int32) : IO (Option String)
 * -- C: SDL_GetCameraDriver (NULL = out of range). */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_driver(int32_t index, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetCameraDriver((int)index)));
}

/* Sdl.currentCameraDriver : IO (Option String)
 * -- C: SDL_GetCurrentCameraDriver (NULL = camera not initialized). */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_camera_driver(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetCurrentCameraDriver()));
}

/* ==================== Enumeration and opening ==================== */

/* Sdl.getCamerasRaw : IO (Array UInt32) -- C: SDL_GetCameras (NULL -> throw;
 * an empty non-NULL array is a normal result; SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_cameras(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_CameraID *ids = SDL_GetCameras(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.openCameraRaw (id : UInt32) (hasSpec : UInt8) (format colorspace : UInt32)
 *   (w h num den : Int32) : IO Camera
 * -- C: SDL_OpenCamera (spec flattened; hasSpec == 0 -> NULL spec; NULL cam ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_camera(
        uint32_t id, uint8_t has_spec, uint32_t format, uint32_t colorspace,
        int32_t w, int32_t h, int32_t num, int32_t den, lean_obj_arg world) {
    (void)world;
    SDL_SHIM_PROLOGUE();
    SDL_CameraSpec spec;
    SDL_CameraSpec *sp = NULL;
    if (has_spec) {
        SDL_zero(spec);
        spec.format = (SDL_PixelFormat)format;
        spec.colorspace = (SDL_Colorspace)colorspace;
        spec.width = w;
        spec.height = h;
        spec.framerate_numerator = num;
        spec.framerate_denominator = den;
        sp = &spec;
    }
    SDL_Camera *cam = SDL_OpenCamera((SDL_CameraID)id, sp);
    if (!cam) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_camera_class, cam, NULL));
}

/* ==================== CameraID methods ==================== */

/* Sdl.CameraID.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetCameraName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_name(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *n = SDL_GetCameraName((SDL_CameraID)id);
    if (!n) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(n));
}

/* Sdl.CameraID.positionRaw (id : UInt32) : IO UInt32 -- C: SDL_GetCameraPosition.
 * The C function returns 0 (SDL_CAMERA_POSITION_UNKNOWN, a VALID value) both for
 * a genuinely-unknown camera AND on error, only setting the error string in the
 * latter case. Disambiguate: clear the error first, call, and treat a 0 result
 * with a non-empty error as a failure. */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_position(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_ClearError();
    SDL_CameraPosition p = SDL_GetCameraPosition((SDL_CameraID)id);
    if (p == SDL_CAMERA_POSITION_UNKNOWN) {
        const char *e = SDL_GetError();
        if (e && *e) return lean_sdl_throw();
    }
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)p));
}

/* Sdl.CameraID.supportedFormatsRaw (id : UInt32) : IO (Array CameraSpec)
 * -- C: SDL_GetCameraSupportedFormats (NULL -> throw). The result is an array of
 * pointers in a single allocation, freed once after decoding each spec via the
 * Lean maker; an empty list is legal. */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_supported_formats(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_CameraSpec **specs = SDL_GetCameraSupportedFormats((SDL_CameraID)id, &count);
    if (!specs) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_sdl_camera_spec_of(specs[i]));
    SDL_free(specs);
    return lean_io_result_mk_ok(arr);
}

/* ==================== Camera methods ==================== */

/* Sdl.Camera.getPermissionStateRaw : IO Int32
 * -- C: SDL_GetCameraPermissionState (raw -1/0/1; decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_permission_state(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Camera, cam, self);
    SDL_CameraPermissionState s = SDL_GetCameraPermissionState(cam);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)(int32_t)s));
}

/* Sdl.Camera.getIDRaw : IO UInt32 -- C: SDL_GetCameraID (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_id(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Camera, cam, self);
    SDL_CameraID id = SDL_GetCameraID(cam);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Camera.getProperties : IO Properties -- C: SDL_GetCameraProperties.
 * Borrowed Properties tied to the camera (owner = inc'd camera external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Camera, cam, self);
    SDL_PropertiesID id = SDL_GetCameraProperties(cam);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Camera.getFormat : IO CameraSpec -- C: SDL_GetCameraFormat (out-param;
 * false -> throw, e.g. while access is still pending). */
LEAN_EXPORT lean_obj_res lean_sdl_get_camera_format(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Camera, cam, self);
    SDL_CameraSpec spec;
    SDL_zero(spec);
    if (!SDL_GetCameraFormat(cam, &spec)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_camera_spec_of(&spec));
}

/* Sdl.Camera.acquireFrame : IO (Option (Surface x UInt64))
 * -- C: SDL_AcquireCameraFrame. NULL frame -> none (NOT an error: no new frame
 * yet, or access still pending). Non-NULL -> inc the camera, wrap
 * {ptr=frame, owner=camera} in the frame class (release-to-source), and pair it
 * with the timestamp via the Lean maker. */
LEAN_EXPORT lean_obj_res lean_sdl_acquire_camera_frame(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Camera, cam, self);
    Uint64 ts = 0;
    SDL_Surface *frame = SDL_AcquireCameraFrame(cam, &ts);
    if (!frame) return lean_io_result_mk_ok(lean_sdl_none());
    lean_inc(self);
    lean_object *fobj = lean_sdl_wrap(lean_sdl_camera_frame_class, frame, (lean_object *)self);
    lean_object *pair = lean_sdl_mk_surface_timestamp(fobj, (uint64_t)ts);
    return lean_io_result_mk_ok(lean_sdl_some(pair));
}

/* Sdl.Camera.releaseFrame (frame : @& Surface) : IO Unit
 * -- C: SDL_ReleaseCameraFrame. Verify `frame` is a camera frame of THIS camera,
 * then release it and NULL the ptr (manual-destroy pattern; the finalizer
 * NULL-guards, and later Surface ops throw via SDL_GET_OR_THROW). */
LEAN_EXPORT lean_obj_res lean_sdl_release_camera_frame(
        b_lean_obj_arg self, b_lean_obj_arg frame, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Camera, cam, self);
    if (lean_get_external_class(frame) != lean_sdl_camera_frame_class)
        return lean_sdl_throw_msg("SDL: not a camera frame");
    sdl_holder *fh = lean_sdl_holder_of(frame);
    if (!fh->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    if (!fh->owner || lean_sdl_holder_of(fh->owner)->ptr != (void *)cam)
        return lean_sdl_throw_msg("SDL: frame does not belong to this camera");
    SDL_ReleaseCameraFrame(cam, (SDL_Surface *)fh->ptr);
    fh->ptr = NULL;
    return lean_sdl_unit_ok();
}
