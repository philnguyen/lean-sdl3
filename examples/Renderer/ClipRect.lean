import Common

/-!
# renderer/15-cliprect

Creates an SDL window and renderer, then stretches a texture across the whole
window every frame while sliding a clipping rectangle around, so only the piece
of the scene inside the clip rect actually renders.

Port of the official example `examples/renderer/15-cliprect/cliprect.c`
(https://examples.libsdl.org/SDL3/renderer/15-cliprect/).

## Deviations
- Assets: the C uses `SDL_GetBasePath() + "sample.png"`; here we resolve the
  vendored asset with `Examples.assetPath` (see `examples/Common.lean`).
-/

open Sdl

def windowWidth : Float32 := 640
def windowHeight : Float32 := 480
def cliprectSize : Float32 := 250
def cliprectSpeed : Float32 := 200  -- pixels per second

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  position : IO.Ref FPoint
  direction : IO.Ref FPoint
  lastTime : IO.Ref UInt64

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Clipping Rectangle" "1.0" "com.example.renderer-cliprect"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/cliprect" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let position ← IO.mkRef ⟨0, 0⟩
    let direction ← IO.mkRef ⟨1, 1⟩
    let lastTime ← IO.mkRef (← getTicks)
    -- Load a .png into a surface, move it to a texture from there.
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texture ← renderer.createTextureFromSurface surface
    return (.continue, some { window, renderer, texture, position, direction, lastTime })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let pos ← s.position.get
    let cliprect : Rect := ⟨pos.x.round.toInt32, pos.y.round.toInt32,
      cliprectSize.toInt32, cliprectSize.toInt32⟩
    let now ← getTicks
    let elapsed := (now - (← s.lastTime.get)).toFloat32 / 1000.0  -- seconds since last iteration
    let distance := elapsed * cliprectSpeed

    -- Set a new clipping rectangle position.
    let dir ← s.direction.get
    let mut px := pos.x + distance * dir.x
    let mut dx := dir.x
    if px < -cliprectSize then
      px := -cliprectSize
      dx := 1.0
    else if px >= windowWidth then
      px := windowWidth - 1
      dx := -1.0

    let mut py := pos.y + distance * dir.y
    let mut dy := dir.y
    if py < -cliprectSize then
      py := -cliprectSize
      dy := 1.0
    else if py >= windowHeight then
      py := windowHeight - 1
      dy := -1.0

    s.position.set ⟨px, py⟩
    s.direction.set ⟨dx, dy⟩
    s.renderer.setClipRect (some cliprect)
    s.lastTime.set now

    -- Note that clear is _not_ affected by the clipping rectangle!
    s.renderer.setDrawColor 33 33 33 255  -- grey, full alpha
    s.renderer.clear

    -- Stretch the texture across the entire window. Only the piece in the
    -- clipping rectangle will actually render, though!
    s.renderer.texture s.texture

    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
