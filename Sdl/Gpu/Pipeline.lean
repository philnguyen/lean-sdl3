module

public import Sdl.Gpu
public meta import Sdl.Gpu

public section

/-!
# GPU pipelines & passes (`SDL_gpu.h`)

The shader / pipeline / render-pass / compute-pass half of the SDL3 GPU API
(namespace `Sdl.Gpu`), building on the device / resource / copy-pass core in
`Sdl/Gpu.lean`. Enums and flags are in `Sdl/Gpu/Enums.lean`.

## Ownership

* `Shader` / `ComputePipeline` / `GraphicsPipeline` — **owned children** of the
  `Device` (`{ptr, deviceExternal}`); finalize = `SDL_ReleaseGPU*(device, ptr)`
  then dec the device, plus a manual `release`. A shader may be `release`d
  immediately after the pipeline that uses it is created (probe-verified safe):
  the pipeline keeps its own reference to the compiled program.
* `RenderPass` / `ComputePass` — **consumable** handles `{ptr,
  commandBufferExternal}`. `finish` (C `SDL_EndGPU*Pass`; `end` is a Lean
  keyword) NULLs the pointer so later use throws; the finalizer only decrements
  the owning command buffer. A pass must be finished before beginning another
  pass or submitting the command buffer.

## Struct passing (see `docs/DESIGN.md` "GPU module")

Create-info / state structs are plain Lean structures with C-zero-init
defaults. Pointer-free sub-structs (`RasterizerState`, `MultisampleState`,
`DepthStencilState`, `VertexBufferDescription`, `VertexAttribute`,
`ColorTargetDescription`, …) are packed in pure Lean to the **exact C layout**
and `memcpy`d into place C-side (every `sizeof`/`offsetof` pinned in
`ffi/consts_check.c`, pack strides pinned by the `#guard`s below). Structs that
contain object pointers (render/compute pass bindings) travel as parallel
arrays of externals plus a private scalar blob whose layout is documented
identically in the Lean packer and the C shim.

## MSL shader binding order (`SDL_CreateGPUShader`, MSL / metallib)

Author resource bindings in this order:

* `[[texture(n)]]`: sampled textures, followed by storage textures.
* `[[sampler(n)]]`: samplers, indices matching the sampled textures.
* `[[buffer(n)]]`: uniform buffers, followed by storage buffers.

Vertex buffer 0 is bound at `[[buffer(14)]]`, vertex buffer 1 at
`[[buffer(15)]]`, and so on. Prefer the `[[stage_in]]` attribute, which uses
the pipeline's vertex-input state automatically instead of manual indices.

## Lifetime caveat: binds do not retain (pipelines and samplers)

Binding a pipeline or sampler in a pass does **not** retain it, and SDL frees
a released `GraphicsPipeline`/`ComputePipeline`/`Sampler` immediately — even
while it is bound in a not-yet-submitted command buffer (buffers and textures
are safe: SDL defers their destruction while any command buffer references
them). With Lean's eager reference counting, a *local* pipeline whose last
syntactic use is the `bindPipeline` call is finalized right after that call —
a use-after-free at draw time. Keep pipelines and samplers reachable (e.g. in
your app state, or by calling `.release` only after the command buffer is
submitted) for as long as any recorded-but-unsubmitted work uses them. Same
rule as render's "keep your reference alive while bound"
(`docs/DESIGN.md`).
-/

namespace Sdl.Gpu

/-- A compiled shader program (vertex or fragment). Owned child of its
`Device`. C: `SDL_GPUShader`. -/
sdl_opaque Shader

/-- A compiled compute pipeline. Owned child of its `Device`. C:
`SDL_GPUComputePipeline`. -/
sdl_opaque ComputePipeline

/-- A compiled graphics pipeline. Owned child of its `Device`. C:
`SDL_GPUGraphicsPipeline`. -/
sdl_opaque GraphicsPipeline

/-- A render pass opened on a command buffer. Consumable: `finish` ends it. C:
`SDL_GPURenderPass`. -/
sdl_opaque RenderPass

/-- A compute pass opened on a command buffer. Consumable: `finish` ends it. C:
`SDL_GPUComputePass`. -/
sdl_opaque ComputePass

@[extern "lean_sdl_gpu_pipeline_register_classes"]
private opaque registerPipelineClasses : IO Unit

initialize registerPipelineClasses

/-! ## Byte-packing helpers

Little-endian scalar appenders shared by every packer (all supported targets
are little-endian). `Float32.toBits` gives the IEEE-754 bit pattern, matching
`Sdl/Render.lean`'s `packVertices`. -/

private def pushU8 (b : ByteArray) (v : UInt8) : ByteArray := b.push v

private def pushU32 (b : ByteArray) (v : UInt32) : ByteArray :=
  b.push v.toUInt8 |>.push (v >>> 8).toUInt8 |>.push (v >>> 16).toUInt8
    |>.push (v >>> 24).toUInt8

private def pushI32 (b : ByteArray) (v : Int32) : ByteArray := pushU32 b v.toUInt32

private def pushF32 (b : ByteArray) (f : Float32) : ByteArray := pushU32 b f.toBits

private def pushBool (b : ByteArray) (x : Bool) : ByteArray := b.push (if x then 1 else 0)

private def pushZeros (b : ByteArray) (n : Nat) : ByteArray := Id.run do
  let mut b := b
  for _ in [0:n] do
    b := b.push 0
  return b

/-! ## Pipeline state structures -/

/-- Stencil operation state of one triangle face. C: `SDL_GPUStencilOpState`. -/
structure StencilOpState where
  /-- Action on samples that fail the stencil test. -/
  failOp : StencilOp := .invalid
  /-- Action on samples that pass the depth and stencil tests. -/
  passOp : StencilOp := .invalid
  /-- Action on samples that pass the stencil test but fail the depth test. -/
  depthFailOp : StencilOp := .invalid
  /-- Comparison operator used in the stencil test. -/
  compareOp : CompareOp := .invalid

/-- Blend state of a color target. C: `SDL_GPUColorTargetBlendState`. -/
structure ColorTargetBlendState where
  /-- Factor multiplied by the source RGB value. -/
  srcColorBlendfactor : BlendFactor := .invalid
  /-- Factor multiplied by the destination RGB value. -/
  dstColorBlendfactor : BlendFactor := .invalid
  /-- Blend operation for the RGB components. -/
  colorBlendOp : BlendOp := .invalid
  /-- Factor multiplied by the source alpha value. -/
  srcAlphaBlendfactor : BlendFactor := .invalid
  /-- Factor multiplied by the destination alpha value. -/
  dstAlphaBlendfactor : BlendFactor := .invalid
  /-- Blend operation for the alpha component. -/
  alphaBlendOp : BlendOp := .invalid
  /-- Which RGBA components are enabled for writing (used only if
  `enableColorWriteMask`). -/
  colorWriteMask : ColorComponentFlags := ⟨0⟩
  /-- Whether blending is enabled for the color target. -/
  enableBlend : Bool := false
  /-- Whether the color write mask is enabled. -/
  enableColorWriteMask : Bool := false

/-- Rasterizer state of a graphics pipeline. C: `SDL_GPURasterizerState`. -/
structure RasterizerState where
  /-- Whether polygons are filled or drawn as lines. -/
  fillMode : FillMode := .fill
  /-- The facing direction in which triangles are culled. -/
  cullMode : CullMode := .none
  /-- The vertex winding that makes a triangle front-facing. -/
  frontFace : FrontFace := .counterClockwise
  /-- Scalar factor controlling the depth value added to each fragment. -/
  depthBiasConstantFactor : Float32 := 0
  /-- Maximum depth bias of a fragment. -/
  depthBiasClamp : Float32 := 0
  /-- Scalar factor applied to a fragment's slope in depth calculations. -/
  depthBiasSlopeFactor : Float32 := 0
  /-- Whether fragment depth values are biased. -/
  enableDepthBias : Bool := false
  /-- Whether depth clip is enabled (false enables depth clamp). -/
  enableDepthClip : Bool := false

/-- Multisample state of a graphics pipeline. C: `SDL_GPUMultisampleState`. -/
structure MultisampleState where
  /-- The number of samples used in rasterization. -/
  sampleCount : SampleCount := .x1
  /-- Reserved; must be 0. -/
  sampleMask : UInt32 := 0
  /-- Reserved; must be false. -/
  enableMask : Bool := false
  /-- Whether the alpha-to-coverage feature is enabled. -/
  enableAlphaToCoverage : Bool := false

/-- Depth-stencil state of a graphics pipeline. C: `SDL_GPUDepthStencilState`. -/
structure DepthStencilState where
  /-- Comparison operator used for depth testing. -/
  compareOp : CompareOp := .invalid
  /-- Stencil op state for back-facing triangles. -/
  backStencilState : StencilOpState := {}
  /-- Stencil op state for front-facing triangles. -/
  frontStencilState : StencilOpState := {}
  /-- Bits of the stencil values participating in the stencil test. -/
  compareMask : UInt8 := 0
  /-- Bits of the stencil values updated by the stencil test. -/
  writeMask : UInt8 := 0
  /-- Whether the depth test is enabled. -/
  enableDepthTest : Bool := false
  /-- Whether depth writes are enabled (disabled when `enableDepthTest` false). -/
  enableDepthWrite : Bool := false
  /-- Whether the stencil test is enabled. -/
  enableStencilTest : Bool := false

/-- Parameters of one vertex buffer used by a graphics pipeline. C:
`SDL_GPUVertexBufferDescription`. -/
structure VertexBufferDescription where
  /-- The binding slot of the vertex buffer. -/
  slot : UInt32 := 0
  /-- The size of one element plus the offset between elements (the stride). -/
  pitch : UInt32 := 0
  /-- Whether addressing is by vertex index or instance index. -/
  inputRate : VertexInputRate := .vertex
  /-- Reserved; must be 0. -/
  instanceStepRate : UInt32 := 0

/-- A vertex attribute. C: `SDL_GPUVertexAttribute`. -/
structure VertexAttribute where
  /-- The shader input location index. -/
  location : UInt32 := 0
  /-- The binding slot of the associated vertex buffer. -/
  bufferSlot : UInt32 := 0
  /-- The size and type of the attribute data. -/
  format : VertexElementFormat := .invalid
  /-- Byte offset of this attribute within a vertex element. -/
  offset : UInt32 := 0

/-- The vertex input layout of a graphics pipeline. C:
`SDL_GPUVertexInputState`. -/
structure VertexInputState where
  /-- The vertex buffer descriptions. -/
  vertexBufferDescriptions : Array VertexBufferDescription := #[]
  /-- The vertex attribute descriptions (locations must be unique). -/
  vertexAttributes : Array VertexAttribute := #[]

/-- Description of one color target of a graphics pipeline. C:
`SDL_GPUColorTargetDescription`. -/
structure ColorTargetDescription where
  /-- The pixel format of the color-target texture. -/
  format : TextureFormat
  /-- The blend state for the color target. -/
  blendState : ColorTargetBlendState := {}

/-- Formats and blend modes for the render targets of a graphics pipeline.
C: `SDL_GPUGraphicsPipelineTargetInfo`. -/
structure GraphicsPipelineTargetInfo where
  /-- The color target descriptions. -/
  colorTargetDescriptions : Array ColorTargetDescription := #[]
  /-- The pixel format of the depth-stencil target (if `hasDepthStencilTarget`). -/
  depthStencilFormat : TextureFormat := .invalid
  /-- Whether the pipeline uses a depth-stencil target. -/
  hasDepthStencilTarget : Bool := false

/-- Parameters for `Device.createGraphicsPipeline`. C:
`SDL_GPUGraphicsPipelineCreateInfo` (the `props` extension field is passed as
0). -/
structure GraphicsPipelineCreateInfo where
  /-- The vertex shader. -/
  vertexShader : Shader
  /-- The fragment shader. -/
  fragmentShader : Shader
  /-- The vertex input layout. -/
  vertexInputState : VertexInputState := {}
  /-- The primitive topology. -/
  primitiveType : PrimitiveType := .triangleList
  /-- The rasterizer state. -/
  rasterizerState : RasterizerState := {}
  /-- The multisample state. -/
  multisampleState : MultisampleState := {}
  /-- The depth-stencil state. -/
  depthStencilState : DepthStencilState := {}
  /-- Formats and blend modes for the render targets. -/
  targetInfo : GraphicsPipelineTargetInfo

/-! ### Packers (exact C layout; strides pinned by the `#guard`s) -/

/-- Append a `SDL_GPUStencilOpState` (16 bytes) to `b`. -/
private def emitStencilOpState (b : ByteArray) (s : StencilOpState) : ByteArray :=
  pushU32 (pushU32 (pushU32 (pushU32 b s.failOp.val) s.passOp.val)
    s.depthFailOp.val) s.compareOp.val

/-- Append a `SDL_GPUColorTargetBlendState` (32 bytes) to `b`. -/
private def emitColorTargetBlendState (b : ByteArray) (s : ColorTargetBlendState) :
    ByteArray := Id.run do
  let mut b := b
  b := pushU32 b s.srcColorBlendfactor.val
  b := pushU32 b s.dstColorBlendfactor.val
  b := pushU32 b s.colorBlendOp.val
  b := pushU32 b s.srcAlphaBlendfactor.val
  b := pushU32 b s.dstAlphaBlendfactor.val
  b := pushU32 b s.alphaBlendOp.val
  b := pushU8 b s.colorWriteMask.val
  b := pushBool b s.enableBlend
  b := pushBool b s.enableColorWriteMask
  b := pushZeros b 5 -- padding1, padding2, + 3 tail-pad to 32
  return b

/-- Pack `SDL_GPURasterizerState` (28 bytes). -/
def packRasterizerState (s : RasterizerState) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity 28
  b := pushU32 b s.fillMode.val
  b := pushU32 b s.cullMode.val
  b := pushU32 b s.frontFace.val
  b := pushF32 b s.depthBiasConstantFactor
  b := pushF32 b s.depthBiasClamp
  b := pushF32 b s.depthBiasSlopeFactor
  b := pushBool b s.enableDepthBias
  b := pushBool b s.enableDepthClip
  b := pushZeros b 2
  return b

#guard (packRasterizerState {}).size == 28

/-- Pack `SDL_GPUMultisampleState` (12 bytes). -/
def packMultisampleState (s : MultisampleState) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity 12
  b := pushU32 b s.sampleCount.val
  b := pushU32 b s.sampleMask
  b := pushBool b s.enableMask
  b := pushBool b s.enableAlphaToCoverage
  b := pushZeros b 2
  return b

#guard (packMultisampleState {}).size == 12

/-- Pack `SDL_GPUDepthStencilState` (44 bytes). -/
def packDepthStencilState (s : DepthStencilState) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity 44
  b := pushU32 b s.compareOp.val
  b := emitStencilOpState b s.backStencilState
  b := emitStencilOpState b s.frontStencilState
  b := pushU8 b s.compareMask
  b := pushU8 b s.writeMask
  b := pushBool b s.enableDepthTest
  b := pushBool b s.enableDepthWrite
  b := pushBool b s.enableStencilTest
  b := pushZeros b 3
  return b

#guard (packDepthStencilState {}).size == 44

/-- Pack an array of `SDL_GPUVertexBufferDescription` (16 bytes each). -/
def packVertexBufferDescriptions (ds : Array VertexBufferDescription) : ByteArray :=
    Id.run do
  let mut b := ByteArray.emptyWithCapacity (ds.size * 16)
  for d in ds do
    b := pushU32 b d.slot
    b := pushU32 b d.pitch
    b := pushU32 b d.inputRate.val
    b := pushU32 b d.instanceStepRate
  return b

#guard (packVertexBufferDescriptions #[{}]).size == 16

/-- Pack an array of `SDL_GPUVertexAttribute` (16 bytes each). -/
def packVertexAttributes (attrs : Array VertexAttribute) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (attrs.size * 16)
  for a in attrs do
    b := pushU32 b a.location
    b := pushU32 b a.bufferSlot
    b := pushU32 b a.format.val
    b := pushU32 b a.offset
  return b

#guard (packVertexAttributes #[{}]).size == 16

/-- Pack an array of `SDL_GPUColorTargetDescription` (36 bytes each: format +
32-byte blend state). -/
def packColorTargetDescriptions (ds : Array ColorTargetDescription) : ByteArray :=
    Id.run do
  let mut b := ByteArray.emptyWithCapacity (ds.size * 36)
  for d in ds do
    b := pushU32 b d.format.val
    b := emitColorTargetBlendState b d.blendState
  return b

#guard (packColorTargetDescriptions #[{ format := .r8g8b8a8Unorm }]).size == 36

/-! ## Shaders & pipelines -/

/-- Parameters for `Device.createShader`. C: `SDL_GPUShaderCreateInfo` (the
`props` extension field is passed as 0). -/
structure ShaderCreateInfo where
  /-- The shader code (`code_size` is `code.size`). -/
  code : ByteArray
  /-- The entry-point function name. -/
  entrypoint : String
  /-- The format of the shader code. -/
  format : ShaderFormat
  /-- The stage the shader corresponds to. -/
  stage : ShaderStage
  /-- The number of samplers defined in the shader. -/
  numSamplers : UInt32 := 0
  /-- The number of storage textures defined in the shader. -/
  numStorageTextures : UInt32 := 0
  /-- The number of storage buffers defined in the shader. -/
  numStorageBuffers : UInt32 := 0
  /-- The number of uniform buffers defined in the shader. -/
  numUniformBuffers : UInt32 := 0

/-- Parameters for `Device.createComputePipeline`. C:
`SDL_GPUComputePipelineCreateInfo` (the `props` extension field is passed as
0). The threadcounts must match the values in the shader; there is no sane
zero default, so they are required. -/
structure ComputePipelineCreateInfo where
  /-- The compute shader code (`code_size` is `code.size`). -/
  code : ByteArray
  /-- The entry-point function name. -/
  entrypoint : String
  /-- The format of the shader code. -/
  format : ShaderFormat
  /-- The number of samplers defined in the shader. -/
  numSamplers : UInt32 := 0
  /-- The number of readonly storage textures defined in the shader. -/
  numReadonlyStorageTextures : UInt32 := 0
  /-- The number of readonly storage buffers defined in the shader. -/
  numReadonlyStorageBuffers : UInt32 := 0
  /-- The number of read-write storage textures defined in the shader. -/
  numReadwriteStorageTextures : UInt32 := 0
  /-- The number of read-write storage buffers defined in the shader. -/
  numReadwriteStorageBuffers : UInt32 := 0
  /-- The number of uniform buffers defined in the shader. -/
  numUniformBuffers : UInt32 := 0
  /-- The number of threads in the X dimension. -/
  threadcountX : UInt32
  /-- The number of threads in the Y dimension. -/
  threadcountY : UInt32
  /-- The number of threads in the Z dimension. -/
  threadcountZ : UInt32

namespace Device

@[extern "lean_sdl_gpu_create_shader"]
private opaque createShaderRaw (self : @& Device) (code : @& ByteArray)
    (entrypoint : @& String) (format stage numSamplers numStorageTextures
    numStorageBuffers numUniformBuffers : UInt32) : IO Shader

/-- Create a shader from `info`. See the MSL binding-order rules in this
module's doc comment. Throws on failure. C: `SDL_CreateGPUShader`. -/
def createShader (self : @& Device) (info : ShaderCreateInfo) : IO Shader :=
  createShaderRaw self info.code info.entrypoint info.format.val info.stage.val
    info.numSamplers info.numStorageTextures info.numStorageBuffers info.numUniformBuffers

@[extern "lean_sdl_gpu_create_compute_pipeline"]
private opaque createComputePipelineRaw (self : @& Device) (code : @& ByteArray)
    (entrypoint : @& String) (format numSamplers numReadonlyStorageTextures
    numReadonlyStorageBuffers numReadwriteStorageTextures numReadwriteStorageBuffers
    numUniformBuffers threadcountX threadcountY threadcountZ : UInt32) : IO ComputePipeline

/-- Create a compute pipeline from `info`. Same MSL binding order as
`createShader` (uniform buffers then storage buffers in `[[buffer]]`). Throws
on failure. C: `SDL_CreateGPUComputePipeline`. -/
def createComputePipeline (self : @& Device) (info : ComputePipelineCreateInfo) :
    IO ComputePipeline :=
  createComputePipelineRaw self info.code info.entrypoint info.format.val
    info.numSamplers info.numReadonlyStorageTextures info.numReadonlyStorageBuffers
    info.numReadwriteStorageTextures info.numReadwriteStorageBuffers info.numUniformBuffers
    info.threadcountX info.threadcountY info.threadcountZ

@[extern "lean_sdl_gpu_create_graphics_pipeline"]
private opaque createGraphicsPipelineRaw (self : @& Device)
    (vshader fshader : @& Shader) (vbDescs : @& ByteArray) (numVb : UInt32)
    (vAttrs : @& ByteArray) (numAttrs : UInt32) (primitiveType : UInt32)
    (rasterizer multisample depthStencil ctDescs : @& ByteArray)
    (numCt depthFormat : UInt32) (hasDepth : Bool) : IO GraphicsPipeline

/-- Create a graphics pipeline from `info`. Packs the pointer-free state
sub-structs to their exact C layout; the shaders may be `release`d immediately
afterwards. Throws on failure. C: `SDL_CreateGPUGraphicsPipeline`. -/
def createGraphicsPipeline (self : @& Device) (info : GraphicsPipelineCreateInfo) :
    IO GraphicsPipeline :=
  createGraphicsPipelineRaw self info.vertexShader info.fragmentShader
    (packVertexBufferDescriptions info.vertexInputState.vertexBufferDescriptions)
    (UInt32.ofNat info.vertexInputState.vertexBufferDescriptions.size)
    (packVertexAttributes info.vertexInputState.vertexAttributes)
    (UInt32.ofNat info.vertexInputState.vertexAttributes.size)
    info.primitiveType.val
    (packRasterizerState info.rasterizerState)
    (packMultisampleState info.multisampleState)
    (packDepthStencilState info.depthStencilState)
    (packColorTargetDescriptions info.targetInfo.colorTargetDescriptions)
    (UInt32.ofNat info.targetInfo.colorTargetDescriptions.size)
    info.targetInfo.depthStencilFormat.val info.targetInfo.hasDepthStencilTarget

end Device

/-- Release the shader immediately (rather than at finalization). Safe to call
right after any pipeline using it is created. Later use throws. C:
`SDL_ReleaseGPUShader`. -/
@[extern "lean_sdl_gpu_release_shader"]
opaque Shader.release (self : @& Shader) : IO Unit

/-- Release the compute pipeline immediately. Later use throws. C:
`SDL_ReleaseGPUComputePipeline`. -/
@[extern "lean_sdl_gpu_release_compute_pipeline"]
opaque ComputePipeline.release (self : @& ComputePipeline) : IO Unit

/-- Release the graphics pipeline immediately. Later use throws. C:
`SDL_ReleaseGPUGraphicsPipeline`. -/
@[extern "lean_sdl_gpu_release_graphics_pipeline"]
opaque GraphicsPipeline.release (self : @& GraphicsPipeline) : IO Unit

/-! ## Indirect-draw command data

Pure data mirroring the C indirect-command structs, with `toBytes` packers
(tightly packed `Uint32`/`Sint32` LE, no padding) for writing into an INDIRECT
buffer. -/

/-- Parameters of an indirect draw. C: `SDL_GPUIndirectDrawCommand` (16 bytes). -/
structure IndirectDrawCommand where
  /-- The number of vertices to draw. -/
  numVertices : UInt32
  /-- The number of instances to draw. -/
  numInstances : UInt32
  /-- The index of the first vertex to draw. -/
  firstVertex : UInt32 := 0
  /-- The ID of the first instance to draw. -/
  firstInstance : UInt32 := 0

/-- Pack to the 16-byte `SDL_GPUIndirectDrawCommand` layout. -/
def IndirectDrawCommand.toBytes (c : IndirectDrawCommand) : ByteArray :=
  pushU32 (pushU32 (pushU32 (pushU32 (ByteArray.emptyWithCapacity 16)
    c.numVertices) c.numInstances) c.firstVertex) c.firstInstance

#guard (IndirectDrawCommand.toBytes { numVertices := 0, numInstances := 0 }).size == 16

/-- Parameters of an indexed indirect draw. C:
`SDL_GPUIndexedIndirectDrawCommand` (20 bytes). -/
structure IndexedIndirectDrawCommand where
  /-- The number of indices to draw per instance. -/
  numIndices : UInt32
  /-- The number of instances to draw. -/
  numInstances : UInt32
  /-- The base index within the index buffer. -/
  firstIndex : UInt32 := 0
  /-- Value added to the vertex index before indexing into the vertex buffer. -/
  vertexOffset : Int32 := 0
  /-- The ID of the first instance to draw. -/
  firstInstance : UInt32 := 0

/-- Pack to the 20-byte `SDL_GPUIndexedIndirectDrawCommand` layout. -/
def IndexedIndirectDrawCommand.toBytes (c : IndexedIndirectDrawCommand) : ByteArray :=
  pushU32 (pushI32 (pushU32 (pushU32 (pushU32 (ByteArray.emptyWithCapacity 20)
    c.numIndices) c.numInstances) c.firstIndex) c.vertexOffset) c.firstInstance

#guard (IndexedIndirectDrawCommand.toBytes { numIndices := 0, numInstances := 0 }).size == 20

/-- Parameters of an indirect dispatch. C: `SDL_GPUIndirectDispatchCommand`
(12 bytes). -/
structure IndirectDispatchCommand where
  /-- Local workgroups to dispatch in the X dimension. -/
  groupcountX : UInt32
  /-- Local workgroups to dispatch in the Y dimension. -/
  groupcountY : UInt32
  /-- Local workgroups to dispatch in the Z dimension. -/
  groupcountZ : UInt32

/-- Pack to the 12-byte `SDL_GPUIndirectDispatchCommand` layout. -/
def IndirectDispatchCommand.toBytes (c : IndirectDispatchCommand) : ByteArray :=
  pushU32 (pushU32 (pushU32 (ByteArray.emptyWithCapacity 12)
    c.groupcountX) c.groupcountY) c.groupcountZ

#guard (IndirectDispatchCommand.toBytes { groupcountX := 0, groupcountY := 0, groupcountZ := 0 }).size == 12

/-! ## Render pass -/

/-- A color target of a render pass. C: `SDL_GPUColorTargetInfo`. -/
structure ColorTargetInfo where
  /-- The texture used as a color target. -/
  texture : Texture
  /-- The mip level to use. -/
  mipLevel : UInt32 := 0
  /-- The layer index (2D array/cube) or depth plane (3D) to use. -/
  layerOrDepthPlane : UInt32 := 0
  /-- The color to clear to at pass begin (used only if `loadOp` is `.clear`). -/
  clearColor : Sdl.FColor := ⟨0, 0, 0, 0⟩
  /-- What is done with the target's contents at pass begin. -/
  loadOp : LoadOp := .load
  /-- What is done with the pass's color results. -/
  storeOp : StoreOp := .store
  /-- The texture that receives a multisample resolve (only for RESOLVE* ops). -/
  resolveTexture : Option Texture := none
  /-- The mip level of the resolve texture. -/
  resolveMipLevel : UInt32 := 0
  /-- The layer index of the resolve texture. -/
  resolveLayer : UInt32 := 0
  /-- Cycle the texture if it is bound and `loadOp` is not `.load`. -/
  cycle : Bool := false
  /-- Cycle the resolve texture if it is bound. -/
  cycleResolveTexture : Bool := false

/-- A depth-stencil target of a render pass. C:
`SDL_GPUDepthStencilTargetInfo`. -/
structure DepthStencilTargetInfo where
  /-- The depth-stencil texture. -/
  texture : Texture
  /-- The value to clear depth to (used only if `loadOp` is `.clear`). -/
  clearDepth : Float32 := 0
  /-- What is done with the depth contents at pass begin. -/
  loadOp : LoadOp := .load
  /-- What is done with the depth results. -/
  storeOp : StoreOp := .store
  /-- What is done with the stencil contents at pass begin. -/
  stencilLoadOp : LoadOp := .load
  /-- What is done with the stencil results. -/
  stencilStoreOp : StoreOp := .store
  /-- Cycle the texture if it is bound and any load op is not `.load`. -/
  cycle : Bool := false
  /-- The value to clear stencil to (used only if `loadOp` is `.clear`). -/
  clearStencil : UInt8 := 0

/-- The viewport of a render pass. C: `SDL_GPUViewport`. The depth defaults
`(0, 1)` are the practical unit range (a deliberate deviation from C-zero, where
`maxDepth` would be 0). -/
structure Viewport where
  /-- The left offset of the viewport. -/
  x : Float32 := 0
  /-- The top offset of the viewport. -/
  y : Float32 := 0
  /-- The width of the viewport. -/
  w : Float32
  /-- The height of the viewport. -/
  h : Float32
  /-- The minimum depth of the viewport. -/
  minDepth : Float32 := 0
  /-- The maximum depth of the viewport. -/
  maxDepth : Float32 := 1

/-- Parameters of a vertex/index buffer binding. C: `SDL_GPUBufferBinding`. -/
structure BufferBinding where
  /-- The buffer to bind. -/
  buffer : Buffer
  /-- The starting byte of the data to bind. -/
  offset : UInt32 := 0

/-- A texture-sampler pair binding. C: `SDL_GPUTextureSamplerBinding`. -/
structure TextureSamplerBinding where
  /-- The texture to bind (must have the SAMPLER usage). -/
  texture : Texture
  /-- The sampler to bind. -/
  sampler : Sampler

/-- Our private per-color-target scalar blob (stride 44; NOT a C struct — it is
assembled into an `SDL_GPUColorTargetInfo` C-side): `mip u32@0, layer u32@4,
clear r/g/b/a f32@8/12/16/20, loadOp u32@24, storeOp u32@28, resolveMip u32@32,
resolveLayer u32@36, cycle u8@40, cycleResolve u8@41, pad@42..43`. -/
private def packColorTargetInfos (ts : Array ColorTargetInfo) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (ts.size * 44)
  for t in ts do
    b := pushU32 b t.mipLevel
    b := pushU32 b t.layerOrDepthPlane
    b := pushF32 b t.clearColor.r
    b := pushF32 b t.clearColor.g
    b := pushF32 b t.clearColor.b
    b := pushF32 b t.clearColor.a
    b := pushU32 b t.loadOp.val
    b := pushU32 b t.storeOp.val
    b := pushU32 b t.resolveMipLevel
    b := pushU32 b t.resolveLayer
    b := pushBool b t.cycle
    b := pushBool b t.cycleResolveTexture
    b := pushZeros b 2
  return b

/-- Our private depth-stencil scalar blob (24 bytes; assembled into an
`SDL_GPUDepthStencilTargetInfo` C-side): `clearDepth f32@0, loadOp u32@4, storeOp
u32@8, stencilLoadOp u32@12, stencilStoreOp u32@16, cycle u8@20, clearStencil
u8@21, pad@22..23`. -/
private def packDepthStencilTargetInfo (d : DepthStencilTargetInfo) : ByteArray :=
    Id.run do
  let mut b := ByteArray.emptyWithCapacity 24
  b := pushF32 b d.clearDepth
  b := pushU32 b d.loadOp.val
  b := pushU32 b d.storeOp.val
  b := pushU32 b d.stencilLoadOp.val
  b := pushU32 b d.stencilStoreOp.val
  b := pushBool b d.cycle
  b := pushU8 b d.clearStencil
  b := pushZeros b 2
  return b

/-- Pack an array of vertex/index buffer-binding offsets (u32 LE each). -/
private def packBufferOffsets (bs : Array BufferBinding) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (bs.size * 4)
  for x in bs do
    b := pushU32 b x.offset
  return b

namespace CommandBuffer

@[extern "lean_sdl_gpu_begin_render_pass"]
private opaque beginRenderPassRaw (self : @& CommandBuffer) (textures : @& Array Texture)
    (resolveTextures : @& Array (Option Texture)) (scalars : @& ByteArray)
    (hasDepth : Bool) (dsTexture : @& Option Texture) (dsScalars : @& ByteArray) :
    IO RenderPass

/-- Begin a render pass writing to `colorTargets` (at most 8) and an optional
`depthStencilTarget`. All graphics-pipeline work happens inside the pass; it
must be finished (`RenderPass.finish`) before beginning another pass or
submitting. Throws on failure. C: `SDL_BeginGPURenderPass`. -/
def beginRenderPass (self : @& CommandBuffer) (colorTargets : Array ColorTargetInfo)
    (depthStencilTarget : Option DepthStencilTargetInfo := none) : IO RenderPass :=
  beginRenderPassRaw self (colorTargets.map (·.texture))
    (colorTargets.map (·.resolveTexture)) (packColorTargetInfos colorTargets)
    depthStencilTarget.isSome (depthStencilTarget.map (·.texture))
    (match depthStencilTarget with
     | some d => packDepthStencilTargetInfo d
     | none   => ByteArray.empty)

end CommandBuffer

namespace RenderPass

/-- Bind a graphics pipeline for subsequent draws. Does **not** retain the
pipeline — keep it reachable until the command buffer is submitted (see the
module doc's lifetime caveat). C: `SDL_BindGPUGraphicsPipeline`. -/
@[extern "lean_sdl_gpu_render_bind_pipeline"]
opaque bindPipeline (self : @& RenderPass) (pipeline : @& GraphicsPipeline) : IO Unit

@[extern "lean_sdl_gpu_set_viewport"]
private opaque setViewportRaw (self : @& RenderPass) (x y w h minDepth maxDepth : Float32) :
    IO Unit

/-- Set the current viewport. C: `SDL_SetGPUViewport`. -/
def setViewport (self : @& RenderPass) (viewport : Viewport) : IO Unit :=
  setViewportRaw self viewport.x viewport.y viewport.w viewport.h
    viewport.minDepth viewport.maxDepth

@[extern "lean_sdl_gpu_set_scissor"]
private opaque setScissorRaw (self : @& RenderPass) (x y w h : Int32) : IO Unit

/-- Set the current scissor rectangle. C: `SDL_SetGPUScissor`. -/
def setScissor (self : @& RenderPass) (rect : Sdl.Rect) : IO Unit :=
  setScissorRaw self rect.x rect.y rect.w rect.h

@[extern "lean_sdl_gpu_set_blend_constants"]
private opaque setBlendConstantsRaw (self : @& RenderPass) (r g b a : Float32) : IO Unit

/-- Set the current blend constant color (for CONSTANT_COLOR blend factors).
C: `SDL_SetGPUBlendConstants`. -/
def setBlendConstants (self : @& RenderPass) (color : Sdl.FColor) : IO Unit :=
  setBlendConstantsRaw self color.r color.g color.b color.a

/-- Set the current stencil reference value. C: `SDL_SetGPUStencilReference`. -/
@[extern "lean_sdl_gpu_set_stencil_reference"]
opaque setStencilReference (self : @& RenderPass) (reference : UInt8) : IO Unit

@[extern "lean_sdl_gpu_bind_vertex_buffers"]
private opaque bindVertexBuffersRaw (self : @& RenderPass) (firstSlot : UInt32)
    (buffers : @& Array Buffer) (offsets : @& ByteArray) : IO Unit

/-- Bind vertex buffers starting at `firstSlot`. C: `SDL_BindGPUVertexBuffers`. -/
def bindVertexBuffers (self : @& RenderPass) (firstSlot : UInt32)
    (bindings : Array BufferBinding) : IO Unit :=
  bindVertexBuffersRaw self firstSlot (bindings.map (·.buffer)) (packBufferOffsets bindings)

@[extern "lean_sdl_gpu_bind_index_buffer"]
private opaque bindIndexBufferRaw (self : @& RenderPass) (buffer : @& Buffer)
    (offset elementSize : UInt32) : IO Unit

/-- Bind an index buffer. C: `SDL_BindGPUIndexBuffer`. -/
def bindIndexBuffer (self : @& RenderPass) (binding : BufferBinding)
    (elementSize : IndexElementSize) : IO Unit :=
  bindIndexBufferRaw self binding.buffer binding.offset elementSize.val

@[extern "lean_sdl_gpu_bind_vertex_samplers"]
private opaque bindVertexSamplersRaw (self : @& RenderPass) (firstSlot : UInt32)
    (textures : @& Array Texture) (samplers : @& Array Sampler) : IO Unit

/-- Bind texture-sampler pairs for the vertex shader. C:
`SDL_BindGPUVertexSamplers`. -/
def bindVertexSamplers (self : @& RenderPass) (firstSlot : UInt32)
    (bindings : Array TextureSamplerBinding) : IO Unit :=
  bindVertexSamplersRaw self firstSlot (bindings.map (·.texture)) (bindings.map (·.sampler))

/-- Bind storage textures for the vertex shader. C:
`SDL_BindGPUVertexStorageTextures`. -/
@[extern "lean_sdl_gpu_bind_vertex_storage_textures"]
opaque bindVertexStorageTextures (self : @& RenderPass) (firstSlot : UInt32)
    (textures : @& Array Texture) : IO Unit

/-- Bind storage buffers for the vertex shader. C:
`SDL_BindGPUVertexStorageBuffers`. -/
@[extern "lean_sdl_gpu_bind_vertex_storage_buffers"]
opaque bindVertexStorageBuffers (self : @& RenderPass) (firstSlot : UInt32)
    (buffers : @& Array Buffer) : IO Unit

@[extern "lean_sdl_gpu_bind_fragment_samplers"]
private opaque bindFragmentSamplersRaw (self : @& RenderPass) (firstSlot : UInt32)
    (textures : @& Array Texture) (samplers : @& Array Sampler) : IO Unit

/-- Bind texture-sampler pairs for the fragment shader. C:
`SDL_BindGPUFragmentSamplers`. -/
def bindFragmentSamplers (self : @& RenderPass) (firstSlot : UInt32)
    (bindings : Array TextureSamplerBinding) : IO Unit :=
  bindFragmentSamplersRaw self firstSlot (bindings.map (·.texture)) (bindings.map (·.sampler))

/-- Bind storage textures for the fragment shader. C:
`SDL_BindGPUFragmentStorageTextures`. -/
@[extern "lean_sdl_gpu_bind_fragment_storage_textures"]
opaque bindFragmentStorageTextures (self : @& RenderPass) (firstSlot : UInt32)
    (textures : @& Array Texture) : IO Unit

/-- Bind storage buffers for the fragment shader. C:
`SDL_BindGPUFragmentStorageBuffers`. -/
@[extern "lean_sdl_gpu_bind_fragment_storage_buffers"]
opaque bindFragmentStorageBuffers (self : @& RenderPass) (firstSlot : UInt32)
    (buffers : @& Array Buffer) : IO Unit

/-- Draw primitives using the bound graphics state. C: `SDL_DrawGPUPrimitives`. -/
@[extern "lean_sdl_gpu_draw_primitives"]
opaque drawPrimitives (self : @& RenderPass) (numVertices : UInt32)
    (numInstances : UInt32 := 1) (firstVertex : UInt32 := 0) (firstInstance : UInt32 := 0) :
    IO Unit

/-- Draw indexed primitives using the bound graphics state and index buffer.
C: `SDL_DrawGPUIndexedPrimitives`. -/
@[extern "lean_sdl_gpu_draw_indexed_primitives"]
opaque drawIndexedPrimitives (self : @& RenderPass) (numIndices : UInt32)
    (numInstances : UInt32 := 1) (firstIndex : UInt32 := 0) (vertexOffset : Int32 := 0)
    (firstInstance : UInt32 := 0) : IO Unit

/-- Draw with parameters read from a buffer of tightly-packed
`IndirectDrawCommand`s. C: `SDL_DrawGPUPrimitivesIndirect`. -/
@[extern "lean_sdl_gpu_draw_primitives_indirect"]
opaque drawPrimitivesIndirect (self : @& RenderPass) (buffer : @& Buffer)
    (offset drawCount : UInt32) : IO Unit

/-- Draw indexed with parameters read from a buffer of tightly-packed
`IndexedIndirectDrawCommand`s. C: `SDL_DrawGPUIndexedPrimitivesIndirect`. -/
@[extern "lean_sdl_gpu_draw_indexed_primitives_indirect"]
opaque drawIndexedPrimitivesIndirect (self : @& RenderPass) (buffer : @& Buffer)
    (offset drawCount : UInt32) : IO Unit

/-- End the render pass, consuming it (later use throws). Named `finish`
because `end` is a Lean keyword. C: `SDL_EndGPURenderPass`. -/
@[extern "lean_sdl_gpu_render_pass_finish"]
opaque finish (self : @& RenderPass) : IO Unit

end RenderPass

/-! ## Compute pass -/

/-- A read-write storage-texture binding for a compute pass. C:
`SDL_GPUStorageTextureReadWriteBinding`. -/
structure StorageTextureReadWriteBinding where
  /-- The texture to bind (COMPUTE_STORAGE_WRITE or SIMULTANEOUS_READ_WRITE). -/
  texture : Texture
  /-- The mip level index to bind. -/
  mipLevel : UInt32 := 0
  /-- The layer index to bind. -/
  layer : UInt32 := 0
  /-- Cycle the texture if it is already bound. -/
  cycle : Bool := false

/-- A read-write storage-buffer binding for a compute pass. C:
`SDL_GPUStorageBufferReadWriteBinding`. -/
structure StorageBufferReadWriteBinding where
  /-- The buffer to bind (must have the COMPUTE_STORAGE_WRITE usage). -/
  buffer : Buffer
  /-- Cycle the buffer if it is already bound. -/
  cycle : Bool := false

/-- Our private per-storage-texture scalar blob (stride 12; assembled into an
`SDL_GPUStorageTextureReadWriteBinding` C-side): `mip u32@0, layer u32@4, cycle
u8@8, pad@9..11`. -/
private def packComputeTextureScalars (bs : Array StorageTextureReadWriteBinding) :
    ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (bs.size * 12)
  for x in bs do
    b := pushU32 b x.mipLevel
    b := pushU32 b x.layer
    b := pushBool b x.cycle
    b := pushZeros b 3
  return b

/-- Our private per-storage-buffer cycle blob (stride 1: `cycle u8` per buffer). -/
private def packComputeBufferCycles (bs : Array StorageBufferReadWriteBinding) :
    ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity bs.size
  for x in bs do
    b := pushBool b x.cycle
  return b

namespace CommandBuffer

@[extern "lean_sdl_gpu_begin_compute_pass"]
private opaque beginComputePassRaw (self : @& CommandBuffer) (textures : @& Array Texture)
    (textureScalars : @& ByteArray) (buffers : @& Array Buffer) (bufferCycles : @& ByteArray) :
    IO ComputePass

/-- Begin a compute pass with the given read-write storage-texture and
storage-buffer bindings. All compute-pipeline work happens inside the pass; it
must be finished (`ComputePass.finish`) before beginning another pass or
submitting. Throws on failure. C: `SDL_BeginGPUComputePass`. -/
def beginComputePass (self : @& CommandBuffer)
    (storageTextureBindings : Array StorageTextureReadWriteBinding := #[])
    (storageBufferBindings : Array StorageBufferReadWriteBinding := #[]) : IO ComputePass :=
  beginComputePassRaw self (storageTextureBindings.map (·.texture))
    (packComputeTextureScalars storageTextureBindings)
    (storageBufferBindings.map (·.buffer))
    (packComputeBufferCycles storageBufferBindings)

end CommandBuffer

namespace ComputePass

/-- Bind a compute pipeline for subsequent dispatches. C:
`SDL_BindGPUComputePipeline`. -/
@[extern "lean_sdl_gpu_compute_bind_pipeline"]
opaque bindPipeline (self : @& ComputePass) (pipeline : @& ComputePipeline) : IO Unit

@[extern "lean_sdl_gpu_bind_compute_samplers"]
private opaque bindSamplersRaw (self : @& ComputePass) (firstSlot : UInt32)
    (textures : @& Array Texture) (samplers : @& Array Sampler) : IO Unit

/-- Bind texture-sampler pairs for the compute shader. C:
`SDL_BindGPUComputeSamplers`. -/
def bindSamplers (self : @& ComputePass) (firstSlot : UInt32)
    (bindings : Array TextureSamplerBinding) : IO Unit :=
  bindSamplersRaw self firstSlot (bindings.map (·.texture)) (bindings.map (·.sampler))

/-- Bind readonly storage textures for the compute shader. C:
`SDL_BindGPUComputeStorageTextures`. -/
@[extern "lean_sdl_gpu_bind_compute_storage_textures"]
opaque bindStorageTextures (self : @& ComputePass) (firstSlot : UInt32)
    (textures : @& Array Texture) : IO Unit

/-- Bind readonly storage buffers for the compute shader. C:
`SDL_BindGPUComputeStorageBuffers`. -/
@[extern "lean_sdl_gpu_bind_compute_storage_buffers"]
opaque bindStorageBuffers (self : @& ComputePass) (firstSlot : UInt32)
    (buffers : @& Array Buffer) : IO Unit

/-- Dispatch compute work over the given workgroup counts. C:
`SDL_DispatchGPUCompute`. -/
@[extern "lean_sdl_gpu_dispatch"]
opaque dispatch (self : @& ComputePass) (groupcountX groupcountY groupcountZ : UInt32) :
    IO Unit

/-- Dispatch compute work with parameters read from a buffer (one
`IndirectDispatchCommand`). C: `SDL_DispatchGPUComputeIndirect`. -/
@[extern "lean_sdl_gpu_dispatch_indirect"]
opaque dispatchIndirect (self : @& ComputePass) (buffer : @& Buffer) (offset : UInt32) :
    IO Unit

/-- End the compute pass, consuming it (later use throws). Named `finish`
because `end` is a Lean keyword. C: `SDL_EndGPUComputePass`. -/
@[extern "lean_sdl_gpu_compute_pass_finish"]
opaque finish (self : @& ComputePass) : IO Unit

end ComputePass

end Sdl.Gpu

end
