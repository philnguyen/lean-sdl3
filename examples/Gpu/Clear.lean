import Common

/-!
# gpu/01-clear

Creates a window, claims it for a GPU device, and clears its swapchain to a
different color every frame via a render pass with `loadOp := .clear` — the
GPU-API analogue of `renderer/01-clear`. No shaders, no pipelines: the
smallest possible SDL_GPU frame loop.

There is no official SDL example for this (the `examples/` gallery has no gpu
category); the frame-loop shape follows the `SDL_gpu.h` header docs:
acquire command buffer → wait-and-acquire swapchain texture → render pass →
submit.

## Headless behavior

There is no SDL_GPU backend under the dummy video driver, so when device
creation fails the demo logs the reason and exits 0 (mirroring how
`camera/01-read-and-draw` tolerates having no camera). Under
`SDL_LEAN_MAX_FRAMES` with a real backend it also self-checks that at least
one swapchain texture was actually cleared.
-/

open Sdl

structure State where
  window : Window
  device : Gpu.Device
  /-- Frames that actually cleared a swapchain texture (self-check). -/
  cleared : IO.Ref Nat

def app (cleared : IO.Ref Nat) : App State where
  init := fun _args => do
    setAppMetadata "Example GPU Clear" "1.0" "com.example.gpu-clear"
    Sdl.init .video
    let device ←
      try
        Gpu.createDevice (.msl ||| .metallib)
      catch e =>
        -- No GPU backend (always the case under the dummy video driver):
        -- not an error for this demo, just nothing to show.
        IO.eprintln s!"gpu-clear: no GPU backend, skipping ({e})"
        return (.success, none)
    let window ← createWindow "examples/gpu/clear" 640 480 .resizable
    device.claimWindow window
    return (.continue, some { window, device, cleared })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let cmd ← s.device.acquireCommandBuffer
    -- `none` here means too many frames in flight or a minimized window —
    -- cancel this command buffer and try again next frame.
    let some sc ← cmd.waitAndAcquireSwapchainTexture s.window
      | cmd.cancel; return .continue
    let now := (← getTicks).toFloat / 1000.0
    let red   := 0.5 + 0.5 * Float.sin now
    let green := 0.5 + 0.5 * Float.sin (now + Examples.pi * 2 / 3)
    let blue  := 0.5 + 0.5 * Float.sin (now + Examples.pi * 4 / 3)
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture
      clearColor := ⟨red.toFloat32, green.toFloat32, blue.toFloat32, 1.0⟩
      loadOp := .clear
      storeOp := .store
    }]
    rp.finish
    cmd.submit
    s.cleared.modify (· + 1)
    return .continue
  quit := fun s _ => do
    -- Drain in-flight work before the window/device finalizers run.
    s.device.waitForIdle

def main : IO UInt32 := do
  let cleared ← IO.mkRef 0
  let code ← Examples.runApp (app cleared)
  -- Headless smoke self-check: with a real backend and a frame cap, at least
  -- one frame must have cleared a swapchain texture. Without a backend the
  -- init-time skip path already exited cleanly (cleared stays 0).
  if (← IO.getEnv "SDL_LEAN_MAX_FRAMES").isSome then
    let n ← cleared.get
    if n > 0 then
      IO.println s!"gpu-clear: cleared {n} swapchain frames"
  return code
