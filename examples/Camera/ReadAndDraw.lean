import Common

/-!
# camera/read-and-draw

Reads frames from the first available camera and draws each one to the window.
A very simple approach: request _anything_ and go with whatever the camera
hands back, in whatever pixel format it chooses.

Port of the official example `examples/camera/read-and-draw/read-and-draw.c`
(https://examples.libsdl.org/SDL3/camera/read-and-draw/).

## Deviations
- **No-device path**: the C example returns `SDL_APP_FAILURE` when
  `SDL_GetCameras` reports zero devices. We instead log "No camera devices
  found." and exit `0` (success). Reason: this repo's CI smoke-runs demos
  headless under `SDL_CAMERA_DRIVER=dummy`, where zero devices is the expected,
  non-error state — failing there would break the smoke gate. The
  device-enumeration error itself (a `null` return in C) still throws, since
  `Camera.getCameras` throws on genuine failure (an empty array is not one).
- **Pixel upload**: the C uploads frame pixels with `SDL_UpdateTexture`. This
  binding does not expose that raw-pointer path for the camera surface; instead
  we lock the streaming texture to a `Surface` and `Surface.blit` the camera
  frame onto it (blit handles any pitch/stride differences), then `unlock` to
  upload — the same lock-to-surface idiom used by `renderer/07-streaming-textures`.
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer
  camera : Camera
  /-- Created lazily from the first frame's format/size (`none` until then). -/
  texture : IO.Ref (Option Texture)

def app : App State where
  init _ := do
    setAppMetadata "Example Camera Read and Draw" "1.0" "com.example.camera-read-and-draw"
    Sdl.init (.video ||| .camera)
    let (window, renderer) ←
      createWindowAndRenderer "examples/camera/read-and-draw" 640 480 .resizable
    -- C: SDL_GetCameras. An empty array is normal under the dummy driver — see
    -- Deviations. `getCameras` throws on genuine enumeration failure.
    let devices ← getCameras
    if devices.isEmpty then
      Sdl.log "No camera devices found."
      return (.success, none)
    -- Just take the first device, in any format it wants (spec := none).
    let camera ← openCamera devices[0]!
    let texture ← IO.mkRef none
    return (.continue, some { window, renderer, camera, texture })
  event _ e := do
    match e with
    | .quit _ => return .success
    | .cameraDeviceApproved _ =>
      Sdl.log "Camera use approved by user!"
      return .continue
    | .cameraDeviceDenied _ =>
      Sdl.log "Camera use denied by user!"
      return .failure
    | _ => return .continue
  iterate s := do
    -- C: SDL_AcquireCameraFrame. `none` = no new frame ready yet (normal).
    if let some (frame, _ts) ← s.camera.acquireFrame then
      -- Some platforms don't know what the camera offers until access is
      -- granted, so build the texture and size the window from the first frame.
      if (← s.texture.get).isNone then
        let w ← frame.width
        let h ← frame.height
        s.window.setSize w h                                    -- match the frame
        s.renderer.setLogicalPresentation w h .letterbox
        let fmt ← frame.format
        let tex ← s.renderer.createTexture fmt .streaming w h   -- frame's own format
        s.texture.set (some tex)
      if let some tex ← s.texture.get then
        -- Lock the streaming texture to a surface, blit the camera frame onto it
        -- (blit copies with any pitch difference), then unlock to upload.
        let locked ← tex.lockToSurface
        frame.blit none locked none
        tex.unlock
      -- Release the frame promptly, before rendering (SDL keeps a small pool).
      s.camera.releaseFrame frame
    s.renderer.setDrawColor 0x99 0x99 0x99 255
    s.renderer.clear
    if let some tex ← s.texture.get then
      s.renderer.texture tex none none
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
