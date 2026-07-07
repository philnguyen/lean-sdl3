/* Shims for Sdl/Gpu.lean (SDL_gpu.h): device / resource / transfer / copy-pass
 * / fence / swapchain core. Shaders, pipelines and render/compute passes live
 * in ffi/gpu_pipeline.c (a later module) and reuse the external classes
 * exported from ffi/classes.h.
 *
 * External classes (see docs/DESIGN.md "GPU module"):
 *   - lean_sdl_gpu_device          : owned root, finalizer SDL_DestroyGPUDevice.
 *   - lean_sdl_gpu_buffer          : owned child {ptr, deviceExt}; finalize =
 *   - lean_sdl_gpu_transfer_buffer   SDL_ReleaseGPU*(device, ptr) then dec owner.
 *   - lean_sdl_gpu_texture           The device pointer is read from the owner
 *   - lean_sdl_gpu_sampler           holder (owner is always the device ext).
 *   - lean_sdl_gpu_fence           : Manual `release` NULLs the ptr (finalizer
 *                                    then skips the SDL release, still decs).
 *   - lean_sdl_gpu_texture_borrowed: borrowed swapchain texture {ptr, cmdBufExt};
 *                                    finalize decs owner only; release/setName
 *                                    throw on it.
 *   - lean_sdl_gpu_cmdbuf          : consumable {ptr, deviceExt}; finalize decs
 *                                    owner only (never submit/cancel from a
 *                                    finalizer). submit/submitAndAcquireFence/
 *                                    cancel NULL the ptr unconditionally.
 *   - lean_sdl_gpu_copypass        : consumable {ptr, cmdBufExt}; finish NULLs.
 *
 * Create-info / location / region structs arrive as flattened scalars (+ Lean
 * externals) and are rebuilt field-by-field here; C never learns Lean struct
 * layouts. Map/unmap are wrapped by TransferBuffer.write/read (Lean bounds-
 * checks before touching the mapped pointer). */
#include "util.h"
#include "classes.h"

/* Lean-owned maker (see Sdl/Gpu.lean): wraps a swapchain texture + size. */
extern lean_object *lean_sdl_mk_gpu_swapchain_texture(
    lean_object *texture, uint32_t width, uint32_t height);

/* Device pointer of an owned child (owner is always the device external). */
#define GPU_DEV(h) ((SDL_GPUDevice *)lean_sdl_holder_of((h)->owner)->ptr)

/* ---- External classes ---- */
SDL_DEFINE_CLASS(lean_sdl_gpu_device, SDL_DestroyGPUDevice((SDL_GPUDevice *)self))
SDL_DEFINE_CLASS(lean_sdl_gpu_buffer,
    SDL_ReleaseGPUBuffer(GPU_DEV(h), (SDL_GPUBuffer *)self))
SDL_DEFINE_CLASS(lean_sdl_gpu_transfer_buffer,
    SDL_ReleaseGPUTransferBuffer(GPU_DEV(h), (SDL_GPUTransferBuffer *)self))
SDL_DEFINE_CLASS(lean_sdl_gpu_texture,
    SDL_ReleaseGPUTexture(GPU_DEV(h), (SDL_GPUTexture *)self))
SDL_DEFINE_BORROWED_CLASS(lean_sdl_gpu_texture_borrowed)
SDL_DEFINE_CLASS(lean_sdl_gpu_sampler,
    SDL_ReleaseGPUSampler(GPU_DEV(h), (SDL_GPUSampler *)self))
SDL_DEFINE_CLASS(lean_sdl_gpu_fence,
    SDL_ReleaseGPUFence(GPU_DEV(h), (SDL_GPUFence *)self))
SDL_DEFINE_BORROWED_CLASS(lean_sdl_gpu_cmdbuf)
SDL_DEFINE_BORROWED_CLASS(lean_sdl_gpu_copypass)

/* Register all classes. Called from Sdl/Gpu.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_gpu_device_class_init();
    lean_sdl_gpu_buffer_class_init();
    lean_sdl_gpu_transfer_buffer_class_init();
    lean_sdl_gpu_texture_class_init();
    lean_sdl_gpu_texture_borrowed_class_init();
    lean_sdl_gpu_sampler_class_init();
    lean_sdl_gpu_fence_class_init();
    lean_sdl_gpu_cmdbuf_class_init();
    lean_sdl_gpu_copypass_class_init();
    return lean_sdl_unit_ok();
}

/* Borrowed `Option String` -> C string or NULL. */
static const char *gpu_option_cstr(b_lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL;
    return lean_string_cstr(lean_ctor_get(opt, 0));
}

/* Extract an SDL_PropertiesID from a required `@& Properties` (throw if the
 * handle was destroyed). The holder ptr encodes the id (ffi/properties.c). */
#define GPU_PROPS_ID_OR_THROW(id, obj)                                         \
    SDL_PropertiesID id;                                                       \
    do {                                                                       \
        sdl_holder *_h = lean_sdl_holder_of(obj);                             \
        if (!_h->ptr)                                                          \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
        id = (SDL_PropertiesID)(uintptr_t)_h->ptr;                            \
    } while (0)

/* Manual release of an owned child: SDL_ReleaseGPU*(device, ptr) + NULL ptr
 * (the finalizer then skips the release and only decs the owner). */
#define GPU_CHILD_RELEASE(fnname, SDLTYPE, RELEASE_CALL)                        \
    LEAN_EXPORT lean_obj_res fnname(b_lean_obj_arg self, lean_obj_arg w) {      \
        (void)w;                                                                \
        SDL_SHIM_PROLOGUE();                                                    \
        sdl_holder *h = lean_sdl_holder_of(self);                              \
        if (!h->ptr)                                                            \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
        RELEASE_CALL(GPU_DEV(h), (SDLTYPE *)h->ptr);                            \
        h->ptr = NULL;                                                          \
        return lean_sdl_unit_ok();                                             \
    }

/* ==================== Top-level ==================== */

/* Sdl.Gpu.supportsShaderFormatsRaw (formats : UInt32) (name : Option String)
 * : IO Bool -- C: SDL_GPUSupportsShaderFormats. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_supports_shader_formats(
        uint32_t formats, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(
        SDL_GPUSupportsShaderFormats((SDL_GPUShaderFormat)formats,
                                     gpu_option_cstr(name)) ? 1 : 0));
}

/* Sdl.Gpu.supportsProperties (props : @& Properties) : IO Bool
 * -- C: SDL_GPUSupportsProperties. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_supports_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    GPU_PROPS_ID_OR_THROW(id, props);
    return lean_io_result_mk_ok(lean_box(SDL_GPUSupportsProperties(id) ? 1 : 0));
}

/* Sdl.Gpu.createDeviceRaw (formatFlags : UInt32) (debugMode : Bool)
 * (name : Option String) : IO Device -- C: SDL_CreateGPUDevice (owned root). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_device(
        uint32_t format_flags, uint8_t debug_mode, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GPUDevice *dev = SDL_CreateGPUDevice((SDL_GPUShaderFormat)format_flags,
                                             debug_mode != 0, gpu_option_cstr(name));
    if (!dev) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_gpu_device_class, dev, NULL));
}

/* Sdl.Gpu.createDeviceWithProperties (props : @& Properties) : IO Device
 * -- C: SDL_CreateGPUDeviceWithProperties (owned root). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_device_with_properties(
        b_lean_obj_arg props, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    GPU_PROPS_ID_OR_THROW(id, props);
    SDL_GPUDevice *dev = SDL_CreateGPUDeviceWithProperties(id);
    if (!dev) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_gpu_device_class, dev, NULL));
}

/* Sdl.Gpu.getNumDrivers : IO Int32 -- C: SDL_GetNumGPUDrivers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_get_num_drivers(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumGPUDrivers()));
}

/* Sdl.Gpu.getDriver (index : Int32) : IO String -- C: SDL_GetGPUDriver. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_get_driver(int32_t index, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetGPUDriver((int)index);
    if (!s) return lean_sdl_throw_msg("SDL: GPU driver index out of range");
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* ==================== Device queries ==================== */

/* Sdl.Gpu.Device.getDriver : IO String -- C: SDL_GetGPUDeviceDriver. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_device_get_driver(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    const char *s = SDL_GetGPUDeviceDriver(dev);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_string(s));
}

/* Sdl.Gpu.Device.getShaderFormatsRaw : IO UInt32 -- C: SDL_GetGPUShaderFormats. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_get_shader_formats(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetGPUShaderFormats(dev)));
}

/* Sdl.Gpu.Device.getProperties : IO Properties -- C: SDL_GetGPUDeviceProperties.
 * Borrowed Properties tied to the device (owner = inc'd device external). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_get_device_properties(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_PropertiesID id = SDL_GetGPUDeviceProperties(dev);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* ==================== Resource creation ==================== */

/* Sdl.Gpu.Device.createBufferRaw (usage size : UInt32) : IO Buffer
 * -- C: SDL_CreateGPUBuffer. Owner = inc'd device; props field = 0. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_buffer(
        b_lean_obj_arg self, uint32_t usage, uint32_t size, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUBufferCreateInfo info = { (SDL_GPUBufferUsageFlags)usage, size, 0 };
    SDL_GPUBuffer *b = SDL_CreateGPUBuffer(dev, &info);
    if (!b) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_buffer_class, b, (lean_object *)self));
}

/* Sdl.Gpu.Device.createTransferBufferRaw (usage size : UInt32)
 * : IO TransferBufferHandle -- C: SDL_CreateGPUTransferBuffer. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_transfer_buffer(
        b_lean_obj_arg self, uint32_t usage, uint32_t size, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUTransferBufferCreateInfo info = { (SDL_GPUTransferBufferUsage)usage, size, 0 };
    SDL_GPUTransferBuffer *tb = SDL_CreateGPUTransferBuffer(dev, &info);
    if (!tb) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_transfer_buffer_class, tb, (lean_object *)self));
}

/* Sdl.Gpu.Device.createTextureRaw (8 flattened scalars) : IO Texture
 * -- C: SDL_CreateGPUTexture. Owner = inc'd device; props field = 0. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_texture(
        b_lean_obj_arg self, uint32_t type, uint32_t format, uint32_t usage,
        uint32_t width, uint32_t height, uint32_t layer_count_or_depth,
        uint32_t num_levels, uint32_t sample_count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUTextureCreateInfo info;
    SDL_zero(info);
    info.type = (SDL_GPUTextureType)type;
    info.format = (SDL_GPUTextureFormat)format;
    info.usage = (SDL_GPUTextureUsageFlags)usage;
    info.width = width;
    info.height = height;
    info.layer_count_or_depth = layer_count_or_depth;
    info.num_levels = num_levels;
    info.sample_count = (SDL_GPUSampleCount)sample_count;
    info.props = 0;
    SDL_GPUTexture *t = SDL_CreateGPUTexture(dev, &info);
    if (!t) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_texture_class, t, (lean_object *)self));
}

/* Sdl.Gpu.Device.createSamplerRaw (13 flattened scalars) : IO Sampler
 * -- C: SDL_CreateGPUSampler. Owner = inc'd device; props field = 0. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_sampler(
        b_lean_obj_arg self, uint32_t min_filter, uint32_t mag_filter, uint32_t mipmap_mode,
        uint32_t address_u, uint32_t address_v, uint32_t address_w,
        float mip_lod_bias, float max_anisotropy, uint32_t compare_op,
        float min_lod, float max_lod, uint8_t enable_anisotropy, uint8_t enable_compare,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUSamplerCreateInfo info;
    SDL_zero(info);
    info.min_filter = (SDL_GPUFilter)min_filter;
    info.mag_filter = (SDL_GPUFilter)mag_filter;
    info.mipmap_mode = (SDL_GPUSamplerMipmapMode)mipmap_mode;
    info.address_mode_u = (SDL_GPUSamplerAddressMode)address_u;
    info.address_mode_v = (SDL_GPUSamplerAddressMode)address_v;
    info.address_mode_w = (SDL_GPUSamplerAddressMode)address_w;
    info.mip_lod_bias = mip_lod_bias;
    info.max_anisotropy = max_anisotropy;
    info.compare_op = (SDL_GPUCompareOp)compare_op;
    info.min_lod = min_lod;
    info.max_lod = max_lod;
    info.enable_anisotropy = enable_anisotropy != 0;
    info.enable_compare = enable_compare != 0;
    info.props = 0;
    SDL_GPUSampler *s = SDL_CreateGPUSampler(dev, &info);
    if (!s) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_sampler_class, s, (lean_object *)self));
}

/* Sdl.Gpu.Device.acquireCommandBuffer : IO CommandBuffer
 * -- C: SDL_AcquireGPUCommandBuffer. Consumable, owner = inc'd device. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_acquire_command_buffer(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUCommandBuffer *cmd = SDL_AcquireGPUCommandBuffer(dev);
    if (!cmd) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_cmdbuf_class, cmd, (lean_object *)self));
}

/* ==================== Window / swapchain (device) ==================== */

/* Sdl.Gpu.Device.claimWindow (window) : IO Unit -- C: SDL_ClaimWindowForGPUDevice. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_claim_window(
        b_lean_obj_arg self, b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_BOOL_TO_IO(SDL_ClaimWindowForGPUDevice(dev, win));
}

/* Sdl.Gpu.Device.releaseWindow (window) : IO Unit
 * -- C: SDL_ReleaseWindowFromGPUDevice (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_release_window(
        b_lean_obj_arg self, b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_ReleaseWindowFromGPUDevice(dev, win);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.Device.windowSupportsSwapchainCompositionRaw (composition : UInt32)
 * : IO Bool -- C: SDL_WindowSupportsGPUSwapchainComposition. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_window_supports_swapchain_composition(
        b_lean_obj_arg self, b_lean_obj_arg window, uint32_t composition, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    return lean_io_result_mk_ok(lean_box(SDL_WindowSupportsGPUSwapchainComposition(
        dev, win, (SDL_GPUSwapchainComposition)composition) ? 1 : 0));
}

/* Sdl.Gpu.Device.windowSupportsPresentModeRaw (mode : UInt32) : IO Bool
 * -- C: SDL_WindowSupportsGPUPresentMode. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_window_supports_present_mode(
        b_lean_obj_arg self, b_lean_obj_arg window, uint32_t mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    return lean_io_result_mk_ok(lean_box(SDL_WindowSupportsGPUPresentMode(
        dev, win, (SDL_GPUPresentMode)mode) ? 1 : 0));
}

/* Sdl.Gpu.Device.setSwapchainParametersRaw (composition mode : UInt32) : IO Unit
 * -- C: SDL_SetGPUSwapchainParameters. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_swapchain_parameters(
        b_lean_obj_arg self, b_lean_obj_arg window, uint32_t composition, uint32_t mode,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_BOOL_TO_IO(SDL_SetGPUSwapchainParameters(
        dev, win, (SDL_GPUSwapchainComposition)composition, (SDL_GPUPresentMode)mode));
}

/* Sdl.Gpu.Device.setAllowedFramesInFlight (frames : UInt32) : IO Unit
 * -- C: SDL_SetGPUAllowedFramesInFlight. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_allowed_frames_in_flight(
        b_lean_obj_arg self, uint32_t frames, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_BOOL_TO_IO(SDL_SetGPUAllowedFramesInFlight(dev, frames));
}

/* Sdl.Gpu.Device.getSwapchainTextureFormatRaw (window) : IO UInt32
 * -- C: SDL_GetGPUSwapchainTextureFormat (decoded Lean-side as an open enum). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_get_swapchain_texture_format(
        b_lean_obj_arg self, b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGPUSwapchainTextureFormat(dev, win)));
}

/* Sdl.Gpu.Device.waitForSwapchain (window) : IO Unit -- C: SDL_WaitForGPUSwapchain. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_wait_for_swapchain(
        b_lean_obj_arg self, b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_BOOL_TO_IO(SDL_WaitForGPUSwapchain(dev, win));
}

/* Sdl.Gpu.Device.waitForIdle : IO Unit -- C: SDL_WaitForGPUIdle. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_wait_for_idle(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_BOOL_TO_IO(SDL_WaitForGPUIdle(dev));
}

/* Sdl.Gpu.Device.waitForFences (waitAll : Bool) (fences : @& Array Fence) : IO Unit
 * -- C: SDL_WaitForGPUFences. Build an SDL_GPUFence*[] from the Lean array. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_wait_for_fences(
        b_lean_obj_arg self, uint8_t wait_all, b_lean_obj_arg fences, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    size_t n = lean_array_size(fences);
    SDL_GPUFence **arr = (SDL_GPUFence **)SDL_malloc((n ? n : 1) * sizeof(SDL_GPUFence *));
    if (!arr) return lean_sdl_throw_msg("SDL: out of memory building fence array");
    for (size_t i = 0; i < n; i++) {
        sdl_holder *h = lean_sdl_holder_of(lean_array_get_core(fences, i));
        if (!h->ptr) {
            SDL_free(arr);
            return lean_sdl_throw_msg("SDL: handle used after destroy/release");
        }
        arr[i] = (SDL_GPUFence *)h->ptr;
    }
    bool ok = SDL_WaitForGPUFences(dev, wait_all != 0, arr, (Uint32)n);
    SDL_free(arr);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.Device.textureSupportsFormatRaw (format type usage : UInt32) : IO Bool
 * -- C: SDL_GPUTextureSupportsFormat. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_texture_supports_format(
        b_lean_obj_arg self, uint32_t format, uint32_t type, uint32_t usage, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    return lean_io_result_mk_ok(lean_box(SDL_GPUTextureSupportsFormat(
        dev, (SDL_GPUTextureFormat)format, (SDL_GPUTextureType)type,
        (SDL_GPUTextureUsageFlags)usage) ? 1 : 0));
}

/* Sdl.Gpu.Device.textureSupportsSampleCountRaw (format sampleCount : UInt32)
 * : IO Bool -- C: SDL_GPUTextureSupportsSampleCount. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_texture_supports_sample_count(
        b_lean_obj_arg self, uint32_t format, uint32_t sample_count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    return lean_io_result_mk_ok(lean_box(SDL_GPUTextureSupportsSampleCount(
        dev, (SDL_GPUTextureFormat)format, (SDL_GPUSampleCount)sample_count) ? 1 : 0));
}

/* ==================== Resource methods ==================== */

/* Sdl.Gpu.Buffer.setName (name : @& String) : IO Unit -- C: SDL_SetGPUBufferName. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_buffer_name(
        b_lean_obj_arg self, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_SetGPUBufferName(GPU_DEV(h), (SDL_GPUBuffer *)h->ptr, lean_string_cstr(name));
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.Texture.setName (name : @& String) : IO Unit -- C: SDL_SetGPUTextureName.
 * Throws on a swapchain (borrowed) texture. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_texture_name(
        b_lean_obj_arg self, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (lean_get_external_class((lean_object *)self) == lean_sdl_gpu_texture_borrowed_class)
        return lean_sdl_throw_msg("SDL: cannot name a swapchain texture");
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_SetGPUTextureName(GPU_DEV(h), (SDL_GPUTexture *)h->ptr, lean_string_cstr(name));
    return lean_sdl_unit_ok();
}

GPU_CHILD_RELEASE(lean_sdl_gpu_release_buffer, SDL_GPUBuffer, SDL_ReleaseGPUBuffer)
GPU_CHILD_RELEASE(lean_sdl_gpu_release_transfer_buffer, SDL_GPUTransferBuffer,
                  SDL_ReleaseGPUTransferBuffer)
GPU_CHILD_RELEASE(lean_sdl_gpu_release_sampler, SDL_GPUSampler, SDL_ReleaseGPUSampler)
GPU_CHILD_RELEASE(lean_sdl_gpu_release_fence, SDL_GPUFence, SDL_ReleaseGPUFence)

/* Sdl.Gpu.Texture.release : IO Unit -- C: SDL_ReleaseGPUTexture. Throws on a
 * swapchain (borrowed) texture (SDL owns it). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_release_texture(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (lean_get_external_class((lean_object *)self) == lean_sdl_gpu_texture_borrowed_class)
        return lean_sdl_throw_msg("SDL: cannot release a swapchain texture");
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_ReleaseGPUTexture(GPU_DEV(h), (SDL_GPUTexture *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.Fence.query : IO Bool -- C: SDL_QueryGPUFence (device from owner). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_query_fence(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    return lean_io_result_mk_ok(
        lean_box(SDL_QueryGPUFence(GPU_DEV(h), (SDL_GPUFence *)h->ptr) ? 1 : 0));
}

/* ==================== TransferBuffer map/unmap ==================== */

/* Sdl.Gpu.TransferBuffer.writeRaw (data : @& ByteArray) (dstOffset : UInt32)
 * (cycle : Bool) : IO Unit -- C: SDL_MapGPUTransferBuffer + memcpy + unmap.
 * Bounds already checked in Lean. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_transfer_buffer_write(
        b_lean_obj_arg self, b_lean_obj_arg data, uint32_t dst_offset, uint8_t cycle,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUTransferBuffer, tb, self);
    SDL_GPUDevice *dev = GPU_DEV(lean_sdl_holder_of(self));
    void *mapped = SDL_MapGPUTransferBuffer(dev, tb, cycle != 0);
    if (!mapped) return lean_sdl_throw();
    size_t n = lean_sarray_size(data);
    if (n) SDL_memcpy((char *)mapped + dst_offset, lean_sarray_cptr((lean_object *)data), n);
    SDL_UnmapGPUTransferBuffer(dev, tb);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.TransferBuffer.readRaw (offset size : UInt32) : IO ByteArray
 * -- C: SDL_MapGPUTransferBuffer + memcpy + unmap. Bounds checked in Lean. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_transfer_buffer_read(
        b_lean_obj_arg self, uint32_t offset, uint32_t size, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUTransferBuffer, tb, self);
    SDL_GPUDevice *dev = GPU_DEV(lean_sdl_holder_of(self));
    void *mapped = SDL_MapGPUTransferBuffer(dev, tb, false);
    if (!mapped) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, size, size);
    if (size) SDL_memcpy(lean_sarray_cptr(arr), (char *)mapped + offset, size);
    SDL_UnmapGPUTransferBuffer(dev, tb);
    return lean_io_result_mk_ok(arr);
}

/* ==================== CommandBuffer ==================== */

/* Sdl.Gpu.CommandBuffer.insertDebugLabel (text) : IO Unit
 * -- C: SDL_InsertGPUDebugLabel (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_insert_debug_label(
        b_lean_obj_arg self, b_lean_obj_arg text, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_InsertGPUDebugLabel(cmd, lean_string_cstr(text));
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CommandBuffer.pushDebugGroup (name) : IO Unit
 * -- C: SDL_PushGPUDebugGroup (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_push_debug_group(
        b_lean_obj_arg self, b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_PushGPUDebugGroup(cmd, lean_string_cstr(name));
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CommandBuffer.popDebugGroup : IO Unit -- C: SDL_PopGPUDebugGroup (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_pop_debug_group(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_PopGPUDebugGroup(cmd);
    return lean_sdl_unit_ok();
}

/* Uniform-push helper: three near-identical void shims. */
#define GPU_PUSH_UNIFORM(fnname, SDLCALLNAME)                                  \
    LEAN_EXPORT lean_obj_res fnname(b_lean_obj_arg self, uint32_t slot,        \
            b_lean_obj_arg data, lean_obj_arg w) {                            \
        (void)w;                                                               \
        SDL_SHIM_PROLOGUE();                                                    \
        SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);                     \
        SDLCALLNAME(cmd, slot, lean_sarray_cptr((lean_object *)data),          \
                    (Uint32)lean_sarray_size(data));                           \
        return lean_sdl_unit_ok();                                             \
    }

/* Sdl.Gpu.CommandBuffer.push{Vertex,Fragment,Compute}UniformData
 * -- C: SDL_PushGPU{Vertex,Fragment,Compute}UniformData. */
GPU_PUSH_UNIFORM(lean_sdl_gpu_push_vertex_uniform_data, SDL_PushGPUVertexUniformData)
GPU_PUSH_UNIFORM(lean_sdl_gpu_push_fragment_uniform_data, SDL_PushGPUFragmentUniformData)
GPU_PUSH_UNIFORM(lean_sdl_gpu_push_compute_uniform_data, SDL_PushGPUComputeUniformData)

/* Sdl.Gpu.CommandBuffer.beginCopyPass : IO CopyPass -- C: SDL_BeginGPUCopyPass.
 * Consumable, owner = inc'd command-buffer external. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_begin_copy_pass(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_GPUCopyPass *cp = SDL_BeginGPUCopyPass(cmd);
    if (!cp) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_copypass_class, cp, (lean_object *)self));
}

/* Sdl.Gpu.CommandBuffer.generateMipmaps (texture) : IO Unit
 * -- C: SDL_GenerateMipmapsForGPUTexture (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_generate_mipmaps(
        b_lean_obj_arg self, b_lean_obj_arg texture, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_GET_OR_THROW(SDL_GPUTexture, t, texture);
    SDL_GenerateMipmapsForGPUTexture(cmd, t);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CommandBuffer.blitTextureRaw (2 textures + flattened scalars) : IO Unit
 * -- C: SDL_BlitGPUTexture (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_blit_texture(
        b_lean_obj_arg self,
        b_lean_obj_arg src_tex, uint32_t src_mip, uint32_t src_layer_or_depth,
        uint32_t src_x, uint32_t src_y, uint32_t src_w, uint32_t src_h,
        b_lean_obj_arg dst_tex, uint32_t dst_mip, uint32_t dst_layer_or_depth,
        uint32_t dst_x, uint32_t dst_y, uint32_t dst_w, uint32_t dst_h,
        uint32_t load_op, float clear_r, float clear_g, float clear_b, float clear_a,
        uint32_t flip_mode, uint32_t filter, uint8_t cycle, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_GET_OR_THROW(SDL_GPUTexture, st, src_tex);
    SDL_GET_OR_THROW(SDL_GPUTexture, dt, dst_tex);
    SDL_GPUBlitInfo info;
    SDL_zero(info);
    info.source.texture = st;
    info.source.mip_level = src_mip;
    info.source.layer_or_depth_plane = src_layer_or_depth;
    info.source.x = src_x;
    info.source.y = src_y;
    info.source.w = src_w;
    info.source.h = src_h;
    info.destination.texture = dt;
    info.destination.mip_level = dst_mip;
    info.destination.layer_or_depth_plane = dst_layer_or_depth;
    info.destination.x = dst_x;
    info.destination.y = dst_y;
    info.destination.w = dst_w;
    info.destination.h = dst_h;
    info.load_op = (SDL_GPULoadOp)load_op;
    info.clear_color.r = clear_r;
    info.clear_color.g = clear_g;
    info.clear_color.b = clear_b;
    info.clear_color.a = clear_a;
    info.flip_mode = (SDL_FlipMode)flip_mode;
    info.filter = (SDL_GPUFilter)filter;
    info.cycle = cycle != 0;
    SDL_BlitGPUTexture(cmd, &info);
    return lean_sdl_unit_ok();
}

/* Wrap a freshly-acquired swapchain texture into an Option SwapchainTexture:
 * C false -> throw; C true with NULL texture -> none; else a borrowed texture
 * (owner = inc'd command buffer) inside `some`. */
static lean_obj_res lean_sdl_gpu_acquire_swapchain_common(
        b_lean_obj_arg self, b_lean_obj_arg window, bool wait) {
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    SDL_GET_OR_THROW(SDL_Window, win, window);
    SDL_GPUTexture *tex = NULL;
    Uint32 tw = 0, th = 0;
    bool ok = wait
        ? SDL_WaitAndAcquireGPUSwapchainTexture(cmd, win, &tex, &tw, &th)
        : SDL_AcquireGPUSwapchainTexture(cmd, win, &tex, &tw, &th);
    if (!ok) return lean_sdl_throw();
    if (!tex) return lean_io_result_mk_ok(lean_sdl_none());
    lean_inc(self);
    lean_object *texobj =
        lean_sdl_wrap(lean_sdl_gpu_texture_borrowed_class, tex, (lean_object *)self);
    lean_object *st = lean_sdl_mk_gpu_swapchain_texture(texobj, (uint32_t)tw, (uint32_t)th);
    return lean_io_result_mk_ok(lean_sdl_some(st));
}

/* Sdl.Gpu.CommandBuffer.acquireSwapchainTexture (window) : IO (Option SwapchainTexture)
 * -- C: SDL_AcquireGPUSwapchainTexture. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_acquire_swapchain_texture(
        b_lean_obj_arg self, b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_gpu_acquire_swapchain_common(self, window, false);
}

/* Sdl.Gpu.CommandBuffer.waitAndAcquireSwapchainTexture (window)
 * : IO (Option SwapchainTexture) -- C: SDL_WaitAndAcquireGPUSwapchainTexture. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_wait_and_acquire_swapchain_texture(
        b_lean_obj_arg self, b_lean_obj_arg window, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_gpu_acquire_swapchain_common(self, window, true);
}

/* Sdl.Gpu.CommandBuffer.submit : IO Unit -- C: SDL_SubmitGPUCommandBuffer. NULLs
 * the ptr unconditionally (invalid to reuse either way), then throws on false. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_submit(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_GPUCommandBuffer *cmd = (SDL_GPUCommandBuffer *)h->ptr;
    h->ptr = NULL;
    SDL_BOOL_TO_IO(SDL_SubmitGPUCommandBuffer(cmd));
}

/* Sdl.Gpu.CommandBuffer.submitAndAcquireFence : IO Fence
 * -- C: SDL_SubmitGPUCommandBufferAndAcquireFence. NULLs the ptr uncondition-
 * ally; the fence's owner is the device (inc the command buffer's owner). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_submit_and_acquire_fence(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_GPUCommandBuffer *cmd = (SDL_GPUCommandBuffer *)h->ptr;
    lean_object *device = h->owner; /* the command buffer's device external */
    h->ptr = NULL;
    SDL_GPUFence *fence = SDL_SubmitGPUCommandBufferAndAcquireFence(cmd);
    if (!fence) return lean_sdl_throw();
    lean_inc(device);
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_gpu_fence_class, fence, device));
}

/* Sdl.Gpu.CommandBuffer.cancel : IO Unit -- C: SDL_CancelGPUCommandBuffer. NULLs
 * the ptr unconditionally, then throws on false. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_cancel(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_GPUCommandBuffer *cmd = (SDL_GPUCommandBuffer *)h->ptr;
    h->ptr = NULL;
    SDL_BOOL_TO_IO(SDL_CancelGPUCommandBuffer(cmd));
}

/* ==================== CopyPass ==================== */

/* Sdl.Gpu.CopyPass.uploadToTextureRaw -- C: SDL_UploadToGPUTexture (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_upload_to_texture(
        b_lean_obj_arg self, b_lean_obj_arg tb, uint32_t offset, uint32_t ppr, uint32_t rpl,
        b_lean_obj_arg tex, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t z,
        uint32_t rw, uint32_t rh, uint32_t rd, uint8_t cycle, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCopyPass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUTransferBuffer, tbuf, tb);
    SDL_GET_OR_THROW(SDL_GPUTexture, t, tex);
    SDL_GPUTextureTransferInfo src = { tbuf, offset, ppr, rpl };
    SDL_GPUTextureRegion dst = { t, mip, layer, x, y, z, rw, rh, rd };
    SDL_UploadToGPUTexture(cp, &src, &dst, cycle != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CopyPass.uploadToBufferRaw -- C: SDL_UploadToGPUBuffer (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_upload_to_buffer(
        b_lean_obj_arg self, b_lean_obj_arg tb, uint32_t src_offset,
        b_lean_obj_arg buffer, uint32_t dst_offset, uint32_t size, uint8_t cycle,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCopyPass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUTransferBuffer, tbuf, tb);
    SDL_GET_OR_THROW(SDL_GPUBuffer, buf, buffer);
    SDL_GPUTransferBufferLocation src = { tbuf, src_offset };
    SDL_GPUBufferRegion dst = { buf, dst_offset, size };
    SDL_UploadToGPUBuffer(cp, &src, &dst, cycle != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CopyPass.copyTextureToTextureRaw -- C: SDL_CopyGPUTextureToTexture (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_copy_texture_to_texture(
        b_lean_obj_arg self,
        b_lean_obj_arg src_tex, uint32_t s_mip, uint32_t s_layer,
        uint32_t s_x, uint32_t s_y, uint32_t s_z,
        b_lean_obj_arg dst_tex, uint32_t d_mip, uint32_t d_layer,
        uint32_t d_x, uint32_t d_y, uint32_t d_z,
        uint32_t rw, uint32_t rh, uint32_t rd, uint8_t cycle, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCopyPass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUTexture, st, src_tex);
    SDL_GET_OR_THROW(SDL_GPUTexture, dt, dst_tex);
    SDL_GPUTextureLocation src = { st, s_mip, s_layer, s_x, s_y, s_z };
    SDL_GPUTextureLocation dst = { dt, d_mip, d_layer, d_x, d_y, d_z };
    SDL_CopyGPUTextureToTexture(cp, &src, &dst, rw, rh, rd, cycle != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CopyPass.copyBufferToBufferRaw -- C: SDL_CopyGPUBufferToBuffer (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_copy_buffer_to_buffer(
        b_lean_obj_arg self, b_lean_obj_arg src_buf, uint32_t src_offset,
        b_lean_obj_arg dst_buf, uint32_t dst_offset, uint32_t size, uint8_t cycle,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCopyPass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUBuffer, sb, src_buf);
    SDL_GET_OR_THROW(SDL_GPUBuffer, db, dst_buf);
    SDL_GPUBufferLocation src = { sb, src_offset };
    SDL_GPUBufferLocation dst = { db, dst_offset };
    SDL_CopyGPUBufferToBuffer(cp, &src, &dst, size, cycle != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CopyPass.downloadFromTextureRaw -- C: SDL_DownloadFromGPUTexture (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_download_from_texture(
        b_lean_obj_arg self,
        b_lean_obj_arg tex, uint32_t mip, uint32_t layer,
        uint32_t x, uint32_t y, uint32_t z, uint32_t rw, uint32_t rh, uint32_t rd,
        b_lean_obj_arg tb, uint32_t offset, uint32_t ppr, uint32_t rpl, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCopyPass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUTexture, t, tex);
    SDL_GET_OR_THROW(SDL_GPUTransferBuffer, tbuf, tb);
    SDL_GPUTextureRegion src = { t, mip, layer, x, y, z, rw, rh, rd };
    SDL_GPUTextureTransferInfo dst = { tbuf, offset, ppr, rpl };
    SDL_DownloadFromGPUTexture(cp, &src, &dst);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CopyPass.downloadFromBufferRaw -- C: SDL_DownloadFromGPUBuffer (void). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_download_from_buffer(
        b_lean_obj_arg self, b_lean_obj_arg buffer, uint32_t offset, uint32_t size,
        b_lean_obj_arg tb, uint32_t dst_offset, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCopyPass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUBuffer, buf, buffer);
    SDL_GET_OR_THROW(SDL_GPUTransferBuffer, tbuf, tb);
    SDL_GPUBufferRegion src = { buf, offset, size };
    SDL_GPUTransferBufferLocation dst = { tbuf, dst_offset };
    SDL_DownloadFromGPUBuffer(cp, &src, &dst);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.CopyPass.finish : IO Unit -- C: SDL_EndGPUCopyPass (void). Consumes:
 * NULLs the ptr so later use throws and the finalizer skips. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_copy_pass_finish(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_EndGPUCopyPass((SDL_GPUCopyPass *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* ==================== Format helpers (device-free) ==================== */

/* Sdl.Gpu.TextureFormat.texelBlockSizeRaw (format : UInt32) : IO UInt32
 * -- C: SDL_GPUTextureFormatTexelBlockSize. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_texel_block_size(uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32(
        SDL_GPUTextureFormatTexelBlockSize((SDL_GPUTextureFormat)format)));
}

/* Sdl.Gpu.TextureFormat.calculateSizeRaw (format width height depthOrLayerCount)
 * : IO UInt32 -- C: SDL_CalculateGPUTextureFormatSize. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_calculate_size(
        uint32_t format, uint32_t width, uint32_t height, uint32_t depth_or_layer_count,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32(SDL_CalculateGPUTextureFormatSize(
        (SDL_GPUTextureFormat)format, width, height, depth_or_layer_count)));
}

/* Sdl.Gpu.TextureFormat.toPixelFormatRaw (format : UInt32) : IO UInt32
 * -- C: SDL_GetPixelFormatFromGPUTextureFormat. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_pixel_format_of(uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32(
        (uint32_t)SDL_GetPixelFormatFromGPUTextureFormat((SDL_GPUTextureFormat)format)));
}

/* Sdl.Gpu.TextureFormat.ofPixelFormatRaw (format : UInt32) : IO UInt32
 * -- C: SDL_GetGPUTextureFormatFromPixelFormat. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_texture_format_of_pixel(uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32(
        (uint32_t)SDL_GetGPUTextureFormatFromPixelFormat((SDL_PixelFormat)format)));
}
