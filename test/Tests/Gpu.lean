import Sdl
import Tests.Harness

/-!
# GPU core runtime tests

Device-free checks (driver enumeration + the format helpers) always run — they
need no GPU backend and no `SDL_Init`. The device-gated block only runs when a
real GPU backend is available: under the dummy video driver there is none, so
`createDevice` throws and we assert the failure path instead. On a real
(Metal) backend it exercises an offscreen buffer upload/download round-trip,
command-buffer consumption, transfer-buffer bounds checking, and texture
creation. NO windows are ever opened.

Registers nothing — the entry point wires `test/Tests.lean`.
-/

namespace Tests.Gpu
open Sdl Sdl.Gpu Tests.Harness

/-- A deterministic 256-byte test pattern (no `ByteArray.replicate` exists). -/
def mkPattern (n : Nat) : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity n
  for i in [0:n] do
    b := b.push (UInt8.ofNat (i % 251))
  return b

/-- Driver enumeration and the device-free `TextureFormat` helpers. -/
def deviceFreeTests : IO Unit := do
  let n ← getNumDrivers
  check "getNumDrivers ≥ 1" (n.toNatClampNeg != 0)
  for name in (← getDrivers) do
    check s!"getDriver {name} non-empty" (name.length > 0)
  check "texelBlockSize r8g8b8a8Unorm == 4"
    ((← TextureFormat.texelBlockSize .r8g8b8a8Unorm) == 4)
  check "calculateSize 16 16 1 == 1024"
    ((← TextureFormat.calculateSize .r8g8b8a8Unorm 16 16 1) == 1024)
  check "toPixelFormat r8g8b8a8Unorm == abgr8888"
    ((← TextureFormat.toPixelFormat .r8g8b8a8Unorm) == .abgr8888)
  check "ofPixelFormat abgr8888 round-trips"
    ((← TextureFormat.ofPixelFormat .abgr8888) == .r8g8b8a8Unorm)

/-- Full offscreen round-trip on a real device (local run with a Metal
backend). -/
def deviceRoundTrip (dev : Device) : IO Unit := do
  let pattern := mkPattern 256
  let buf ← dev.createBuffer .vertex 256
  let upload ← dev.createTransferBuffer .upload 256
  let download ← dev.createTransferBuffer .download 256
  upload.write pattern
  let cmd ← dev.acquireCommandBuffer
  let cp ← cmd.beginCopyPass
  cp.uploadToBuffer { buffer := upload } { buffer := buf, size := 256 }
  cp.downloadFromBuffer { buffer := buf, size := 256 } { buffer := download }
  cp.finish
  let fence ← cmd.submitAndAcquireFence
  dev.waitForFences true #[fence]
  check "fence signaled after wait" (← fence.query)
  check "buffer upload/download byte-exact" ((← download.read) == pattern)

/-- Command-buffer typestate, bounds checking, texture creation, device queries. -/
def deviceMisc (dev : Device) : IO Unit := do
  -- acquire + cancel of an unused command buffer
  let cmd ← dev.acquireCommandBuffer
  cmd.cancel
  -- post-submit use of a command buffer throws
  let cmd2 ← dev.acquireCommandBuffer
  cmd2.submit
  checkThrows "post-submit command-buffer use throws" (cmd2.insertDebugLabel "x")
  -- transfer-buffer write out of bounds throws (in Lean, no crash)
  let tb ← dev.createTransferBuffer .upload 16
  checkThrows "transfer-buffer write OOB throws" (tb.write (mkPattern 32))
  -- texture create + setName
  let tex ← dev.createTexture { format := .r8g8b8a8Unorm, usage := .sampler,
                                width := 16, height := 16 }
  tex.setName "gpu-test-texture"
  -- device queries
  check "device driver == metal" ((← dev.getDriver) == "metal")
  check "device shader formats has msl" ((← dev.getShaderFormats).has .msl)
  dev.waitForIdle

def run : IO Unit := do
  deviceFreeTests
  -- createDevice needs the video subsystem (refcounted; usually already up
  -- from the Video group, but not in SDL_LEAN_TEST_GROUP-filtered runs).
  Sdl.initSubSystem .video
  let dev? ← try some <$> createDevice (.msl ||| .metallib) true catch _ => pure none
  match dev? with
  | none =>
    check "no GPU backend ⇒ SDL_VIDEO_DRIVER is dummy"
      ((← IO.getEnv "SDL_VIDEO_DRIVER") == some "dummy")
    IO.println "  ok: no GPU backend under dummy driver (expected)"
  | some dev =>
    deviceRoundTrip dev
    deviceMisc dev

end Tests.Gpu
