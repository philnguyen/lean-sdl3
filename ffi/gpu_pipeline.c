/* Shims for Sdl/Gpu/Pipeline.lean (SDL_gpu.h): shaders, compute/graphics
 * pipelines, render passes, compute passes. Builds on ffi/gpu.c's device /
 * resource / command-buffer classes (reached generically through the shared
 * sdl_holder; the only cross-file dependency is reading a holder's ptr/owner).
 *
 * External classes (registered here; see docs/DESIGN.md "GPU module"):
 *   - lean_sdl_gpu_shader            : owned child {ptr, deviceExt}; finalize =
 *   - lean_sdl_gpu_compute_pipeline    SDL_ReleaseGPU*(device, ptr) then dec.
 *   - lean_sdl_gpu_graphics_pipeline   Manual `release` NULLs the ptr.
 *   - lean_sdl_gpu_render_pass       : consumable {ptr, cmdBufExt}; finish NULLs
 *   - lean_sdl_gpu_compute_pass        the ptr; finalizer decs the owner only.
 *
 * Pointer-free pipeline sub-structs (rasterizer/multisample/depth-stencil,
 * vertex buffer descriptions, vertex attributes, color target descriptions)
 * arrive as ByteArrays packed in Lean to the EXACT C layout and are memcpy'd
 * into place (sizeof/offsetof pinned in ffi/consts_check.c). Render/compute
 * pass bindings arrive as parallel arrays of externals plus a private scalar
 * blob whose layout is documented identically in the Lean packer and below. */
#include "util.h"
#include "classes.h"

/* Device pointer of an owned child (owner is always the device external). */
#define GPU_DEV(h) ((SDL_GPUDevice *)lean_sdl_holder_of((h)->owner)->ptr)

/* ---- External classes ---- */
SDL_DEFINE_CLASS(lean_sdl_gpu_shader,
    SDL_ReleaseGPUShader(GPU_DEV(h), (SDL_GPUShader *)self))
SDL_DEFINE_CLASS(lean_sdl_gpu_compute_pipeline,
    SDL_ReleaseGPUComputePipeline(GPU_DEV(h), (SDL_GPUComputePipeline *)self))
SDL_DEFINE_CLASS(lean_sdl_gpu_graphics_pipeline,
    SDL_ReleaseGPUGraphicsPipeline(GPU_DEV(h), (SDL_GPUGraphicsPipeline *)self))
SDL_DEFINE_BORROWED_CLASS(lean_sdl_gpu_render_pass)
SDL_DEFINE_BORROWED_CLASS(lean_sdl_gpu_compute_pass)

/* Register all classes. Called from Sdl/Gpu/Pipeline.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_pipeline_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_gpu_shader_class_init();
    lean_sdl_gpu_compute_pipeline_class_init();
    lean_sdl_gpu_graphics_pipeline_class_init();
    lean_sdl_gpu_render_pass_class_init();
    lean_sdl_gpu_compute_pass_class_init();
    return lean_sdl_unit_ok();
}

/* Manual release of an owned child: SDL_ReleaseGPU*(device, ptr) + NULL ptr
 * (the finalizer then skips the release and only decs the owner). */
#define GPU_CHILD_RELEASE(fnname, SDLTYPE, RELEASE_CALL)                        \
    LEAN_EXPORT lean_obj_res fnname(b_lean_obj_arg self, lean_obj_arg w) {      \
        (void)w;                                                                \
        SDL_SHIM_PROLOGUE();                                                    \
        sdl_holder *h = lean_sdl_holder_of(self);                             \
        if (!h->ptr)                                                            \
            return lean_sdl_throw_msg("SDL: handle used after destroy/release"); \
        RELEASE_CALL(GPU_DEV(h), (SDLTYPE *)h->ptr);                            \
        h->ptr = NULL;                                                          \
        return lean_sdl_unit_ok();                                             \
    }

GPU_CHILD_RELEASE(lean_sdl_gpu_release_shader, SDL_GPUShader, SDL_ReleaseGPUShader)
GPU_CHILD_RELEASE(lean_sdl_gpu_release_compute_pipeline, SDL_GPUComputePipeline,
                  SDL_ReleaseGPUComputePipeline)
GPU_CHILD_RELEASE(lean_sdl_gpu_release_graphics_pipeline, SDL_GPUGraphicsPipeline,
                  SDL_ReleaseGPUGraphicsPipeline)

/* ---- Little-endian scalar readers over a packed ByteArray ---- */
static uint32_t rd_u32(const uint8_t *p) { uint32_t v; SDL_memcpy(&v, p, 4); return v; }
static float rd_f32(const uint8_t *p) { float v; SDL_memcpy(&v, p, 4); return v; }

/* SDL_GPUTexture* of a Texture external: NULL when released, or when a
 * borrowed swapchain texture's command buffer was already consumed (the
 * pointer is then stale). */
static SDL_GPUTexture *texture_ptr_checked(b_lean_obj_arg ext) {
    if (lean_sdl_borrowed_stale(ext, lean_sdl_gpu_texture_borrowed_class))
        return NULL;
    return (SDL_GPUTexture *)lean_sdl_holder_of(ext)->ptr;
}

/* SDL_GPUTexture* of an `Option Texture` element: scalar (none) -> NULL with
 * `*stale` false; `some t` -> the checked ptr, flagging `*stale` when the
 * handle is released/stale (callers must throw, not silently pass NULL). */
static SDL_GPUTexture *opt_texture_ptr(b_lean_obj_arg opt, bool *stale) {
    *stale = false;
    if (lean_is_scalar(opt)) return NULL;
    SDL_GPUTexture *t = texture_ptr_checked(lean_ctor_get(opt, 0));
    if (!t) *stale = true;
    return t;
}

/* ==================== Shaders & pipelines ==================== */

/* Sdl.Gpu.Device.createShaderRaw (code entrypoint + 6 scalars) : IO Shader
 * -- C: SDL_CreateGPUShader. Owner = inc'd device; props field = 0. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_shader(
        b_lean_obj_arg self, b_lean_obj_arg code, b_lean_obj_arg entrypoint,
        uint32_t format, uint32_t stage, uint32_t num_samplers,
        uint32_t num_storage_textures, uint32_t num_storage_buffers,
        uint32_t num_uniform_buffers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUShaderCreateInfo info;
    SDL_zero(info);
    info.code_size = lean_sarray_size(code);
    info.code = (const Uint8 *)lean_sarray_cptr((lean_object *)code);
    info.entrypoint = lean_string_cstr(entrypoint);
    info.format = (SDL_GPUShaderFormat)format;
    info.stage = (SDL_GPUShaderStage)stage;
    info.num_samplers = num_samplers;
    info.num_storage_textures = num_storage_textures;
    info.num_storage_buffers = num_storage_buffers;
    info.num_uniform_buffers = num_uniform_buffers;
    info.props = 0;
    SDL_GPUShader *sh = SDL_CreateGPUShader(dev, &info);
    if (!sh) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_shader_class, sh, (lean_object *)self));
}

/* Sdl.Gpu.Device.createComputePipelineRaw (code entrypoint + 11 scalars)
 * : IO ComputePipeline -- C: SDL_CreateGPUComputePipeline. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_compute_pipeline(
        b_lean_obj_arg self, b_lean_obj_arg code, b_lean_obj_arg entrypoint,
        uint32_t format, uint32_t num_samplers, uint32_t num_ro_storage_textures,
        uint32_t num_ro_storage_buffers, uint32_t num_rw_storage_textures,
        uint32_t num_rw_storage_buffers, uint32_t num_uniform_buffers,
        uint32_t threadcount_x, uint32_t threadcount_y, uint32_t threadcount_z,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GPUComputePipelineCreateInfo info;
    SDL_zero(info);
    info.code_size = lean_sarray_size(code);
    info.code = (const Uint8 *)lean_sarray_cptr((lean_object *)code);
    info.entrypoint = lean_string_cstr(entrypoint);
    info.format = (SDL_GPUShaderFormat)format;
    info.num_samplers = num_samplers;
    info.num_readonly_storage_textures = num_ro_storage_textures;
    info.num_readonly_storage_buffers = num_ro_storage_buffers;
    info.num_readwrite_storage_textures = num_rw_storage_textures;
    info.num_readwrite_storage_buffers = num_rw_storage_buffers;
    info.num_uniform_buffers = num_uniform_buffers;
    info.threadcount_x = threadcount_x;
    info.threadcount_y = threadcount_y;
    info.threadcount_z = threadcount_z;
    info.props = 0;
    SDL_GPUComputePipeline *cp = SDL_CreateGPUComputePipeline(dev, &info);
    if (!cp) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_compute_pipeline_class, cp, (lean_object *)self));
}

/* Sdl.Gpu.Device.createGraphicsPipelineRaw -- C: SDL_CreateGPUGraphicsPipeline.
 * The three state blobs are memcpy'd into the zero-init createinfo (sizeof
 * asserts in consts_check.c make this safe); the array blobs are pointed at
 * directly (the @& borrows keep them alive for the whole call). props = 0. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_create_graphics_pipeline(
        b_lean_obj_arg self, b_lean_obj_arg vshader, b_lean_obj_arg fshader,
        b_lean_obj_arg vb_descs, uint32_t num_vb, b_lean_obj_arg v_attrs,
        uint32_t num_attrs, uint32_t primitive_type, b_lean_obj_arg rasterizer,
        b_lean_obj_arg multisample, b_lean_obj_arg depth_stencil, b_lean_obj_arg ct_descs,
        uint32_t num_ct, uint32_t depth_format, uint8_t has_depth, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUDevice, dev, self);
    SDL_GET_OR_THROW(SDL_GPUShader, vs, vshader);
    SDL_GET_OR_THROW(SDL_GPUShader, fs, fshader);
    SDL_GPUGraphicsPipelineCreateInfo info;
    SDL_zero(info);
    info.vertex_shader = vs;
    info.fragment_shader = fs;
    info.vertex_input_state.vertex_buffer_descriptions =
        (const SDL_GPUVertexBufferDescription *)lean_sarray_cptr((lean_object *)vb_descs);
    info.vertex_input_state.num_vertex_buffers = num_vb;
    info.vertex_input_state.vertex_attributes =
        (const SDL_GPUVertexAttribute *)lean_sarray_cptr((lean_object *)v_attrs);
    info.vertex_input_state.num_vertex_attributes = num_attrs;
    info.primitive_type = (SDL_GPUPrimitiveType)primitive_type;
    SDL_memcpy(&info.rasterizer_state, lean_sarray_cptr((lean_object *)rasterizer),
               sizeof(info.rasterizer_state));
    SDL_memcpy(&info.multisample_state, lean_sarray_cptr((lean_object *)multisample),
               sizeof(info.multisample_state));
    SDL_memcpy(&info.depth_stencil_state, lean_sarray_cptr((lean_object *)depth_stencil),
               sizeof(info.depth_stencil_state));
    info.target_info.color_target_descriptions =
        (const SDL_GPUColorTargetDescription *)lean_sarray_cptr((lean_object *)ct_descs);
    info.target_info.num_color_targets = num_ct;
    info.target_info.depth_stencil_format = (SDL_GPUTextureFormat)depth_format;
    info.target_info.has_depth_stencil_target = has_depth != 0;
    info.props = 0;
    SDL_GPUGraphicsPipeline *gp = SDL_CreateGPUGraphicsPipeline(dev, &info);
    if (!gp) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_graphics_pipeline_class, gp, (lean_object *)self));
}

/* ==================== Render pass ==================== */

/* Sdl.Gpu.CommandBuffer.beginRenderPassRaw -- C: SDL_BeginGPURenderPass.
 * Assembles up to 8 SDL_GPUColorTargetInfo + an optional depth-stencil target
 * from parallel texture arrays and our private scalar blobs (see the Lean
 * packers). Owner = inc'd command buffer. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_begin_render_pass(
        b_lean_obj_arg self, b_lean_obj_arg textures, b_lean_obj_arg resolve_textures,
        b_lean_obj_arg scalars, uint8_t has_depth, b_lean_obj_arg ds_texture,
        b_lean_obj_arg ds_scalars, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    size_t n = lean_array_size(textures);
    if (n > 8)
        return lean_sdl_throw_msg("SDL: beginRenderPass supports at most 8 color targets");
    SDL_GPUColorTargetInfo cti[8];
    SDL_memset(cti, 0, sizeof(cti));
    const uint8_t *sb = (const uint8_t *)lean_sarray_cptr((lean_object *)scalars);
    for (size_t i = 0; i < n; i++) {
        const uint8_t *p = sb + i * 44;
        SDL_GPUTexture *t = texture_ptr_checked(lean_array_get_core(textures, i));
        if (!t) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
        cti[i].texture = t;
        cti[i].mip_level = rd_u32(p + 0);
        cti[i].layer_or_depth_plane = rd_u32(p + 4);
        cti[i].clear_color.r = rd_f32(p + 8);
        cti[i].clear_color.g = rd_f32(p + 12);
        cti[i].clear_color.b = rd_f32(p + 16);
        cti[i].clear_color.a = rd_f32(p + 20);
        cti[i].load_op = (SDL_GPULoadOp)rd_u32(p + 24);
        cti[i].store_op = (SDL_GPUStoreOp)rd_u32(p + 28);
        bool resolve_stale;
        cti[i].resolve_texture =
            opt_texture_ptr(lean_array_get_core(resolve_textures, i), &resolve_stale);
        if (resolve_stale)
            return lean_sdl_throw_msg("SDL: handle used after destroy/release");
        cti[i].resolve_mip_level = rd_u32(p + 32);
        cti[i].resolve_layer = rd_u32(p + 36);
        cti[i].cycle = p[40] != 0;
        cti[i].cycle_resolve_texture = p[41] != 0;
    }
    SDL_GPUDepthStencilTargetInfo ds;
    SDL_GPUDepthStencilTargetInfo *dsp = NULL;
    if (has_depth != 0) {
        SDL_zero(ds);
        bool ds_stale;
        SDL_GPUTexture *dt = opt_texture_ptr(ds_texture, &ds_stale);
        if (!dt) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
        (void)ds_stale;
        const uint8_t *d = (const uint8_t *)lean_sarray_cptr((lean_object *)ds_scalars);
        ds.texture = dt;
        ds.clear_depth = rd_f32(d + 0);
        ds.load_op = (SDL_GPULoadOp)rd_u32(d + 4);
        ds.store_op = (SDL_GPUStoreOp)rd_u32(d + 8);
        ds.stencil_load_op = (SDL_GPULoadOp)rd_u32(d + 12);
        ds.stencil_store_op = (SDL_GPUStoreOp)rd_u32(d + 16);
        ds.cycle = d[20] != 0;
        ds.clear_stencil = d[21];
        dsp = &ds;
    }
    SDL_GPURenderPass *rp = SDL_BeginGPURenderPass(cmd, cti, (Uint32)n, dsp);
    if (!rp) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_render_pass_class, rp, (lean_object *)self));
}

/* Sdl.Gpu.RenderPass.bindPipeline (pipeline) -- C: SDL_BindGPUGraphicsPipeline. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_render_bind_pipeline(
        b_lean_obj_arg self, b_lean_obj_arg pipeline, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_GET_OR_THROW(SDL_GPUGraphicsPipeline, gp, pipeline);
    SDL_BindGPUGraphicsPipeline(rp, gp);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.setViewportRaw (6 floats) -- C: SDL_SetGPUViewport. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_viewport(
        b_lean_obj_arg self, float x, float y, float wv, float hv,
        float min_depth, float max_depth, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_GPUViewport vp = { x, y, wv, hv, min_depth, max_depth };
    SDL_SetGPUViewport(rp, &vp);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.setScissorRaw (4 int32) -- C: SDL_SetGPUScissor. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_scissor(
        b_lean_obj_arg self, int32_t x, int32_t y, int32_t wv, int32_t hv, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_Rect r = { x, y, wv, hv };
    SDL_SetGPUScissor(rp, &r);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.setBlendConstantsRaw (4 floats) -- C: SDL_SetGPUBlendConstants. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_blend_constants(
        b_lean_obj_arg self, float r, float g, float b, float a, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_FColor c = { r, g, b, a };
    SDL_SetGPUBlendConstants(rp, c);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.setStencilReference (reference : UInt8)
 * -- C: SDL_SetGPUStencilReference. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_set_stencil_reference(
        b_lean_obj_arg self, uint8_t reference, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_SetGPUStencilReference(rp, reference);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.bindVertexBuffersRaw (firstSlot, buffers, offsets)
 * -- C: SDL_BindGPUVertexBuffers. Builds SDL_GPUBufferBinding[] (SDL_malloc). */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_vertex_buffers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg buffers,
        b_lean_obj_arg offsets, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    size_t n = lean_array_size(buffers);
    const uint8_t *off = (const uint8_t *)lean_sarray_cptr((lean_object *)offsets);
    SDL_GPUBufferBinding *bb =
        (SDL_GPUBufferBinding *)SDL_malloc((n ? n : 1) * sizeof(SDL_GPUBufferBinding));
    if (!bb) return lean_sdl_throw_msg("SDL: out of memory building buffer bindings");
    for (size_t i = 0; i < n; i++) {
        SDL_GPUBuffer *b = (SDL_GPUBuffer *)lean_sdl_holder_of(lean_array_get_core(buffers, i))->ptr;
        if (!b) { SDL_free(bb); return lean_sdl_throw_msg("SDL: handle used after destroy/release"); }
        bb[i].buffer = b;
        bb[i].offset = rd_u32(off + i * 4);
    }
    SDL_BindGPUVertexBuffers(rp, first_slot, bb, (Uint32)n);
    SDL_free(bb);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.bindIndexBufferRaw (buffer, offset, elementSize)
 * -- C: SDL_BindGPUIndexBuffer. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_index_buffer(
        b_lean_obj_arg self, b_lean_obj_arg buffer, uint32_t offset,
        uint32_t element_size, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_GET_OR_THROW(SDL_GPUBuffer, b, buffer);
    SDL_GPUBufferBinding binding = { b, offset };
    SDL_BindGPUIndexBuffer(rp, &binding, (SDL_GPUIndexElementSize)element_size);
    return lean_sdl_unit_ok();
}

/* Build an SDL_GPUTextureSamplerBinding[] from parallel texture/sampler arrays
 * and dispatch to `bindfn`. Shared by vertex/fragment/compute samplers. */
static lean_obj_res gpu_bind_samplers(
        void *pass, uint32_t first_slot, b_lean_obj_arg textures, b_lean_obj_arg samplers,
        void (*bindfn)(void *, Uint32, const SDL_GPUTextureSamplerBinding *, Uint32)) {
    size_t n = lean_array_size(textures);
    SDL_GPUTextureSamplerBinding *tsb = (SDL_GPUTextureSamplerBinding *)SDL_malloc(
        (n ? n : 1) * sizeof(SDL_GPUTextureSamplerBinding));
    if (!tsb) return lean_sdl_throw_msg("SDL: out of memory building sampler bindings");
    for (size_t i = 0; i < n; i++) {
        SDL_GPUTexture *t = texture_ptr_checked(lean_array_get_core(textures, i));
        SDL_GPUSampler *s = (SDL_GPUSampler *)lean_sdl_holder_of(lean_array_get_core(samplers, i))->ptr;
        if (!t || !s) { SDL_free(tsb); return lean_sdl_throw_msg("SDL: handle used after destroy/release"); }
        tsb[i].texture = t;
        tsb[i].sampler = s;
    }
    bindfn(pass, first_slot, tsb, (Uint32)n);
    SDL_free(tsb);
    return lean_sdl_unit_ok();
}

/* Build an SDL_GPUTexture*[] from an Array Texture and dispatch to `bindfn`. */
static lean_obj_res gpu_bind_storage_textures(
        void *pass, uint32_t first_slot, b_lean_obj_arg textures,
        void (*bindfn)(void *, Uint32, SDL_GPUTexture *const *, Uint32)) {
    size_t n = lean_array_size(textures);
    SDL_GPUTexture **arr =
        (SDL_GPUTexture **)SDL_malloc((n ? n : 1) * sizeof(SDL_GPUTexture *));
    if (!arr) return lean_sdl_throw_msg("SDL: out of memory building storage textures");
    for (size_t i = 0; i < n; i++) {
        SDL_GPUTexture *t = texture_ptr_checked(lean_array_get_core(textures, i));
        if (!t) { SDL_free(arr); return lean_sdl_throw_msg("SDL: handle used after destroy/release"); }
        arr[i] = t;
    }
    bindfn(pass, first_slot, arr, (Uint32)n);
    SDL_free(arr);
    return lean_sdl_unit_ok();
}

/* Build an SDL_GPUBuffer*[] from an Array Buffer and dispatch to `bindfn`. */
static lean_obj_res gpu_bind_storage_buffers(
        void *pass, uint32_t first_slot, b_lean_obj_arg buffers,
        void (*bindfn)(void *, Uint32, SDL_GPUBuffer *const *, Uint32)) {
    size_t n = lean_array_size(buffers);
    SDL_GPUBuffer **arr =
        (SDL_GPUBuffer **)SDL_malloc((n ? n : 1) * sizeof(SDL_GPUBuffer *));
    if (!arr) return lean_sdl_throw_msg("SDL: out of memory building storage buffers");
    for (size_t i = 0; i < n; i++) {
        SDL_GPUBuffer *b = (SDL_GPUBuffer *)lean_sdl_holder_of(lean_array_get_core(buffers, i))->ptr;
        if (!b) { SDL_free(arr); return lean_sdl_throw_msg("SDL: handle used after destroy/release"); }
        arr[i] = b;
    }
    bindfn(pass, first_slot, arr, (Uint32)n);
    SDL_free(arr);
    return lean_sdl_unit_ok();
}

/* Trampolines matching the generic (void*) function-pointer signatures. */
static void bind_rp_samplers(void *p, Uint32 s, const SDL_GPUTextureSamplerBinding *b, Uint32 n)
    { SDL_BindGPUVertexSamplers((SDL_GPURenderPass *)p, s, b, n); }
static void bind_rp_frag_samplers(void *p, Uint32 s, const SDL_GPUTextureSamplerBinding *b, Uint32 n)
    { SDL_BindGPUFragmentSamplers((SDL_GPURenderPass *)p, s, b, n); }
static void bind_cp_samplers(void *p, Uint32 s, const SDL_GPUTextureSamplerBinding *b, Uint32 n)
    { SDL_BindGPUComputeSamplers((SDL_GPUComputePass *)p, s, b, n); }
static void bind_rp_vtx_stex(void *p, Uint32 s, SDL_GPUTexture *const *t, Uint32 n)
    { SDL_BindGPUVertexStorageTextures((SDL_GPURenderPass *)p, s, t, n); }
static void bind_rp_frag_stex(void *p, Uint32 s, SDL_GPUTexture *const *t, Uint32 n)
    { SDL_BindGPUFragmentStorageTextures((SDL_GPURenderPass *)p, s, t, n); }
static void bind_cp_stex(void *p, Uint32 s, SDL_GPUTexture *const *t, Uint32 n)
    { SDL_BindGPUComputeStorageTextures((SDL_GPUComputePass *)p, s, t, n); }
static void bind_rp_vtx_sbuf(void *p, Uint32 s, SDL_GPUBuffer *const *b, Uint32 n)
    { SDL_BindGPUVertexStorageBuffers((SDL_GPURenderPass *)p, s, b, n); }
static void bind_rp_frag_sbuf(void *p, Uint32 s, SDL_GPUBuffer *const *b, Uint32 n)
    { SDL_BindGPUFragmentStorageBuffers((SDL_GPURenderPass *)p, s, b, n); }
static void bind_cp_sbuf(void *p, Uint32 s, SDL_GPUBuffer *const *b, Uint32 n)
    { SDL_BindGPUComputeStorageBuffers((SDL_GPUComputePass *)p, s, b, n); }

/* Sdl.Gpu.RenderPass.bindVertexSamplersRaw -- C: SDL_BindGPUVertexSamplers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_vertex_samplers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg textures,
        b_lean_obj_arg samplers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    return gpu_bind_samplers(rp, first_slot, textures, samplers, bind_rp_samplers);
}

/* Sdl.Gpu.RenderPass.bindVertexStorageTextures -- C: SDL_BindGPUVertexStorageTextures. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_vertex_storage_textures(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg textures, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    return gpu_bind_storage_textures(rp, first_slot, textures, bind_rp_vtx_stex);
}

/* Sdl.Gpu.RenderPass.bindVertexStorageBuffers -- C: SDL_BindGPUVertexStorageBuffers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_vertex_storage_buffers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg buffers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    return gpu_bind_storage_buffers(rp, first_slot, buffers, bind_rp_vtx_sbuf);
}

/* Sdl.Gpu.RenderPass.bindFragmentSamplersRaw -- C: SDL_BindGPUFragmentSamplers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_fragment_samplers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg textures,
        b_lean_obj_arg samplers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    return gpu_bind_samplers(rp, first_slot, textures, samplers, bind_rp_frag_samplers);
}

/* Sdl.Gpu.RenderPass.bindFragmentStorageTextures -- C: SDL_BindGPUFragmentStorageTextures. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_fragment_storage_textures(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg textures, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    return gpu_bind_storage_textures(rp, first_slot, textures, bind_rp_frag_stex);
}

/* Sdl.Gpu.RenderPass.bindFragmentStorageBuffers -- C: SDL_BindGPUFragmentStorageBuffers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_fragment_storage_buffers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg buffers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    return gpu_bind_storage_buffers(rp, first_slot, buffers, bind_rp_frag_sbuf);
}

/* Sdl.Gpu.RenderPass.drawPrimitives -- C: SDL_DrawGPUPrimitives. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_draw_primitives(
        b_lean_obj_arg self, uint32_t num_vertices, uint32_t num_instances,
        uint32_t first_vertex, uint32_t first_instance, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_DrawGPUPrimitives(rp, num_vertices, num_instances, first_vertex, first_instance);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.drawIndexedPrimitives -- C: SDL_DrawGPUIndexedPrimitives. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_draw_indexed_primitives(
        b_lean_obj_arg self, uint32_t num_indices, uint32_t num_instances,
        uint32_t first_index, int32_t vertex_offset, uint32_t first_instance, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_DrawGPUIndexedPrimitives(rp, num_indices, num_instances, first_index,
                                 vertex_offset, first_instance);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.drawPrimitivesIndirect -- C: SDL_DrawGPUPrimitivesIndirect. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_draw_primitives_indirect(
        b_lean_obj_arg self, b_lean_obj_arg buffer, uint32_t offset, uint32_t draw_count,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_GET_OR_THROW(SDL_GPUBuffer, b, buffer);
    SDL_DrawGPUPrimitivesIndirect(rp, b, offset, draw_count);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.drawIndexedPrimitivesIndirect
 * -- C: SDL_DrawGPUIndexedPrimitivesIndirect. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_draw_indexed_primitives_indirect(
        b_lean_obj_arg self, b_lean_obj_arg buffer, uint32_t offset, uint32_t draw_count,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPURenderPass, rp, self);
    SDL_GET_OR_THROW(SDL_GPUBuffer, b, buffer);
    SDL_DrawGPUIndexedPrimitivesIndirect(rp, b, offset, draw_count);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.RenderPass.finish -- C: SDL_EndGPURenderPass (void). Consumes: NULLs
 * the ptr so later use throws and the finalizer skips. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_render_pass_finish(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_EndGPURenderPass((SDL_GPURenderPass *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* ==================== Compute pass ==================== */

/* Sdl.Gpu.CommandBuffer.beginComputePassRaw -- C: SDL_BeginGPUComputePass.
 * Assembles the two C binding arrays (SDL_malloc/free) from parallel external
 * arrays + our private scalar blobs (texture stride 12, buffer stride 1).
 * Owner = inc'd command buffer. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_begin_compute_pass(
        b_lean_obj_arg self, b_lean_obj_arg textures, b_lean_obj_arg texture_scalars,
        b_lean_obj_arg buffers, b_lean_obj_arg buffer_cycles, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUCommandBuffer, cmd, self);
    size_t nt = lean_array_size(textures);
    size_t nb = lean_array_size(buffers);
    SDL_GPUStorageTextureReadWriteBinding *tb = NULL;
    SDL_GPUStorageBufferReadWriteBinding *bb = NULL;
    if (nt) {
        tb = (SDL_GPUStorageTextureReadWriteBinding *)SDL_malloc(
            nt * sizeof(SDL_GPUStorageTextureReadWriteBinding));
        if (!tb) return lean_sdl_throw_msg("SDL: out of memory building storage-texture bindings");
        const uint8_t *ts = (const uint8_t *)lean_sarray_cptr((lean_object *)texture_scalars);
        for (size_t i = 0; i < nt; i++) {
            SDL_memset(&tb[i], 0, sizeof(tb[i]));
            SDL_GPUTexture *t = (SDL_GPUTexture *)lean_sdl_holder_of(lean_array_get_core(textures, i))->ptr;
            if (!t) { SDL_free(tb); return lean_sdl_throw_msg("SDL: handle used after destroy/release"); }
            tb[i].texture = t;
            tb[i].mip_level = rd_u32(ts + i * 12 + 0);
            tb[i].layer = rd_u32(ts + i * 12 + 4);
            tb[i].cycle = ts[i * 12 + 8] != 0;
        }
    }
    if (nb) {
        bb = (SDL_GPUStorageBufferReadWriteBinding *)SDL_malloc(
            nb * sizeof(SDL_GPUStorageBufferReadWriteBinding));
        if (!bb) { SDL_free(tb); return lean_sdl_throw_msg("SDL: out of memory building storage-buffer bindings"); }
        const uint8_t *bc = (const uint8_t *)lean_sarray_cptr((lean_object *)buffer_cycles);
        for (size_t i = 0; i < nb; i++) {
            SDL_memset(&bb[i], 0, sizeof(bb[i]));
            SDL_GPUBuffer *b = (SDL_GPUBuffer *)lean_sdl_holder_of(lean_array_get_core(buffers, i))->ptr;
            if (!b) { SDL_free(tb); SDL_free(bb); return lean_sdl_throw_msg("SDL: handle used after destroy/release"); }
            bb[i].buffer = b;
            bb[i].cycle = bc[i] != 0;
        }
    }
    SDL_GPUComputePass *cp =
        SDL_BeginGPUComputePass(cmd, tb, (Uint32)nt, bb, (Uint32)nb);
    SDL_free(tb);
    SDL_free(bb);
    if (!cp) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_gpu_compute_pass_class, cp, (lean_object *)self));
}

/* Sdl.Gpu.ComputePass.bindPipeline (pipeline) -- C: SDL_BindGPUComputePipeline. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_compute_bind_pipeline(
        b_lean_obj_arg self, b_lean_obj_arg pipeline, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUComputePass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUComputePipeline, p, pipeline);
    SDL_BindGPUComputePipeline(cp, p);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.ComputePass.bindSamplersRaw -- C: SDL_BindGPUComputeSamplers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_compute_samplers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg textures,
        b_lean_obj_arg samplers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUComputePass, cp, self);
    return gpu_bind_samplers(cp, first_slot, textures, samplers, bind_cp_samplers);
}

/* Sdl.Gpu.ComputePass.bindStorageTextures -- C: SDL_BindGPUComputeStorageTextures. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_compute_storage_textures(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg textures, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUComputePass, cp, self);
    return gpu_bind_storage_textures(cp, first_slot, textures, bind_cp_stex);
}

/* Sdl.Gpu.ComputePass.bindStorageBuffers -- C: SDL_BindGPUComputeStorageBuffers. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_bind_compute_storage_buffers(
        b_lean_obj_arg self, uint32_t first_slot, b_lean_obj_arg buffers, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUComputePass, cp, self);
    return gpu_bind_storage_buffers(cp, first_slot, buffers, bind_cp_sbuf);
}

/* Sdl.Gpu.ComputePass.dispatch (x y z) -- C: SDL_DispatchGPUCompute. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_dispatch(
        b_lean_obj_arg self, uint32_t gx, uint32_t gy, uint32_t gz, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUComputePass, cp, self);
    SDL_DispatchGPUCompute(cp, gx, gy, gz);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.ComputePass.dispatchIndirect (buffer, offset)
 * -- C: SDL_DispatchGPUComputeIndirect. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_dispatch_indirect(
        b_lean_obj_arg self, b_lean_obj_arg buffer, uint32_t offset, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_GPUComputePass, cp, self);
    SDL_GET_OR_THROW(SDL_GPUBuffer, b, buffer);
    SDL_DispatchGPUComputeIndirect(cp, b, offset);
    return lean_sdl_unit_ok();
}

/* Sdl.Gpu.ComputePass.finish -- C: SDL_EndGPUComputePass (void). Consumes. */
LEAN_EXPORT lean_obj_res lean_sdl_gpu_compute_pass_finish(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_EndGPUComputePass((SDL_GPUComputePass *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}
