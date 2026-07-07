import Sdl
import Tests.Harness

/-!
# GPU pipeline / pass runtime tests

Device-free checks (structure defaults) always run — packer stride checks are
compile-time `#guard`s inside `Sdl/Gpu/Pipeline.lean`. The device-gated block
only runs on a real (Metal) backend: under the dummy video driver there is no
GPU backend, so `createDevice` throws and we assert the failure path instead.

On a real backend it exercises (with the probe-verified MSL sources, verbatim):
an offscreen graphics pipeline drawing a tinted fullscreen triangle into a
16×16 texture and reading back the exact center + corner pixels; an offscreen
compute pipeline filling a storage buffer and reading back all 256 words;
consumable pass typestate; and releasing shaders immediately after pipeline
creation. NO windows are ever opened.

Registers nothing — the entry point wires `test/Tests.lean`.
-/

namespace Tests.GpuPipeline
open Sdl Sdl.Gpu Tests.Harness

/-- The probe-verified graphics MSL: a tinted fullscreen triangle. -/
def graphicsMsl : String :=
  "#include <metal_stdlib>\n" ++
  "using namespace metal;\n" ++
  "struct VIn { float2 pos [[attribute(0)]]; float4 color [[attribute(1)]]; };\n" ++
  "struct VOut { float4 pos [[position]]; float4 color; };\n" ++
  "vertex VOut vs_main(VIn in [[stage_in]]) {\n" ++
  "  VOut out; out.pos = float4(in.pos, 0.0, 1.0); out.color = in.color; return out;\n" ++
  "}\n" ++
  "fragment float4 fs_main(VOut in [[stage_in]], constant float4 &tint [[buffer(0)]]) {\n" ++
  "  return in.color * tint;\n" ++
  "}\n"

/-- The probe-verified compute MSL: `out[gid.x] = gid.x * 3 + 7`. -/
def computeMsl : String :=
  "#include <metal_stdlib>\n" ++
  "using namespace metal;\n" ++
  "kernel void cs_main(device uint *out [[buffer(0)]],\n" ++
  "                    uint3 gid [[thread_position_in_grid]]) {\n" ++
  "  out[gid.x] = gid.x * 3u + 7u;\n" ++
  "}\n"

/-- Append a little-endian `Float32`. -/
def pushF32 (b : ByteArray) (f : Float32) : ByteArray :=
  let u := f.toBits
  b.push u.toUInt8 |>.push (u >>> 8).toUInt8 |>.push (u >>> 16).toUInt8
    |>.push (u >>> 24).toUInt8

/-- Read a little-endian `UInt32` at byte offset `o`. -/
def rdU32 (b : ByteArray) (o : Nat) : UInt32 :=
  b[o]!.toUInt32 ||| (b[o+1]!.toUInt32 <<< 8) ||| (b[o+2]!.toUInt32 <<< 16)
    ||| (b[o+3]!.toUInt32 <<< 24)

/-- Three fullscreen-triangle vertices `{x, y, r, g, b, a}` (24-byte stride,
all white). -/
def vertexBytes : ByteArray := Id.run do
  let verts : Array (Float32 × Float32) := #[(-1, -1), (3, -1), (-1, 3)]
  let mut b := ByteArray.emptyWithCapacity 72
  for (x, y) in verts do
    b := pushF32 b x
    b := pushF32 b y
    b := pushF32 b 1  -- r
    b := pushF32 b 1  -- g
    b := pushF32 b 1  -- b
    b := pushF32 b 1  -- a
  return b

/-- The fragment tint uniform: 4 f32 = (0.25, 0.5, 0.75, 1.0). -/
def tintBytes : ByteArray :=
  pushF32 (pushF32 (pushF32 (pushF32 (ByteArray.emptyWithCapacity 16)
    0.25) 0.5) 0.75) 1.0

/-- Sanity checks that pipeline structures construct with their spec defaults. -/
def defaultsTests : IO Unit := do
  check "RasterizerState default fillMode == fill" ((({} : RasterizerState)).fillMode == .fill)
  check "RasterizerState default cullMode == none" ((({} : RasterizerState)).cullMode == .none)
  check "MultisampleState default sampleCount == x1"
    ((({} : MultisampleState)).sampleCount == .x1)
  check "StencilOpState default failOp == invalid"
    ((({} : StencilOpState)).failOp == .invalid)
  check "packRasterizerState default size == 28" ((packRasterizerState {}).size == 28)
  check "packDepthStencilState default size == 44" ((packDepthStencilState {}).size == 44)

/-- Full offscreen graphics pipeline: draw a tinted fullscreen triangle into a
16×16 texture and read back exact pixels. Also releases the shaders immediately
after pipeline creation, then still draws with the pipeline. -/
def graphicsTest (dev : Device) : IO Unit := do
  let vs ← dev.createShader
    { code := graphicsMsl.toUTF8, entrypoint := "vs_main", format := .msl, stage := .vertex }
  let fs ← dev.createShader
    { code := graphicsMsl.toUTF8, entrypoint := "fs_main", format := .msl, stage := .fragment,
      numUniformBuffers := 1 }
  let pipeline ← dev.createGraphicsPipeline
    { vertexShader := vs, fragmentShader := fs,
      vertexInputState :=
        { vertexBufferDescriptions := #[{ slot := 0, pitch := 24 }],
          vertexAttributes :=
            #[{ location := 0, bufferSlot := 0, format := .float2, offset := 0 },
              { location := 1, bufferSlot := 0, format := .float4, offset := 8 }] },
      targetInfo := { colorTargetDescriptions := #[{ format := .r8g8b8a8Unorm }] } }
  -- Shaders may be released immediately after pipeline creation (probe-verified).
  vs.release
  fs.release
  let vbuf ← dev.createBuffer .vertex 72
  let up ← dev.createTransferBuffer .upload 72
  up.write vertexBytes
  let tex ← dev.createTexture
    { format := .r8g8b8a8Unorm, usage := .colorTarget, width := 16, height := 16 }
  let download ← dev.createTransferBuffer .download 1024
  let cmd ← dev.acquireCommandBuffer
  let cp ← cmd.beginCopyPass
  cp.uploadToBuffer { buffer := up } { buffer := vbuf, size := 72 }
  cp.finish
  let rp ← cmd.beginRenderPass
    #[{ texture := tex, loadOp := .clear, storeOp := .store, clearColor := ⟨0, 0, 0, 0⟩ }]
  rp.bindPipeline pipeline
  rp.bindVertexBuffers 0 #[{ buffer := vbuf }]
  cmd.pushFragmentUniformData 0 tintBytes
  rp.drawPrimitives 3
  rp.finish
  let cp2 ← cmd.beginCopyPass
  cp2.downloadFromTexture { texture := tex, w := 16, h := 16 } { buffer := download }
  cp2.finish
  let fence ← cmd.submitAndAcquireFence
  dev.waitForFences true #[fence]
  -- Only NOW may the pipeline be dropped: binds do not retain, and SDL frees a
  -- released pipeline even while it is bound in unsubmitted work (module-doc
  -- lifetime caveat). Without this explicit later use, eager RC would finalize
  -- `pipeline` right after `bindPipeline` — a use-after-free at draw time.
  pipeline.release
  let px ← download.read
  -- center pixel (8,8) at byte (8*16+8)*4 = 544; corner (0,0) at byte 0.
  check "graphics center pixel R == 64" (px[544]! == 64)
  check "graphics center pixel G == 128" (px[545]! == 128)
  check "graphics center pixel B == 191" (px[546]! == 191)
  check "graphics center pixel A == 255" (px[547]! == 255)
  check "graphics corner pixel == (64,128,191,255)"
    (px[0]! == 64 && px[1]! == 128 && px[2]! == 191 && px[3]! == 255)

/-- Full offscreen compute pipeline: fill a 1024-byte storage buffer with
`out[i] = i*3+7` and read back all 256 words. -/
def computeTest (dev : Device) : IO Unit := do
  let cpipe ← dev.createComputePipeline
    { code := computeMsl.toUTF8, entrypoint := "cs_main", format := .msl,
      numReadwriteStorageBuffers := 1, threadcountX := 64, threadcountY := 1, threadcountZ := 1 }
  let sbuf ← dev.createBuffer .computeStorageWrite 1024
  let download ← dev.createTransferBuffer .download 1024
  let cmd ← dev.acquireCommandBuffer
  let pass ← cmd.beginComputePass (storageBufferBindings := #[{ buffer := sbuf }])
  pass.bindPipeline cpipe
  pass.dispatch 4 1 1
  pass.finish
  let cp ← cmd.beginCopyPass
  cp.downloadFromBuffer { buffer := sbuf, size := 1024 } { buffer := download }
  cp.finish
  let fence ← cmd.submitAndAcquireFence
  dev.waitForFences true #[fence]
  cpipe.release -- keep the pipeline alive until after submit (lifetime caveat)
  let bytes ← download.read
  let mut allOk := true
  for i in [0:256] do
    if rdU32 bytes (i * 4) != UInt32.ofNat (i * 3 + 7) then
      allOk := false
  check "compute out[i] == i*3+7 for all 256 words" allOk

/-- Consumable typestate: a second `finish` throws; after submit, a draw
throws (the render-pass holder is NULLed and the command buffer is gone). -/
def typestateTest (dev : Device) : IO Unit := do
  let tex ← dev.createTexture
    { format := .r8g8b8a8Unorm, usage := .colorTarget, width := 16, height := 16 }
  let cmd ← dev.acquireCommandBuffer
  let rp ← cmd.beginRenderPass
    #[{ texture := tex, loadOp := .clear, storeOp := .store }]
  rp.finish
  checkThrows "second RenderPass.finish throws" rp.finish
  cmd.submit
  checkThrows "post-finish/submit RenderPass.drawPrimitives throws" (rp.drawPrimitives 3)

def run : IO Unit := do
  defaultsTests
  -- createDevice needs the video subsystem (refcounted; copy Gpu's gate idiom).
  Sdl.initSubSystem .video
  let dev? ← try some <$> createDevice (.msl ||| .metallib) true catch _ => pure none
  match dev? with
  | none =>
    check "no GPU backend ⇒ SDL_VIDEO_DRIVER is dummy"
      ((← IO.getEnv "SDL_VIDEO_DRIVER") == some "dummy")
    IO.println "  ok: no GPU backend under dummy driver (expected)"
  | some dev =>
    graphicsTest dev
    computeTest dev
    typestateTest dev

end Tests.GpuPipeline
