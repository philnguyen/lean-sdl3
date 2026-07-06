import Common

/-!
# renderer/07-streaming-textures

Creates a streaming texture and rewrites its pixels every frame: the whole
texture is cleared to black and a horizontal green strip slides up and down
over a few seconds. The texture is then drawn centered in the window.

Port of the official example
`examples/renderer/07-streaming-textures/streaming-textures.c`
(https://examples.libsdl.org/SDL3/renderer/07-streaming-textures/).

## Deviations
- Streaming update: the C example locks raw pixels with `SDL_LockTexture`, but
  this binding exposes streaming updates through `Texture.lockToSurface` (which
  wraps the locked pixels in a temporary `Surface`). We use that path
  exclusively, drawing with the surface fill functions, then `unlock` to upload.
-/

open Sdl

/-- The streaming texture is a 150x150 square. -/
def textureSize : Int32 := 150

def windowWidth : Float := 640.0
def windowHeight : Float := 480.0

structure State where
  window : Window
  renderer : Renderer
  /-- Streaming (lockable) RGBA8888 texture, rewritten every frame. -/
  texture : Texture

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Renderer Streaming Textures" "1.0"
      "com.example.renderer-streaming-textures"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/streaming-textures" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let texture ← renderer.createTexture .rgba8888 .streaming textureSize textureSize
    return (.continue, some { window, renderer, texture })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let now ← getTicks
    -- some color moves around over a few seconds.
    let direction : Float := if now % 2000 ≥ 1000 then 1.0 else -1.0
    let scale : Float := ((now % 1000).toFloat - 500.0) / 500.0 * direction
    -- Lock the streaming texture: this exposes it as a borrowed, write-only
    -- surface. Every locked pixel must be written (its contents are undefined).
    let surface ← s.texture.lockToSurface
    let fmt ← surface.format
    surface.fillRect none (← mapRGB fmt none 0 0 0)  -- whole surface black
    let stripH : Int32 := textureSize / 10
    let stripY : Int32 :=
      ((textureSize - stripH).toFloat * ((scale + 1.0) / 2.0)).toInt32
    surface.fillRect (some { x := 0, y := stripY, w := textureSize, h := stripH })
      (← mapRGB fmt none 0 255 0)                    -- a green strip
    s.texture.unlock                                 -- upload the changes.
    -- rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 66 66 66 255  -- grey, full alpha
    s.renderer.clear                       -- start with a blank canvas.
    -- Center the texture; it shows the latest pixels we drew while locked.
    let sizeF := textureSize.toFloat
    s.renderer.texture s.texture none (some
      { x := ((windowWidth - sizeF) / 2.0).toFloat32,
        y := ((windowHeight - sizeF) / 2.0).toFloat32,
        w := sizeF.toFloat32, h := sizeF.toFloat32 })
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
