import Common

/-!
# Shared scaffolding for the GPU demos

Lean counterpart of `Examples/Common.{h,c}` in the official
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples) suite,
which the `gpu-*` demos under `examples/Gpu/` port one-to-one:

- `Examples.Gpu.Example` + `Example.run`: the upstream `Init`/`Update`/`Draw`/
  `Quit` example shape and its driver loop (`main.c`), mapped onto `Sdl.App`.
  Device + window creation (`CommonInit`), per-frame arrow-key state
  (`LeftPressed` …), `DeltaTime`, and the headless skip path live here.
- `loadShader` / `createComputePipeline`: load a precompiled shader from
  `examples/assets/gpu/shaders/`, choosing SPIR-V, MSL or DXIL by what the
  device accepts (upstream `LoadShader` / `CreateComputePipelineFromShader`).
- `loadImage`: a BMP as tightly packed RGBA8 bytes (upstream `LoadImage`).
- Vertex layouts, `Matrix4x4` / `Vector3` math, and little-endian byte packers
  for filling transfer buffers and uniform blocks.

## Headless behavior

There is no SDL_GPU backend under the dummy video driver, so when device
creation fails `Example.run` logs the reason and exits 0 — the same policy as
`gpu-01-clear`, which keeps `scripts/smoke-examples.sh` green in CI. With a
real backend every demo honors `SDL_LEAN_MAX_FRAMES` via `Examples.runApp`.
-/

namespace Examples.Gpu
open Sdl

/-! ## Little-endian byte packing

Transfer buffers and uniform pushes take raw bytes; these append scalars in
the C struct layouts the shaders expect (all supported targets are
little-endian). -/

/-- Append a `Uint8`. -/
def pushU8 (b : ByteArray) (v : UInt8) : ByteArray := b.push v

/-- Append a little-endian `Uint16`. -/
def pushU16 (b : ByteArray) (v : UInt16) : ByteArray :=
  b.push v.toUInt8 |>.push (v >>> 8).toUInt8

/-- Append a little-endian `Uint32`. -/
def pushU32 (b : ByteArray) (v : UInt32) : ByteArray :=
  b.push v.toUInt8 |>.push (v >>> 8).toUInt8 |>.push (v >>> 16).toUInt8
    |>.push (v >>> 24).toUInt8

/-- Append a little-endian `Sint32`. -/
def pushI32 (b : ByteArray) (v : Int32) : ByteArray := pushU32 b v.toUInt32

/-- Append a little-endian IEEE-754 `float`. -/
def pushF32 (b : ByteArray) (f : Float32) : ByteArray := pushU32 b f.toBits

/-- Append four `float`s — one 16-byte row of a `float4`-aligned struct.
(A direct chain, not a list fold: the sprite batchers call this 32768 times
a frame.) -/
def pushF32x4 (b : ByteArray) (x y z w : Float32) : ByteArray :=
  pushF32 (pushF32 (pushF32 (pushF32 b x) y) z) w

/-- Append `n` zero bytes (struct padding). -/
def pushZeros (b : ByteArray) (n : Nat) : ByteArray := Id.run do
  let mut b := b
  for _ in [0:n] do
    b := b.push 0
  return b

/-- Read a little-endian `Uint32` at byte offset `o`. -/
def readU32 (b : ByteArray) (o : Nat) : UInt32 :=
  b[o]!.toUInt32 ||| (b[o+1]!.toUInt32 <<< 8) ||| (b[o+2]!.toUInt32 <<< 16)
    ||| (b[o+3]!.toUInt32 <<< 24)

#guard (pushU16 .empty 0x1234).toList == [0x34, 0x12]
#guard (pushU32 .empty 0xDEADBEEF).toList == [0xEF, 0xBE, 0xAD, 0xDE]
#guard (pushF32 .empty 1.0).toList == [0, 0, 0x80, 0x3F]
#guard (pushF32x4 .empty 1 2 3 4).size == 16
#guard readU32 (pushF32x4 .empty 1 2 3 4) 12 == (4.0 : Float32).toBits
#guard (pushI32 .empty (-1)).toList == [0xFF, 0xFF, 0xFF, 0xFF]
#guard readU32 (pushU32 .empty 0xDEADBEEF) 0 == 0xDEADBEEF
#guard (pushZeros .empty 3).size == 3

/-! ## Vertex formats (upstream `Common.h`) -/

/-- `{float x, y, z}`. C: `PositionVertex` (12 bytes). -/
structure PositionVertex where
  x : Float32
  y : Float32
  z : Float32

namespace PositionVertex
/-- `sizeof(PositionVertex)`. -/
def stride : UInt32 := 12
/-- Append the 12-byte C layout. -/
def emit (b : ByteArray) (v : PositionVertex) : ByteArray :=
  pushF32 (pushF32 (pushF32 b v.x) v.y) v.z
end PositionVertex

#guard (PositionVertex.emit .empty ⟨0, 0, 0⟩).size.toUInt32 == PositionVertex.stride

/-- `{float x, y, z; Uint8 r, g, b, a}`. C: `PositionColorVertex` (16 bytes). -/
structure PositionColorVertex where
  x : Float32
  y : Float32
  z : Float32
  r : UInt8
  g : UInt8
  b : UInt8
  a : UInt8

namespace PositionColorVertex
/-- `sizeof(PositionColorVertex)`. -/
def stride : UInt32 := 16
/-- Append the 16-byte C layout. -/
def emit (b : ByteArray) (v : PositionColorVertex) : ByteArray :=
  pushF32 (pushF32 (pushF32 b v.x) v.y) v.z |>.push v.r |>.push v.g |>.push v.b |>.push v.a
end PositionColorVertex

#guard (PositionColorVertex.emit .empty ⟨0, 0, 0, 0, 0, 0, 0⟩).size.toUInt32
  == PositionColorVertex.stride

/-- `{float x, y, z; float u, v}`. C: `PositionTextureVertex` (20 bytes). -/
structure PositionTextureVertex where
  x : Float32
  y : Float32
  z : Float32
  u : Float32
  v : Float32

namespace PositionTextureVertex
/-- `sizeof(PositionTextureVertex)`. -/
def stride : UInt32 := 20
/-- Append the 20-byte C layout. -/
def emit (b : ByteArray) (v : PositionTextureVertex) : ByteArray :=
  pushF32 (pushF32 (pushF32 (pushF32 (pushF32 b v.x) v.y) v.z) v.u) v.v
end PositionTextureVertex

#guard (PositionTextureVertex.emit .empty ⟨0, 0, 0, 0, 0⟩).size.toUInt32
  == PositionTextureVertex.stride

/-- Pack an array of vertices with `emit`. -/
def packVertices (emit : ByteArray → α → ByteArray) (vs : Array α) : ByteArray :=
  vs.foldl emit .empty

/-- Pack 16-bit indices. -/
def packIndices16 (is : Array UInt16) : ByteArray := is.foldl pushU16 .empty

#guard (packIndices16 #[0, 1, 2]).size == 6

/-! ## Matrix math (upstream `Common.c`)

Row-major `Matrix4x4` with the translation in the fourth row (`m41..m43`),
so vectors are rows multiplied on the left — exactly the upstream helpers'
conventions, which the vendored shaders were written against. -/

/-- A 3-vector. C: `Vector3`. -/
structure Vector3 where
  x : Float32
  y : Float32
  z : Float32
deriving Repr, BEq, Inhabited

namespace Vector3
/-- C: `Vector3_Dot`. -/
def dot (a b : Vector3) : Float32 := a.x * b.x + a.y * b.y + a.z * b.z
/-- C: `Vector3_Cross`. -/
def cross (a b : Vector3) : Vector3 :=
  ⟨a.y * b.z - b.y * a.z, -(a.x * b.z - b.x * a.z), a.x * b.y - b.x * a.y⟩
/-- C: `Vector3_Normalize`. -/
def normalize (v : Vector3) : Vector3 :=
  let m := (v.x * v.x + v.y * v.y + v.z * v.z).sqrt
  ⟨v.x / m, v.y / m, v.z / m⟩
end Vector3

#guard Vector3.dot ⟨1, 2, 3⟩ ⟨4, 5, 6⟩ == 32
#guard Vector3.cross ⟨1, 0, 0⟩ ⟨0, 1, 0⟩ == ⟨0, 0, 1⟩
#guard Vector3.normalize ⟨0, 3, 4⟩ == ⟨0, 0.6, 0.8⟩

/-- A 4×4 float matrix, row-major, `m<row><col>`. C: `Matrix4x4` (64 bytes). -/
structure Matrix4x4 where
  m11 : Float32
  m12 : Float32
  m13 : Float32
  m14 : Float32
  m21 : Float32
  m22 : Float32
  m23 : Float32
  m24 : Float32
  m31 : Float32
  m32 : Float32
  m33 : Float32
  m34 : Float32
  m41 : Float32
  m42 : Float32
  m43 : Float32
  m44 : Float32
deriving Repr, BEq, Inhabited

namespace Matrix4x4

/-- The identity matrix. -/
def identity : Matrix4x4 :=
  ⟨1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1⟩

/-- `a × b`. C: `Matrix4x4_Multiply`. -/
def mul (a b : Matrix4x4) : Matrix4x4 where
  m11 := a.m11 * b.m11 + a.m12 * b.m21 + a.m13 * b.m31 + a.m14 * b.m41
  m12 := a.m11 * b.m12 + a.m12 * b.m22 + a.m13 * b.m32 + a.m14 * b.m42
  m13 := a.m11 * b.m13 + a.m12 * b.m23 + a.m13 * b.m33 + a.m14 * b.m43
  m14 := a.m11 * b.m14 + a.m12 * b.m24 + a.m13 * b.m34 + a.m14 * b.m44
  m21 := a.m21 * b.m11 + a.m22 * b.m21 + a.m23 * b.m31 + a.m24 * b.m41
  m22 := a.m21 * b.m12 + a.m22 * b.m22 + a.m23 * b.m32 + a.m24 * b.m42
  m23 := a.m21 * b.m13 + a.m22 * b.m23 + a.m23 * b.m33 + a.m24 * b.m43
  m24 := a.m21 * b.m14 + a.m22 * b.m24 + a.m23 * b.m34 + a.m24 * b.m44
  m31 := a.m31 * b.m11 + a.m32 * b.m21 + a.m33 * b.m31 + a.m34 * b.m41
  m32 := a.m31 * b.m12 + a.m32 * b.m22 + a.m33 * b.m32 + a.m34 * b.m42
  m33 := a.m31 * b.m13 + a.m32 * b.m23 + a.m33 * b.m33 + a.m34 * b.m43
  m34 := a.m31 * b.m14 + a.m32 * b.m24 + a.m33 * b.m34 + a.m34 * b.m44
  m41 := a.m41 * b.m11 + a.m42 * b.m21 + a.m43 * b.m31 + a.m44 * b.m41
  m42 := a.m41 * b.m12 + a.m42 * b.m22 + a.m43 * b.m32 + a.m44 * b.m42
  m43 := a.m41 * b.m13 + a.m42 * b.m23 + a.m43 * b.m33 + a.m44 * b.m43
  m44 := a.m41 * b.m14 + a.m42 * b.m24 + a.m43 * b.m34 + a.m44 * b.m44

instance : Mul Matrix4x4 := ⟨mul⟩

/-- Rotation about Z by `radians`. C: `Matrix4x4_CreateRotationZ`. -/
def rotationZ (radians : Float32) : Matrix4x4 :=
  let c := radians.cos
  let s := radians.sin
  ⟨c, s, 0, 0,  -s, c, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1⟩

/-- Translation by `(x, y, z)`. C: `Matrix4x4_CreateTranslation`. -/
def translation (x y z : Float32) : Matrix4x4 :=
  ⟨1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  x, y, z, 1⟩

/-- Off-center orthographic projection. C:
`Matrix4x4_CreateOrthographicOffCenter`. -/
def orthographicOffCenter (left right bottom top zNear zFar : Float32) : Matrix4x4 :=
  ⟨2 / (right - left), 0, 0, 0,
   0, 2 / (top - bottom), 0, 0,
   0, 0, 1 / (zNear - zFar), 0,
   (left + right) / (left - right), (top + bottom) / (bottom - top),
     zNear / (zNear - zFar), 1⟩

/-- Perspective projection from a vertical field of view (radians). C:
`Matrix4x4_CreatePerspectiveFieldOfView`. -/
def perspectiveFieldOfView (fieldOfView aspectRatio near far : Float32) : Matrix4x4 :=
  let num := 1 / (fieldOfView * 0.5).tan
  ⟨num / aspectRatio, 0, 0, 0,
   0, num, 0, 0,
   0, 0, far / (near - far), -1,
   0, 0, (near * far) / (near - far), 0⟩

/-- A right-handed look-at view matrix. C: `Matrix4x4_CreateLookAt`. -/
def lookAt (cameraPosition cameraTarget cameraUp : Vector3) : Matrix4x4 :=
  let a := Vector3.normalize ⟨cameraPosition.x - cameraTarget.x,
    cameraPosition.y - cameraTarget.y, cameraPosition.z - cameraTarget.z⟩
  let b := Vector3.normalize (Vector3.cross cameraUp a)
  let c := Vector3.cross a b
  ⟨b.x, c.x, a.x, 0,
   b.y, c.y, a.y, 0,
   b.z, c.z, a.z, 0,
   -(b.dot cameraPosition), -(c.dot cameraPosition), -(a.dot cameraPosition), 1⟩

/-- Append the 64-byte C memory layout (`m11, m12, …, m44`) — what
`SDL_PushGPUVertexUniformData(&matrix, sizeof matrix)` sends. -/
def emit (b : ByteArray) (m : Matrix4x4) : ByteArray :=
  let b := pushF32x4 b m.m11 m.m12 m.m13 m.m14
  let b := pushF32x4 b m.m21 m.m22 m.m23 m.m24
  let b := pushF32x4 b m.m31 m.m32 m.m33 m.m34
  pushF32x4 b m.m41 m.m42 m.m43 m.m44

/-- The 64-byte C memory layout as a fresh `ByteArray`. -/
def toBytes (m : Matrix4x4) : ByteArray := emit (.emptyWithCapacity 64) m

end Matrix4x4

#guard Matrix4x4.identity * Matrix4x4.translation 1 2 3 == Matrix4x4.translation 1 2 3
#guard Matrix4x4.translation 1 2 3 * Matrix4x4.translation 4 5 6 == Matrix4x4.translation 5 7 9
#guard Matrix4x4.rotationZ 0 == Matrix4x4.identity
#guard (Matrix4x4.toBytes .identity).size == 64
#guard (Matrix4x4.toBytes .identity)[0]! == 0 && (Matrix4x4.toBytes .identity)[3]! == 0x3F
#guard Matrix4x4.lookAt ⟨0, 0, 4⟩ ⟨0, 0, 0⟩ ⟨0, 1, 0⟩ == Matrix4x4.translation 0 0 (-4)
-- Orthographic: (0,0) maps to NDC (-1, 1) with y down, (640, 480) to (1, -1).
#guard
  let m := Matrix4x4.orthographicOffCenter 0 640 480 0 0 (-1)
  m.m11 == 2 / 640 && m.m22 == -(2 / 480) && m.m41 == -1 && m.m42 == 1 && m.m44 == 1

/-! ## Pseudo-random numbers

Upstream uses `SDL_rand`/`SDL_randf`; SDL's stdinc is deliberately unbound
(see the README), so the sprite demos use this xorshift64 stream instead. -/

/-- One step of the xorshift64 PRNG (never maps a nonzero state to zero). -/
def xorshift64 (s : UInt64) : UInt64 :=
  let s := s ^^^ (s <<< 13)
  let s := s ^^^ (s >>> 7)
  s ^^^ (s <<< 17)

/-- A uniform `Float32` in `[0, 1)` from the top 24 bits of the state. -/
def randFloat (s : UInt64) : Float32 := (s >>> 40).toNat.toFloat32 / 16777216.0

#guard xorshift64 1 != 0
#guard randFloat 0 == 0
#guard randFloat 0xFFFFFFFFFFFFFFFF < 1

/-! ## Assets -/

/-- `examples/assets/gpu/`: the assets vendored from SDL_gpu_examples. -/
def assetsDir : System.FilePath := Examples.assetsDir / "gpu"

/-- The on-disk path of a vendored GPU asset (`shaders/…` or `images/…`),
with an actionable error if it is missing. -/
def assetPath (rel : String) : IO System.FilePath := do
  let p := assetsDir / rel
  unless (← p.pathExists) do
    throw <| IO.userError s!"asset not found: {p}\n\
      Run demos from the repository root, e.g. `lake exe gpu-02-basic-triangle`."
  return p

/-- One precompiled flavor of the vendored shaders: where it lives under
`shaders/` and how to create it. -/
structure ShaderFlavor where
  format : Sdl.Gpu.ShaderFormat
  /-- Subdirectory of `shaders/`. -/
  dir : String
  /-- File extension. -/
  ext : String
  /-- The MSL entrypoint is `main0` because SDL_shadercross's Metal output
  renames `main`. -/
  entrypoint : String
deriving Repr, BEq

/-- Pick the precompiled shader flavor the device accepts, in upstream
`LoadShader`'s preference order (SPIR-V, then MSL, then DXIL). -/
def pickShaderFormat (formats : Sdl.Gpu.ShaderFormat) : Option ShaderFlavor :=
  if formats.has .spirv then some ⟨.spirv, "SPIRV", "spv", "main"⟩
  else if formats.has .msl then some ⟨.msl, "MSL", "msl", "main0"⟩
  else if formats.has .dxil then some ⟨.dxil, "DXIL", "dxil", "main"⟩
  else none

#guard (pickShaderFormat (.spirv ||| .msl)).map (·.format) == some .spirv
#guard (pickShaderFormat .msl).map (·.entrypoint) == some "main0"
#guard (pickShaderFormat .metallib).isNone

/-- Read the precompiled `name` (e.g. `"RawTriangle.vert"`) in the format the
device accepts: `(code, format, entrypoint)`. -/
def readShaderCode (device : Sdl.Gpu.Device) (name : String) :
    IO (ByteArray × Sdl.Gpu.ShaderFormat × String) := do
  let some f := pickShaderFormat (← device.getShaderFormats)
    | throw <| IO.userError "Unrecognized backend shader format!"
  let code ← IO.FS.readBinFile (← assetPath s!"shaders/{f.dir}/{name}.{f.ext}")
  return (code, f.format, f.entrypoint)

/-- Create a vertex or fragment shader from the precompiled `name`
(`*.vert` / `*.frag`, stage auto-detected from the suffix), in the format the
device accepts. The resource counts must match the shader source. C: upstream
`LoadShader`. -/
def loadShader (device : Sdl.Gpu.Device) (name : String)
    (numSamplers numUniformBuffers numStorageBuffers numStorageTextures : UInt32 := 0) :
    IO Sdl.Gpu.Shader := do
  let stage : Sdl.Gpu.ShaderStage ←
    if name.endsWith ".vert" then pure .vertex
    else if name.endsWith ".frag" then pure .fragment
    else throw <| IO.userError s!"loadShader: cannot tell the stage of '{name}'"
  let (code, format, entrypoint) ← readShaderCode device name
  device.createShader
    { code, entrypoint, format, stage, numSamplers, numUniformBuffers,
      numStorageBuffers, numStorageTextures }

/-- The resource counts and threadgroup size of a compute shader — everything
in `SDL_GPUComputePipelineCreateInfo` except the code, which
`createComputePipeline` loads. -/
structure ComputeShaderInfo where
  numSamplers : UInt32 := 0
  numReadonlyStorageTextures : UInt32 := 0
  numReadonlyStorageBuffers : UInt32 := 0
  numReadwriteStorageTextures : UInt32 := 0
  numReadwriteStorageBuffers : UInt32 := 0
  numUniformBuffers : UInt32 := 0
  threadcountX : UInt32
  threadcountY : UInt32
  threadcountZ : UInt32

/-- Create a compute pipeline from the precompiled `name` (`*.comp`), in the
format the device accepts. C: upstream `CreateComputePipelineFromShader`. -/
def createComputePipeline (device : Sdl.Gpu.Device) (name : String)
    (info : ComputeShaderInfo) : IO Sdl.Gpu.ComputePipeline := do
  let (code, format, entrypoint) ← readShaderCode device name
  device.createComputePipeline
    { code, entrypoint, format,
      numSamplers := info.numSamplers,
      numReadonlyStorageTextures := info.numReadonlyStorageTextures,
      numReadonlyStorageBuffers := info.numReadonlyStorageBuffers,
      numReadwriteStorageTextures := info.numReadwriteStorageTextures,
      numReadwriteStorageBuffers := info.numReadwriteStorageBuffers,
      numUniformBuffers := info.numUniformBuffers,
      threadcountX := info.threadcountX,
      threadcountY := info.threadcountY,
      threadcountZ := info.threadcountZ }

/-- A decoded image: tightly packed RGBA8 rows, top to bottom — the byte
layout of `SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM`. -/
structure Image where
  width : UInt32
  height : UInt32
  /-- `width × height × 4` bytes. -/
  pixels : ByteArray

/-- Load `images/<name>` (a BMP) as RGBA8. C: upstream `LoadImage(name, 4)`,
which converts to `SDL_PIXELFORMAT_ABGR8888` (little-endian R, G, B, A
bytes). -/
def loadImage (name : String) : IO Image := do
  let surface ← Sdl.loadBMP (← assetPath s!"images/{name}").toString
  let surface ← surface.convert .rgba32
  let width := (← surface.width).toNatClampNeg.toUInt32
  let height := (← surface.height).toNatClampNeg.toUInt32
  let pixels ← surface.getPixels
  return { width, height, pixels }

/-! ## The example shape and driver (upstream `Common.h` `Context`/`Example`,
`main.c`) -/

/-- Which arrow keys went down since the previous frame. Upstream
`Context.LeftPressed` …: set on `SDL_EVENT_KEY_DOWN`, cleared after every
frame, so an example's `update` sees each press exactly once. -/
structure Keys where
  left : Bool := false
  right : Bool := false
  up : Bool := false
  down : Bool := false
deriving Repr, BEq, Inhabited

/-- Per-example context. C: upstream `Context` (minus the name/base path). -/
structure Context where
  window : Window
  device : Sdl.Gpu.Device
  /-- Arrow keys pressed this frame (see `Keys`). -/
  keys : IO.Ref Keys
  /-- Seconds since the previous frame. C: `Context.DeltaTime`. -/
  deltaTime : IO.Ref Float32

namespace Context
/-- C: `context->LeftPressed`. -/
def leftPressed (ctx : Context) : IO Bool := return (← ctx.keys.get).left
/-- C: `context->RightPressed`. -/
def rightPressed (ctx : Context) : IO Bool := return (← ctx.keys.get).right
/-- C: `context->UpPressed`. -/
def upPressed (ctx : Context) : IO Bool := return (← ctx.keys.get).up
/-- C: `context->DownPressed`. -/
def downPressed (ctx : Context) : IO Bool := return (← ctx.keys.get).down
/-- C: `context->DeltaTime`. -/
def getDeltaTime (ctx : Context) : IO Float32 := ctx.deltaTime.get
/-- The swapchain format, needed for every pipeline that draws to the window.
C: `SDL_GetGPUSwapchainTextureFormat(context->Device, context->Window)`. -/
def swapchainFormat (ctx : Context) : IO Sdl.Gpu.TextureFormat :=
  ctx.device.getSwapchainTextureFormat ctx.window
end Context

/-- One ported example over its own resource record `σ`. C: upstream
`Example` (`Init`/`Update`/`Draw`/`Quit`); `name` is the window title. The
GPU resources in `σ` are freed by their finalizers, so `quit` usually has
nothing to do (upstream's `Quit` just releases them) — it exists for examples
that must wait on or read back GPU work first. -/
structure Example (σ : Type) where
  name : String
  /-- Create the example's resources (device and window already exist).
  C: `Example.Init` after `CommonInit`. -/
  init : Context → IO σ
  /-- Per-frame logic before drawing (key handling). C: `Example.Update`. -/
  update : Context → σ → IO Unit := fun _ _ => pure ()
  /-- Record and submit one frame. C: `Example.Draw`. -/
  draw : Context → σ → IO Unit
  /-- Cleanup before the device is torn down. C: `Example.Quit` before
  `CommonQuit`. -/
  quit : Context → σ → IO Unit := fun _ _ => pure ()

/-- Run an example as an `Sdl.App`: create the device (SPIR-V / DXIL / MSL,
debug mode on) and a 640×480 window, claim it, then loop `update` → `draw`
with arrow-key state and delta time maintained as upstream `main.c` does.
Honors `SDL_LEAN_MAX_FRAMES` (via `Examples.runApp`); when no GPU backend
exists (the dummy video driver) it logs and exits 0. C: upstream
`CommonInit` + `main.c`'s loop + `CommonQuit`. -/
def Example.run (ex : Example σ) (windowFlags : WindowFlags := .none) : IO UInt32 := do
  let lastTime ← IO.mkRef (0 : Float32)
  let app : App (Context × σ) := {
    init _ := do
      setAppMetadata s!"SDL_gpu_examples: {ex.name}" "1.0" s!"com.example.gpu.{ex.name}"
      Sdl.init .video
      let device ←
        try
          Sdl.Gpu.createDevice (.spirv ||| .dxil ||| .msl) (debugMode := true)
        catch e =>
          IO.eprintln s!"{ex.name}: no GPU backend, skipping ({e})"
          return (.success, none)
      let window ← createWindow ex.name 640 480 windowFlags
      device.claimWindow window
      let ctx : Context := { window, device, keys := ← IO.mkRef {}, deltaTime := ← IO.mkRef 0 }
      let s ← ex.init ctx
      return (.continue, some (ctx, s))
    event s e := do
      match e with
      | .quit _ => return .success
      | .keyDown ke =>
        let keys := s.1.keys
        if ke.key == Keycode.left then keys.modify ({ · with left := true })
        else if ke.key == Keycode.right then keys.modify ({ · with right := true })
        else if ke.key == Keycode.up then keys.modify ({ · with up := true })
        else if ke.key == Keycode.down then keys.modify ({ · with down := true })
        return .continue
      | _ => return .continue
    iterate := fun (ctx, s) => do
      let now := ((← getTicks).toNat.toFloat / 1000.0).toFloat32
      ctx.deltaTime.set (now - (← lastTime.get))
      lastTime.set now
      ex.update ctx s
      ex.draw ctx s
      ctx.keys.set {}
      return .continue
    quit := fun (ctx, s) _ => do
      -- Drain in-flight work before the resource finalizers run.
      ctx.device.waitForIdle
      ex.quit ctx s
      ctx.device.releaseWindow ctx.window
  }
  Examples.runApp app

/-- The per-frame boilerplate shared by every drawing example: acquire a
command buffer, wait for a swapchain texture, run `body` on it if there is
one (a `none` means a minimized window or too many frames in flight — the
frame is skipped, as upstream does), then submit. C: the
`SDL_AcquireGPUCommandBuffer` → `SDL_WaitAndAcquireGPUSwapchainTexture` →
`SDL_SubmitGPUCommandBuffer` skeleton of every upstream `Draw`. -/
def withSwapchainFrame (ctx : Context)
    (body : Sdl.Gpu.CommandBuffer → Sdl.Gpu.SwapchainTexture → IO Unit) : IO Unit := do
  let cmd ← ctx.device.acquireCommandBuffer
  if let some sc ← cmd.waitAndAcquireSwapchainTexture ctx.window then
    body cmd sc
  cmd.submit

end Examples.Gpu
