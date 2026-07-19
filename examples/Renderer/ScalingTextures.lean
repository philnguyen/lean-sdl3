import Common

/-!
# renderer/09-scaling-textures

Loads a PNG into a static texture and draws it centered, growing and shrinking
over a few seconds.

Port of the official example
`examples/renderer/09-scaling-textures/scaling-textures.c`
(https://examples.libsdl.org/SDL3/renderer/09-scaling-textures/).

## Deviations
- Assets: the C example builds the PNG path from `SDL_GetBasePath()`. Here we
  load the vendored `examples/assets/sample.png` via `Examples.assetPath`.
- Surfaces are finalizer-only in this binding, so the C `SDL_DestroySurface`
  becomes letting the surface go out of scope.
-/

open Sdl

def windowWidth : Float := 640.0
def windowHeight : Float := 480.0

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  /-- Texture width in pixels (as `Float` for the per-frame geometry). -/
  texWidth : Float
  /-- Texture height in pixels. -/
  texHeight : Float

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Scaling Textures" "1.0"
      "com.example.renderer-scaling-textures"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/scaling-textures" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texWidth := (← surface.width).toFloat
    let texHeight := (← surface.height).toFloat
    let texture ← renderer.createTextureFromSurface surface
    return (.continue, some { window, renderer, texture, texWidth, texHeight })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let now ← getTicks
    -- grow and shrink the texture over a few seconds.
    let direction : Float := if now % 2000 ≥ 1000 then 1.0 else -1.0
    let scale : Float := ((now % 1000).toFloat - 500.0) / 500.0 * direction
    -- rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255  -- black, full alpha
    s.renderer.clear                    -- start with a blank canvas.
    -- center it and make it grow and shrink.
    let dstW : Float := s.texWidth + s.texWidth * scale
    let dstH : Float := s.texHeight + s.texHeight * scale
    s.renderer.texture s.texture none (some
      { x := ((windowWidth - dstW) / 2.0).toFloat32,
        y := ((windowHeight - dstH) / 2.0).toFloat32,
        w := dstW.toFloat32, h := dstH.toFloat32 })
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
