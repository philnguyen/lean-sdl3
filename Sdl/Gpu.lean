module

public import Sdl.Gpu.Enums
public meta import Sdl.Gpu.Enums
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Properties
public meta import Sdl.Properties
public import Sdl.Video
public meta import Sdl.Video
public import Sdl.Pixels
public meta import Sdl.Pixels
public import Sdl.Rect
public meta import Sdl.Rect
public import Sdl.Surface
public meta import Sdl.Surface

public section

/-!
# GPU core (`SDL_gpu.h`)

The device / resource / transfer / copy-pass / fence / swapchain half of the
SDL3 GPU API (namespace `Sdl.Gpu`; type names drop the C `GPU` prefix, so
`Gpu.Texture` is a distinct type from render's `Sdl.Texture`). Shaders,
graphics/compute pipelines and render/compute passes live in
`Sdl/Gpu/Pipeline.lean` (a later module). Enums and flags are in
`Sdl/Gpu/Enums.lean`.

## Ownership

* `Device` — **owned root**, finalizer-only (`SDL_DestroyGPUDevice`). Every
  child holds an owned reference to the device external, so reference-count
  ordering guarantees the device is destroyed last.
* `Buffer` / `TransferBuffer` / `Texture` / `Sampler` / `Fence` — **owned
  children** `{ptr, deviceExternal}`. The finalizer calls the matching
  `SDL_ReleaseGPU*(device, ptr)` then decrements the device ref; a manual
  `release` is exposed (leaf resources), NULLing the pointer so later use
  throws and the finalizer skips.
* `CommandBuffer` — **consumable** `{ptr, deviceExternal}`. The finalizer only
  decrements the device ref (never submit/cancel from a finalizer — those are
  thread-sensitive; a dropped, unsubmitted command buffer is leaked back to
  SDL's pool, which is documented SDL behavior). `submit`,
  `submitAndAcquireFence` and `cancel` NULL the pointer **unconditionally**
  (SDL makes the command buffer invalid to reuse either way) and then throw on
  a false result.
* `CopyPass` — **consumable** `{ptr, commandBufferExternal}`; `finish` (C
  `SDL_EndGPUCopyPass`; `end` is a Lean keyword) NULLs the pointer.
* Swapchain `Texture` — a **borrowed** `Texture` handle backed by a distinct
  external class `{ptr, commandBufferExternal}`. `release` / `setName` throw on
  it. It is only valid until its command buffer is submitted or canceled
  (documented cross-handle staleness); canceling a command buffer after
  acquiring a swapchain texture is an SDL error.

## Headless behavior

There is **no SDL_GPU backend under the dummy video driver**, so `createDevice`
throws "No supported SDL_GPU backend found!". Driver *enumeration*
(`getNumDrivers` / `getDriver`) and the device-free `TextureFormat` helpers
still work with no device and without `SDL_Init`.

## Skipped

* `SDL_MapGPUTransferBuffer` / `SDL_UnmapGPUTransferBuffer` — subsumed by the
  bounds-checked `TransferBuffer.write` / `TransferBuffer.read` wrappers below.
  Raw map/unmap is not exposed (SDL does not bounds-check the mapped pointer;
  an overrun is heap corruption).
* `SDL_GDKSuspendGPU` / `SDL_GDKResumeGPU` — GDK-only.
* `SDL_GPUVulkanOptions` device-create option struct — Vulkan-specific
  (macOS = Metal).
-/

namespace Sdl.Gpu

/-- A GPU context: the root object owning all GPU resources. Owned root,
finalizer-only (`SDL_DestroyGPUDevice`). C: `SDL_GPUDevice`. -/
sdl_opaque Device

/-- A GPU buffer (vertex/index/storage/indirect data). Owned child of its
`Device`. C: `SDL_GPUBuffer`. -/
sdl_opaque Buffer

/-- The external handle underlying a `TransferBuffer`. Owned child of its
`Device`. Not exposed directly — use `TransferBuffer`, whose bounds-checking
`write`/`read` guard the mapped pointer. C: `SDL_GPUTransferBuffer`. -/
sdl_opaque TransferBufferHandle

/-- A GPU texture. Owned child of its `Device`, unless it is a swapchain
texture (a *borrowed* handle whose `release`/`setName` throw). C:
`SDL_GPUTexture`. -/
sdl_opaque Texture

/-- A GPU sampler describing how a texture is read. Owned child of its
`Device`. C: `SDL_GPUSampler`. -/
sdl_opaque Sampler

/-- A synchronization fence signaled when a submitted command buffer finishes.
Owned child of its `Device`. C: `SDL_GPUFence`. -/
sdl_opaque Fence

/-- A command buffer collecting GPU work for batch submission. Consumable:
`submit`/`submitAndAcquireFence`/`cancel` consume it. C: `SDL_GPUCommandBuffer`. -/
sdl_opaque CommandBuffer

/-- A copy pass for buffer/texture transfers and copies, opened on a command
buffer. Consumable: `finish` ends it. C: `SDL_GPUCopyPass`. -/
sdl_opaque CopyPass

/-- A transfer buffer plus its fixed byte capacity. `write`/`read` bounds-check
against `size` on the Lean side before touching the mapped pointer (SDL does
not bounds-check it). C: `SDL_GPUTransferBuffer`. -/
structure TransferBuffer where
  /-- The underlying transfer-buffer external. -/
  private handle : TransferBufferHandle
  /-- Total capacity in bytes, fixed at creation. -/
  size : UInt32

instance : Nonempty TransferBuffer := ⟨⟨Classical.ofNonempty, 0⟩⟩

/-- A swapchain texture acquired from a command buffer, with its dimensions.
The `texture` is a borrowed handle valid only until the command buffer is
submitted or canceled. -/
structure SwapchainTexture where
  /-- The borrowed swapchain texture (do not `release` or `setName` it). -/
  texture : Texture
  /-- Swapchain texture width in pixels. -/
  width : UInt32
  /-- Swapchain texture height in pixels. -/
  height : UInt32

/-- Maker called from C to hand a `SwapchainTexture` back to Lean. -/
@[export lean_sdl_mk_gpu_swapchain_texture]
private def mkSwapchainTexture (texture : Texture) (width height : UInt32) :
    SwapchainTexture :=
  { texture, width, height }

/-! ## Create-info and location/region structures

Plain Lean structures with C-zero-ish defaults. Their public wrappers unpack
them to raw externs taking only flattened scalars (and external objects); C
never learns the Lean struct layout. -/

/-- Parameters for `Device.createTexture`. C: `SDL_GPUTextureCreateInfo`
(the `props` extension field is passed as 0). -/
structure TextureCreateInfo where
  /-- The base dimensionality of the texture. -/
  type : TextureType := .d2
  /-- The pixel format of the texture. -/
  format : TextureFormat
  /-- How the texture is intended to be used by the client. -/
  usage : TextureUsageFlags
  /-- The width of the texture. -/
  width : UInt32
  /-- The height of the texture. -/
  height : UInt32
  /-- Layer count (2D array / cube) or depth (3D). -/
  layerCountOrDepth : UInt32 := 1
  /-- The number of mip levels. -/
  numLevels : UInt32 := 1
  /-- Samples per texel (only for render targets). -/
  sampleCount : SampleCount := .x1

/-- Parameters for `Device.createSampler`. C: `SDL_GPUSamplerCreateInfo`
(the `props` extension field is passed as 0; `padding*` are internal). All
defaults are the C zero value. -/
structure SamplerCreateInfo where
  /-- The minification filter. -/
  minFilter : Filter := .nearest
  /-- The magnification filter. -/
  magFilter : Filter := .nearest
  /-- The mipmap filter. -/
  mipmapMode : SamplerMipmapMode := .nearest
  /-- Addressing mode for U coordinates outside [0, 1). -/
  addressModeU : SamplerAddressMode := .«repeat»
  /-- Addressing mode for V coordinates outside [0, 1). -/
  addressModeV : SamplerAddressMode := .«repeat»
  /-- Addressing mode for W coordinates outside [0, 1). -/
  addressModeW : SamplerAddressMode := .«repeat»
  /-- Bias added to mipmap LOD calculation. -/
  mipLodBias : Float32 := 0
  /-- Anisotropy clamp (ignored unless `enableAnisotropy`). -/
  maxAnisotropy : Float32 := 0
  /-- Comparison operator applied before filtering. -/
  compareOp : CompareOp := .invalid
  /-- Minimum clamp of the computed LOD. -/
  minLod : Float32 := 0
  /-- Maximum clamp of the computed LOD. -/
  maxLod : Float32 := 0
  /-- Enable anisotropic filtering. -/
  enableAnisotropy : Bool := false
  /-- Enable comparison against a reference value during lookups. -/
  enableCompare : Bool := false

/-- A region of a texture used in a blit. C: `SDL_GPUBlitRegion`. -/
structure BlitRegion where
  /-- The texture. -/
  texture : Texture
  /-- The mip level index of the region. -/
  mipLevel : UInt32 := 0
  /-- The layer index (2D array/cube) or depth plane (3D) of the region. -/
  layerOrDepthPlane : UInt32 := 0
  /-- The left offset of the region. -/
  x : UInt32 := 0
  /-- The top offset of the region. -/
  y : UInt32 := 0
  /-- The width of the region. -/
  w : UInt32
  /-- The height of the region. -/
  h : UInt32

/-- Parameters for `CommandBuffer.blitTexture`. C: `SDL_GPUBlitInfo`. -/
structure BlitInfo where
  /-- The source region for the blit. -/
  source : BlitRegion
  /-- The destination region for the blit. -/
  destination : BlitRegion
  /-- What is done with the destination contents before the blit. -/
  loadOp : LoadOp := .load
  /-- The color to clear the destination to (only if `loadOp` is `.clear`). -/
  clearColor : Sdl.FColor := ⟨0, 0, 0, 0⟩
  /-- The flip mode for the source region. -/
  flipMode : Sdl.FlipMode := .none
  /-- The filter mode used when blitting. -/
  filter : Filter := .nearest
  /-- Whether to cycle the destination texture if it is already bound. -/
  cycle : Bool := false

/-- A location in a transfer buffer. C: `SDL_GPUTransferBufferLocation`. -/
structure TransferBufferLocation where
  /-- The transfer buffer. -/
  buffer : TransferBuffer
  /-- The starting byte in the transfer buffer. -/
  offset : UInt32 := 0

/-- A location in a buffer. C: `SDL_GPUBufferLocation`. -/
structure BufferLocation where
  /-- The buffer. -/
  buffer : Buffer
  /-- The starting byte within the buffer. -/
  offset : UInt32 := 0

/-- A region of a buffer. C: `SDL_GPUBufferRegion`. -/
structure BufferRegion where
  /-- The buffer. -/
  buffer : Buffer
  /-- The starting byte within the buffer. -/
  offset : UInt32 := 0
  /-- The size in bytes of the region. -/
  size : UInt32

/-- A location in a texture. C: `SDL_GPUTextureLocation`. -/
structure TextureLocation where
  /-- The texture. -/
  texture : Texture
  /-- The mip level index of the location. -/
  mipLevel : UInt32 := 0
  /-- The layer index of the location. -/
  layer : UInt32 := 0
  /-- The left offset of the location. -/
  x : UInt32 := 0
  /-- The top offset of the location. -/
  y : UInt32 := 0
  /-- The front offset of the location. -/
  z : UInt32 := 0

/-- A region of a texture. C: `SDL_GPUTextureRegion`. -/
structure TextureRegion where
  /-- The texture. -/
  texture : Texture
  /-- The mip level index to transfer. -/
  mipLevel : UInt32 := 0
  /-- The layer index to transfer. -/
  layer : UInt32 := 0
  /-- The left offset of the region. -/
  x : UInt32 := 0
  /-- The top offset of the region. -/
  y : UInt32 := 0
  /-- The front offset of the region. -/
  z : UInt32 := 0
  /-- The width of the region. -/
  w : UInt32
  /-- The height of the region. -/
  h : UInt32
  /-- The depth of the region. -/
  d : UInt32 := 1

/-- Image-data layout in a transfer buffer for a texture transfer.
C: `SDL_GPUTextureTransferInfo`. -/
structure TextureTransferInfo where
  /-- The transfer buffer used in the transfer. -/
  buffer : TransferBuffer
  /-- The starting byte of the image data in the transfer buffer. -/
  offset : UInt32 := 0
  /-- The number of pixels from one row to the next (0 = tightly packed). -/
  pixelsPerRow : UInt32 := 0
  /-- The number of rows from one layer/depth-slice to the next (0 = packed). -/
  rowsPerLayer : UInt32 := 0

@[extern "lean_sdl_gpu_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Top-level -/

@[extern "lean_sdl_gpu_supports_shader_formats"]
private opaque supportsShaderFormatsRaw (formats : UInt32) (name : Option String) : IO Bool

/-- Whether a GPU backend supporting all of `formats` (optionally the named
driver) is available. Works with no device. C: `SDL_GPUSupportsShaderFormats`. -/
def supportsShaderFormats (formats : ShaderFormat) (name : Option String := none) :
    IO Bool :=
  supportsShaderFormatsRaw formats.val name

/-- Whether a GPU backend supporting the given create properties is available.
C: `SDL_GPUSupportsProperties`. -/
@[extern "lean_sdl_gpu_supports_properties"]
opaque supportsProperties (props : @& Sdl.Properties) : IO Bool

@[extern "lean_sdl_gpu_create_device"]
private opaque createDeviceRaw (formatFlags : UInt32) (debugMode : Bool)
    (name : Option String) : IO Device

/-- Create a GPU device supporting shader `formatFlags`. `name` selects a
specific driver (e.g. `"metal"`), or picks the best available if `none`.
Throws if no supported backend is found (always the case under the dummy video
driver). C: `SDL_CreateGPUDevice`. -/
def createDevice (formatFlags : ShaderFormat) (debugMode : Bool := false)
    (name : Option String := none) : IO Device :=
  createDeviceRaw formatFlags.val debugMode name

/-- Create a GPU device from a properties bag (see the `Props` namespace).
Throws on failure. C: `SDL_CreateGPUDeviceWithProperties`. -/
@[extern "lean_sdl_gpu_create_device_with_properties"]
opaque createDeviceWithProperties (props : @& Sdl.Properties) : IO Device

/-- The number of GPU drivers compiled into SDL. C: `SDL_GetNumGPUDrivers`. -/
@[extern "lean_sdl_gpu_get_num_drivers"]
opaque getNumDrivers : IO Int32

/-- The name of the built-in GPU driver at `index` (e.g. `"metal"`,
`"vulkan"`). Throws if `index` is out of range. C: `SDL_GetGPUDriver`. -/
@[extern "lean_sdl_gpu_get_driver"]
opaque getDriver (index : Int32) : IO String

/-- The names of all built-in GPU drivers. Convenience loop over
`getNumDrivers` / `getDriver`. -/
def getDrivers : IO (Array String) := do
  let n ← getNumDrivers
  let mut drivers := #[]
  for i in [0:n.toNatClampNeg] do
    drivers := drivers.push (← getDriver (Int32.ofNat i))
  return drivers

namespace Device

/-- The name of the driver backing this device. C: `SDL_GetGPUDeviceDriver`. -/
@[extern "lean_sdl_gpu_device_get_driver"]
opaque getDriver (self : @& Device) : IO String

@[extern "lean_sdl_gpu_get_shader_formats"]
private opaque getShaderFormatsRaw (self : @& Device) : IO UInt32

/-- The shader formats supported by this device. C: `SDL_GetGPUShaderFormats`. -/
def getShaderFormats (self : @& Device) : IO ShaderFormat := do
  return ⟨← getShaderFormatsRaw self⟩

/-- The device's properties (borrowed; its lifetime is tied to the device).
C: `SDL_GetGPUDeviceProperties`. -/
@[extern "lean_sdl_gpu_get_device_properties"]
opaque getProperties (self : @& Device) : IO Sdl.Properties

@[extern "lean_sdl_gpu_create_buffer"]
private opaque createBufferRaw (self : @& Device) (usage : UInt32) (size : UInt32) : IO Buffer

/-- Create a GPU buffer of `size` bytes with the given `usage`. The C `props`
field is passed as 0. Throws on failure. C: `SDL_CreateGPUBuffer`. -/
def createBuffer (self : @& Device) (usage : BufferUsageFlags) (size : UInt32) : IO Buffer :=
  createBufferRaw self usage.val size

@[extern "lean_sdl_gpu_create_transfer_buffer"]
private opaque createTransferBufferRaw (self : @& Device) (usage : UInt32) (size : UInt32) :
    IO TransferBufferHandle

/-- Create a transfer buffer of `size` bytes with the given `usage`. Throws on
failure. C: `SDL_CreateGPUTransferBuffer`. -/
def createTransferBuffer (self : @& Device) (usage : TransferBufferUsage) (size : UInt32) :
    IO TransferBuffer := do
  let handle ← createTransferBufferRaw self usage.val size
  return { handle, size }

@[extern "lean_sdl_gpu_create_texture"]
private opaque createTextureRaw (self : @& Device) (type format usage : UInt32)
    (width height layerCountOrDepth numLevels : UInt32) (sampleCount : UInt32) : IO Texture

/-- Create a texture from `info`. The C `props` field is passed as 0. Throws on
failure. C: `SDL_CreateGPUTexture`. -/
def createTexture (self : @& Device) (info : TextureCreateInfo) : IO Texture :=
  createTextureRaw self info.type.val info.format.val info.usage.val
    info.width info.height info.layerCountOrDepth info.numLevels info.sampleCount.val

@[extern "lean_sdl_gpu_create_sampler"]
private opaque createSamplerRaw (self : @& Device)
    (minFilter magFilter mipmapMode addressModeU addressModeV addressModeW : UInt32)
    (mipLodBias maxAnisotropy : Float32) (compareOp : UInt32) (minLod maxLod : Float32)
    (enableAnisotropy enableCompare : Bool) : IO Sampler

/-- Create a sampler from `info`. The C `props` field is passed as 0. Throws on
failure. C: `SDL_CreateGPUSampler`. -/
def createSampler (self : @& Device) (info : SamplerCreateInfo := {}) : IO Sampler :=
  createSamplerRaw self info.minFilter.val info.magFilter.val info.mipmapMode.val
    info.addressModeU.val info.addressModeV.val info.addressModeW.val
    info.mipLodBias info.maxAnisotropy info.compareOp.val info.minLod info.maxLod
    info.enableAnisotropy info.enableCompare

/-- Acquire a command buffer to record GPU work. Throws on failure.
C: `SDL_AcquireGPUCommandBuffer`. -/
@[extern "lean_sdl_gpu_acquire_command_buffer"]
opaque acquireCommandBuffer (self : @& Device) : IO CommandBuffer

/-- Claim a window so its swapchain can be used with this device. Throws on
failure. C: `SDL_ClaimWindowForGPUDevice`. -/
@[extern "lean_sdl_gpu_claim_window"]
opaque claimWindow (self : @& Device) (window : @& Sdl.Window) : IO Unit

/-- Unclaim a window previously claimed with `claimWindow`.
C: `SDL_ReleaseWindowFromGPUDevice`. -/
@[extern "lean_sdl_gpu_release_window"]
opaque releaseWindow (self : @& Device) (window : @& Sdl.Window) : IO Unit

@[extern "lean_sdl_gpu_window_supports_swapchain_composition"]
private opaque windowSupportsSwapchainCompositionRaw (self : @& Device)
    (window : @& Sdl.Window) (composition : UInt32) : IO Bool

/-- Whether the window's swapchain supports the given composition.
C: `SDL_WindowSupportsGPUSwapchainComposition`. -/
def windowSupportsSwapchainComposition (self : @& Device) (window : @& Sdl.Window)
    (composition : SwapchainComposition) : IO Bool :=
  windowSupportsSwapchainCompositionRaw self window composition.val

@[extern "lean_sdl_gpu_window_supports_present_mode"]
private opaque windowSupportsPresentModeRaw (self : @& Device) (window : @& Sdl.Window)
    (mode : UInt32) : IO Bool

/-- Whether the window's swapchain supports the given present mode.
C: `SDL_WindowSupportsGPUPresentMode`. -/
def windowSupportsPresentMode (self : @& Device) (window : @& Sdl.Window)
    (mode : PresentMode) : IO Bool :=
  windowSupportsPresentModeRaw self window mode.val

@[extern "lean_sdl_gpu_set_swapchain_parameters"]
private opaque setSwapchainParametersRaw (self : @& Device) (window : @& Sdl.Window)
    (composition mode : UInt32) : IO Unit

/-- Configure the window's swapchain composition and present mode. Throws on
failure. C: `SDL_SetGPUSwapchainParameters`. -/
def setSwapchainParameters (self : @& Device) (window : @& Sdl.Window)
    (composition : SwapchainComposition) (mode : PresentMode) : IO Unit :=
  setSwapchainParametersRaw self window composition.val mode.val

/-- Set the maximum number of frames that can be in flight. Throws on failure.
C: `SDL_SetGPUAllowedFramesInFlight`. -/
@[extern "lean_sdl_gpu_set_allowed_frames_in_flight"]
opaque setAllowedFramesInFlight (self : @& Device) (frames : UInt32) : IO Unit

@[extern "lean_sdl_gpu_get_swapchain_texture_format"]
private opaque getSwapchainTextureFormatRaw (self : @& Device) (window : @& Sdl.Window) :
    IO UInt32

/-- The texture format of the window's swapchain. C:
`SDL_GetGPUSwapchainTextureFormat`. -/
def getSwapchainTextureFormat (self : @& Device) (window : @& Sdl.Window) :
    IO TextureFormat := do
  return TextureFormat.ofVal (← getSwapchainTextureFormatRaw self window)

/-- Block until the window's swapchain is ready for another acquire. Throws on
failure. C: `SDL_WaitForGPUSwapchain`. -/
@[extern "lean_sdl_gpu_wait_for_swapchain"]
opaque waitForSwapchain (self : @& Device) (window : @& Sdl.Window) : IO Unit

/-- Block until all pending GPU work on this device is complete. Throws on
failure. C: `SDL_WaitForGPUIdle`. -/
@[extern "lean_sdl_gpu_wait_for_idle"]
opaque waitForIdle (self : @& Device) : IO Unit

/-- Block until the fences are signaled (`waitAll`: all vs. any). Throws on
failure. C: `SDL_WaitForGPUFences`. -/
@[extern "lean_sdl_gpu_wait_for_fences"]
opaque waitForFences (self : @& Device) (waitAll : Bool) (fences : @& Array Fence) : IO Unit

@[extern "lean_sdl_gpu_texture_supports_format"]
private opaque textureSupportsFormatRaw (self : @& Device) (format type usage : UInt32) :
    IO Bool

/-- Whether the device supports a texture `format` for the given `type` and
`usage`. C: `SDL_GPUTextureSupportsFormat`. -/
def textureSupportsFormat (self : @& Device) (format : TextureFormat) (type : TextureType)
    (usage : TextureUsageFlags) : IO Bool :=
  textureSupportsFormatRaw self format.val type.val usage.val

@[extern "lean_sdl_gpu_texture_supports_sample_count"]
private opaque textureSupportsSampleCountRaw (self : @& Device) (format sampleCount : UInt32) :
    IO Bool

/-- Whether the device supports `sampleCount` samples for a texture `format`.
C: `SDL_GPUTextureSupportsSampleCount`. -/
def textureSupportsSampleCount (self : @& Device) (format : TextureFormat)
    (sampleCount : SampleCount) : IO Bool :=
  textureSupportsSampleCountRaw self format.val sampleCount.val

end Device

/-! ## Resource methods -/

/-- Set a debug name on a buffer (debug builds). C: `SDL_SetGPUBufferName`. -/
@[extern "lean_sdl_gpu_set_buffer_name"]
opaque Buffer.setName (self : @& Buffer) (name : @& String) : IO Unit

/-- Release the buffer immediately (rather than at finalization). Later use
throws. C: `SDL_ReleaseGPUBuffer`. -/
@[extern "lean_sdl_gpu_release_buffer"]
opaque Buffer.release (self : @& Buffer) : IO Unit

/-- Set a debug name on a texture (debug builds). Throws on a swapchain
texture. C: `SDL_SetGPUTextureName`. -/
@[extern "lean_sdl_gpu_set_texture_name"]
opaque Texture.setName (self : @& Texture) (name : @& String) : IO Unit

/-- Release the texture immediately. Throws on a swapchain texture (SDL owns
it). Later use throws. C: `SDL_ReleaseGPUTexture`. -/
@[extern "lean_sdl_gpu_release_texture"]
opaque Texture.release (self : @& Texture) : IO Unit

/-- Release the sampler immediately. Later use throws.
C: `SDL_ReleaseGPUSampler`. -/
@[extern "lean_sdl_gpu_release_sampler"]
opaque Sampler.release (self : @& Sampler) : IO Unit

/-- Release the fence immediately. Later use throws. C: `SDL_ReleaseGPUFence`. -/
@[extern "lean_sdl_gpu_release_fence"]
opaque Fence.release (self : @& Fence) : IO Unit

/-- Whether the fence is signaled (non-blocking poll). C: `SDL_QueryGPUFence`. -/
@[extern "lean_sdl_gpu_query_fence"]
opaque Fence.query (self : @& Fence) : IO Bool

namespace TransferBuffer

/-- Release the transfer buffer immediately. Later use throws.
C: `SDL_ReleaseGPUTransferBuffer`. -/
@[extern "lean_sdl_gpu_release_transfer_buffer"]
private opaque releaseRaw (handle : @& TransferBufferHandle) : IO Unit

/-- Release the transfer buffer immediately. Later use throws.
C: `SDL_ReleaseGPUTransferBuffer`. -/
def release (self : @& TransferBuffer) : IO Unit :=
  releaseRaw self.handle

@[extern "lean_sdl_gpu_transfer_buffer_write"]
private opaque writeRaw (handle : @& TransferBufferHandle) (data : @& ByteArray)
    (dstOffset : UInt32) (cycle : Bool) : IO Unit

/-- Copy `data` into the transfer buffer at `dstOffset`. `cycle := true` cycles
the buffer if it is bound. Bounds-checked against the buffer's `size` before
touching the mapped pointer. Shim: map → memcpy → unmap.
C: `SDL_MapGPUTransferBuffer` + `SDL_UnmapGPUTransferBuffer`. -/
def write (self : @& TransferBuffer) (data : @& ByteArray) (dstOffset : UInt32 := 0)
    (cycle : Bool := false) : IO Unit := do
  if dstOffset.toNat + data.size > self.size.toNat then
    throw <| IO.userError s!"TransferBuffer.write: {dstOffset.toNat} + {data.size} bytes \
      exceeds buffer size {self.size}"
  writeRaw self.handle data dstOffset cycle

@[extern "lean_sdl_gpu_transfer_buffer_read"]
private opaque readRaw (handle : @& TransferBufferHandle) (offset size : UInt32) :
    IO ByteArray

/-- Read `size` bytes from the transfer buffer starting at `offset`
(`size := none` reads to the end). Bounds-checked against the buffer's `size`.
Shim: map → copy into a fresh `ByteArray` → unmap.
C: `SDL_MapGPUTransferBuffer` + `SDL_UnmapGPUTransferBuffer`. -/
def read (self : @& TransferBuffer) (offset : UInt32 := 0) (size : Option UInt32 := none) :
    IO ByteArray := do
  if offset > self.size then
    throw <| IO.userError s!"TransferBuffer.read: offset {offset} exceeds buffer size {self.size}"
  let sz := size.getD (self.size - offset)
  if offset.toNat + sz.toNat > self.size.toNat then
    throw <| IO.userError s!"TransferBuffer.read: {offset.toNat} + {sz.toNat} bytes \
      exceeds buffer size {self.size}"
  readRaw self.handle offset sz

end TransferBuffer

namespace CommandBuffer

/-- Insert a debug label at the current point in the command buffer.
C: `SDL_InsertGPUDebugLabel`. -/
@[extern "lean_sdl_gpu_insert_debug_label"]
opaque insertDebugLabel (self : @& CommandBuffer) (text : @& String) : IO Unit

/-- Begin a named debug group. Pair with `popDebugGroup`.
C: `SDL_PushGPUDebugGroup`. -/
@[extern "lean_sdl_gpu_push_debug_group"]
opaque pushDebugGroup (self : @& CommandBuffer) (name : @& String) : IO Unit

/-- End the most recently pushed debug group. C: `SDL_PopGPUDebugGroup`. -/
@[extern "lean_sdl_gpu_pop_debug_group"]
opaque popDebugGroup (self : @& CommandBuffer) : IO Unit

/-- Push uniform `data` for the vertex shader at `slot`.
C: `SDL_PushGPUVertexUniformData`. -/
@[extern "lean_sdl_gpu_push_vertex_uniform_data"]
opaque pushVertexUniformData (self : @& CommandBuffer) (slot : UInt32) (data : @& ByteArray) :
    IO Unit

/-- Push uniform `data` for the fragment shader at `slot`.
C: `SDL_PushGPUFragmentUniformData`. -/
@[extern "lean_sdl_gpu_push_fragment_uniform_data"]
opaque pushFragmentUniformData (self : @& CommandBuffer) (slot : UInt32) (data : @& ByteArray) :
    IO Unit

/-- Push uniform `data` for the compute shader at `slot`.
C: `SDL_PushGPUComputeUniformData`. -/
@[extern "lean_sdl_gpu_push_compute_uniform_data"]
opaque pushComputeUniformData (self : @& CommandBuffer) (slot : UInt32) (data : @& ByteArray) :
    IO Unit

/-- Begin a copy pass for buffer/texture transfers. C: `SDL_BeginGPUCopyPass`. -/
@[extern "lean_sdl_gpu_begin_copy_pass"]
opaque beginCopyPass (self : @& CommandBuffer) : IO CopyPass

/-- Generate mipmaps for a texture (must have the SAMPLER and COLOR_TARGET
usages). C: `SDL_GenerateMipmapsForGPUTexture`. -/
@[extern "lean_sdl_gpu_generate_mipmaps"]
opaque generateMipmaps (self : @& CommandBuffer) (texture : @& Texture) : IO Unit

@[extern "lean_sdl_gpu_blit_texture"]
private opaque blitTextureRaw (self : @& CommandBuffer)
    (srcTex : @& Texture) (srcMip srcLayerOrDepth srcX srcY srcW srcH : UInt32)
    (dstTex : @& Texture) (dstMip dstLayerOrDepth dstX dstY dstW dstH : UInt32)
    (loadOp : UInt32) (clearR clearG clearB clearA : Float32)
    (flipMode filter : UInt32) (cycle : Bool) : IO Unit

/-- Blit (copy with scaling/filtering) one texture region to another.
C: `SDL_BlitGPUTexture`. -/
def blitTexture (self : @& CommandBuffer) (info : BlitInfo) : IO Unit :=
  blitTextureRaw self
    info.source.texture info.source.mipLevel info.source.layerOrDepthPlane
      info.source.x info.source.y info.source.w info.source.h
    info.destination.texture info.destination.mipLevel info.destination.layerOrDepthPlane
      info.destination.x info.destination.y info.destination.w info.destination.h
    info.loadOp.val info.clearColor.r info.clearColor.g info.clearColor.b info.clearColor.a
    info.flipMode.val info.filter.val info.cycle

/-- Acquire the window's swapchain texture (valid only until this command
buffer is submitted/canceled). Returns `none` when no texture is available
(too many frames in flight, or the window is minimized). Throws on error.
C: `SDL_AcquireGPUSwapchainTexture`. -/
@[extern "lean_sdl_gpu_acquire_swapchain_texture"]
opaque acquireSwapchainTexture (self : @& CommandBuffer) (window : @& Sdl.Window) :
    IO (Option SwapchainTexture)

/-- Like `acquireSwapchainTexture`, but blocks until a texture is available (or
the swapchain is minimized). C: `SDL_WaitAndAcquireGPUSwapchainTexture`. -/
@[extern "lean_sdl_gpu_wait_and_acquire_swapchain_texture"]
opaque waitAndAcquireSwapchainTexture (self : @& CommandBuffer) (window : @& Sdl.Window) :
    IO (Option SwapchainTexture)

/-- Submit the command buffer's work to the GPU. Consumes the command buffer
(later use throws), even if SDL reports an error. C:
`SDL_SubmitGPUCommandBuffer`. -/
@[extern "lean_sdl_gpu_submit"]
opaque submit (self : @& CommandBuffer) : IO Unit

/-- Submit the command buffer and get a fence signaled on completion. Consumes
the command buffer (later use throws), even if SDL reports an error.
C: `SDL_SubmitGPUCommandBufferAndAcquireFence`. -/
@[extern "lean_sdl_gpu_submit_and_acquire_fence"]
opaque submitAndAcquireFence (self : @& CommandBuffer) : IO Fence

/-- Cancel the command buffer, discarding its work. Consumes the command buffer
(later use throws), even if SDL reports an error. Invalid after acquiring a
swapchain texture. C: `SDL_CancelGPUCommandBuffer`. -/
@[extern "lean_sdl_gpu_cancel"]
opaque cancel (self : @& CommandBuffer) : IO Unit

end CommandBuffer

namespace CopyPass

@[extern "lean_sdl_gpu_upload_to_texture"]
private opaque uploadToTextureRaw (self : @& CopyPass)
    (transferBuffer : @& TransferBufferHandle) (offset pixelsPerRow rowsPerLayer : UInt32)
    (texture : @& Texture) (mipLevel layer x y z w h d : UInt32) (cycle : Bool) : IO Unit

/-- Upload image data from a transfer buffer to a texture region.
C: `SDL_UploadToGPUTexture`. -/
def uploadToTexture (self : @& CopyPass) (source : TextureTransferInfo)
    (destination : TextureRegion) (cycle : Bool := false) : IO Unit :=
  uploadToTextureRaw self source.buffer.handle source.offset source.pixelsPerRow
    source.rowsPerLayer destination.texture destination.mipLevel destination.layer
    destination.x destination.y destination.z destination.w destination.h destination.d cycle

@[extern "lean_sdl_gpu_upload_to_buffer"]
private opaque uploadToBufferRaw (self : @& CopyPass)
    (transferBuffer : @& TransferBufferHandle) (srcOffset : UInt32)
    (buffer : @& Buffer) (dstOffset size : UInt32) (cycle : Bool) : IO Unit

/-- Upload data from a transfer buffer to a buffer region.
C: `SDL_UploadToGPUBuffer`. -/
def uploadToBuffer (self : @& CopyPass) (source : TransferBufferLocation)
    (destination : BufferRegion) (cycle : Bool := false) : IO Unit :=
  uploadToBufferRaw self source.buffer.handle source.offset
    destination.buffer destination.offset destination.size cycle

@[extern "lean_sdl_gpu_copy_texture_to_texture"]
private opaque copyTextureToTextureRaw (self : @& CopyPass)
    (srcTex : @& Texture) (srcMip srcLayer srcX srcY srcZ : UInt32)
    (dstTex : @& Texture) (dstMip dstLayer dstX dstY dstZ : UInt32)
    (w h d : UInt32) (cycle : Bool) : IO Unit

/-- Copy a texture region to another texture. C: `SDL_CopyGPUTextureToTexture`. -/
def copyTextureToTexture (self : @& CopyPass) (source destination : TextureLocation)
    (w h d : UInt32) (cycle : Bool := false) : IO Unit :=
  copyTextureToTextureRaw self
    source.texture source.mipLevel source.layer source.x source.y source.z
    destination.texture destination.mipLevel destination.layer
      destination.x destination.y destination.z
    w h d cycle

@[extern "lean_sdl_gpu_copy_buffer_to_buffer"]
private opaque copyBufferToBufferRaw (self : @& CopyPass)
    (srcBuf : @& Buffer) (srcOffset : UInt32)
    (dstBuf : @& Buffer) (dstOffset : UInt32) (size : UInt32) (cycle : Bool) : IO Unit

/-- Copy a buffer region to another buffer. C: `SDL_CopyGPUBufferToBuffer`. -/
def copyBufferToBuffer (self : @& CopyPass) (source destination : BufferLocation)
    (size : UInt32) (cycle : Bool := false) : IO Unit :=
  copyBufferToBufferRaw self source.buffer source.offset
    destination.buffer destination.offset size cycle

@[extern "lean_sdl_gpu_download_from_texture"]
private opaque downloadFromTextureRaw (self : @& CopyPass)
    (texture : @& Texture) (mipLevel layer x y z w h d : UInt32)
    (transferBuffer : @& TransferBufferHandle) (offset pixelsPerRow rowsPerLayer : UInt32) :
    IO Unit

/-- Download a texture region into a transfer buffer (read back after the
submitting command buffer's fence signals). C: `SDL_DownloadFromGPUTexture`. -/
def downloadFromTexture (self : @& CopyPass) (source : TextureRegion)
    (destination : TextureTransferInfo) : IO Unit :=
  downloadFromTextureRaw self source.texture source.mipLevel source.layer
    source.x source.y source.z source.w source.h source.d
    destination.buffer.handle destination.offset destination.pixelsPerRow
    destination.rowsPerLayer

@[extern "lean_sdl_gpu_download_from_buffer"]
private opaque downloadFromBufferRaw (self : @& CopyPass)
    (buffer : @& Buffer) (offset size : UInt32)
    (transferBuffer : @& TransferBufferHandle) (dstOffset : UInt32) : IO Unit

/-- Download a buffer region into a transfer buffer (read back after the
submitting command buffer's fence signals). C: `SDL_DownloadFromGPUBuffer`. -/
def downloadFromBuffer (self : @& CopyPass) (source : BufferRegion)
    (destination : TransferBufferLocation) : IO Unit :=
  downloadFromBufferRaw self source.buffer source.offset source.size
    destination.buffer.handle destination.offset

/-- End the copy pass, consuming it (later use throws). Named `finish` because
`end` is a Lean keyword. C: `SDL_EndGPUCopyPass`. -/
@[extern "lean_sdl_gpu_copy_pass_finish"]
opaque finish (self : @& CopyPass) : IO Unit

end CopyPass

namespace TextureFormat

@[extern "lean_sdl_gpu_texel_block_size"]
private opaque texelBlockSizeRaw (format : UInt32) : IO UInt32

/-- The texel-block (or byte) size of the format. Works with no device.
C: `SDL_GPUTextureFormatTexelBlockSize`. -/
def texelBlockSize (self : TextureFormat) : IO UInt32 :=
  texelBlockSizeRaw self.val

@[extern "lean_sdl_gpu_calculate_size"]
private opaque calculateSizeRaw (format width height depthOrLayerCount : UInt32) : IO UInt32

/-- The total byte size of a texture of this format and dimensions. Works with
no device. C: `SDL_CalculateGPUTextureFormatSize`. -/
def calculateSize (self : TextureFormat) (width height depthOrLayerCount : UInt32) :
    IO UInt32 :=
  calculateSizeRaw self.val width height depthOrLayerCount

@[extern "lean_sdl_gpu_pixel_format_of"]
private opaque toPixelFormatRaw (format : UInt32) : IO UInt32

/-- The `Sdl.PixelFormat` corresponding to this GPU texture format (or
`.unknown`). Works with no device. C: `SDL_GetPixelFormatFromGPUTextureFormat`. -/
def toPixelFormat (self : TextureFormat) : IO Sdl.PixelFormat := do
  return Sdl.PixelFormat.ofVal (← toPixelFormatRaw self.val)

@[extern "lean_sdl_gpu_texture_format_of_pixel"]
private opaque ofPixelFormatRaw (format : UInt32) : IO UInt32

/-- The GPU texture format corresponding to a `Sdl.PixelFormat` (or `.invalid`).
Works with no device. C: `SDL_GetGPUTextureFormatFromPixelFormat`. -/
def ofPixelFormat (format : Sdl.PixelFormat) : IO TextureFormat := do
  return TextureFormat.ofVal (← ofPixelFormatRaw format.val)

end TextureFormat

/-! ## Device-create properties

Property keys for `createDeviceWithProperties`. Values are the exact
`SDL_PROP_GPU_DEVICE_CREATE_*` strings from `SDL_gpu.h`. -/

namespace Props

/-- Enable debug mode (extra validation, slower). C:
`SDL_PROP_GPU_DEVICE_CREATE_DEBUGMODE_BOOLEAN`. -/
def debugModeBoolean : String := "SDL.gpu.device.create.debugmode"
/-- Prefer a low-power GPU. C:
`SDL_PROP_GPU_DEVICE_CREATE_PREFERLOWPOWER_BOOLEAN`. -/
def preferLowPowerBoolean : String := "SDL.gpu.device.create.preferlowpower"
/-- Automatically log verbose device info. C:
`SDL_PROP_GPU_DEVICE_CREATE_VERBOSE_BOOLEAN`. -/
def verboseBoolean : String := "SDL.gpu.device.create.verbose"
/-- The name of the GPU driver to use. C:
`SDL_PROP_GPU_DEVICE_CREATE_NAME_STRING`. -/
def nameString : String := "SDL.gpu.device.create.name"
/-- Vulkan: enable clip-distance support. C:
`SDL_PROP_GPU_DEVICE_CREATE_FEATURE_CLIP_DISTANCE_BOOLEAN`. -/
def featureClipDistanceBoolean : String := "SDL.gpu.device.create.feature.clip_distance"
/-- Vulkan: enable depth-clamping support. C:
`SDL_PROP_GPU_DEVICE_CREATE_FEATURE_DEPTH_CLAMPING_BOOLEAN`. -/
def featureDepthClampingBoolean : String := "SDL.gpu.device.create.feature.depth_clamping"
/-- Enable indirect-draw first-instance support. C:
`SDL_PROP_GPU_DEVICE_CREATE_FEATURE_INDIRECT_DRAW_FIRST_INSTANCE_BOOLEAN`. -/
def featureIndirectDrawFirstInstanceBoolean : String :=
  "SDL.gpu.device.create.feature.indirect_draw_first_instance"
/-- Vulkan: enable anisotropy support. C:
`SDL_PROP_GPU_DEVICE_CREATE_FEATURE_ANISOTROPY_BOOLEAN`. -/
def featureAnisotropyBoolean : String := "SDL.gpu.device.create.feature.anisotropy"
/-- App can provide PRIVATE-format shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_SHADERS_PRIVATE_BOOLEAN`. -/
def shadersPrivateBoolean : String := "SDL.gpu.device.create.shaders.private"
/-- App can provide SPIR-V shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_SHADERS_SPIRV_BOOLEAN`. -/
def shadersSpirvBoolean : String := "SDL.gpu.device.create.shaders.spirv"
/-- App can provide DXBC shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXBC_BOOLEAN`. -/
def shadersDxbcBoolean : String := "SDL.gpu.device.create.shaders.dxbc"
/-- App can provide DXIL shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_SHADERS_DXIL_BOOLEAN`. -/
def shadersDxilBoolean : String := "SDL.gpu.device.create.shaders.dxil"
/-- App can provide MSL shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_SHADERS_MSL_BOOLEAN`. -/
def shadersMslBoolean : String := "SDL.gpu.device.create.shaders.msl"
/-- App can provide Metal-library shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_SHADERS_METALLIB_BOOLEAN`. -/
def shadersMetallibBoolean : String := "SDL.gpu.device.create.shaders.metallib"
/-- D3D12: allow hardware with fewer resource-binding slots (Tier-1). C:
`SDL_PROP_GPU_DEVICE_CREATE_D3D12_ALLOW_FEWER_RESOURCE_SLOTS_BOOLEAN`. -/
def d3d12AllowFewerResourceSlotsBoolean : String :=
  "SDL.gpu.device.create.d3d12.allowtier1resourcebinding"
/-- D3D12: vertex-semantic prefix used by HLSL shaders. C:
`SDL_PROP_GPU_DEVICE_CREATE_D3D12_SEMANTIC_NAME_STRING`. -/
def d3d12SemanticNameString : String := "SDL.gpu.device.create.d3d12.semantic"
/-- D3D12: Agility SDK version number. C:
`SDL_PROP_GPU_DEVICE_CREATE_D3D12_AGILITY_SDK_VERSION_NUMBER`. -/
def d3d12AgilitySdkVersionNumber : String :=
  "SDL.gpu.device.create.d3d12.agility_sdk_version"
/-- D3D12: Agility SDK path. C:
`SDL_PROP_GPU_DEVICE_CREATE_D3D12_AGILITY_SDK_PATH_STRING`. -/
def d3d12AgilitySdkPathString : String := "SDL.gpu.device.create.d3d12.agility_sdk_path"
/-- Vulkan: require hardware acceleration (reject software renderers). C:
`SDL_PROP_GPU_DEVICE_CREATE_VULKAN_REQUIRE_HARDWARE_ACCELERATION_BOOLEAN`. -/
def vulkanRequireHardwareAccelerationBoolean : String :=
  "SDL.gpu.device.create.vulkan.requirehardwareacceleration"
/-- Vulkan: pointer to an `SDL_GPUVulkanOptions` struct (not bound; macOS =
Metal). C: `SDL_PROP_GPU_DEVICE_CREATE_VULKAN_OPTIONS_POINTER`. -/
def vulkanOptionsPointer : String := "SDL.gpu.device.create.vulkan.options"
/-- Metal: allow devices limited to the `macfamily1` feature set. C:
`SDL_PROP_GPU_DEVICE_CREATE_METAL_ALLOW_MACFAMILY1_BOOLEAN`. -/
def metalAllowMacFamily1Boolean : String := "SDL.gpu.device.create.metal.allowmacfamily1"

end Props

end Sdl.Gpu

end
