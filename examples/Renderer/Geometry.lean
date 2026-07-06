import Common

/-!
# renderer/10-geometry

Creates an SDL window and renderer, then draws some geometry (arbitrary
polygons) to it every frame: a single colored triangle that grows and shrinks,
a textured triangle, and a textured quad built from two triangles sharing
vertices via an index buffer.

Port of the official example `examples/renderer/10-geometry/geometry.c`
(https://examples.libsdl.org/SDL3/renderer/10-geometry/).

## Deviations
- Assets: the C uses `SDL_GetBasePath() + "sample.png"`; here we resolve the
  vendored asset with `Examples.assetPath` (see `examples/Common.lean`).
-/

open Sdl

def windowWidth : Float := 640
def windowHeight : Float := 480

structure State where
  window : Window
  renderer : Renderer
  texture : Texture

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Renderer Geometry" "1.0" "com.example.renderer-geometry"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/geometry" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- Load a .png into a surface, move it to a texture from there.
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texture ← renderer.createTextureFromSurface surface
    return (.continue, some { window, renderer, texture })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let now ← getTicks
    -- have the triangle grow and shrink over a few seconds.
    let direction : Float := if now % 2000 >= 1000 then 1.0 else -1.0
    let scale := ((now % 1000).toFloat - 500.0) / 500.0 * direction
    let size := 200.0 + 200.0 * scale

    -- rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255  -- black, full alpha
    s.renderer.clear

    -- A single triangle with a different color at each vertex, centered.
    let tri : Array Vertex := #[
      { position := ⟨(windowWidth / 2).toFloat32, ((windowHeight - size) / 2).toFloat32⟩,
        color := ⟨1, 0, 0, 1⟩, texCoord := ⟨0, 0⟩ },
      { position := ⟨((windowWidth + size) / 2).toFloat32, ((windowHeight + size) / 2).toFloat32⟩,
        color := ⟨0, 1, 0, 1⟩, texCoord := ⟨0, 0⟩ },
      { position := ⟨((windowWidth - size) / 2).toFloat32, ((windowHeight + size) / 2).toFloat32⟩,
        color := ⟨0, 0, 1, 1⟩, texCoord := ⟨0, 0⟩ }]
    s.renderer.geometry none tri

    -- Map a texture to the geometry. Texture coordinates go from 0.0 to 1.0.
    let white : FColor := ⟨1, 1, 1, 1⟩
    let quad : Array Vertex := #[
      { position := ⟨10, 10⟩,  color := white, texCoord := ⟨0, 0⟩ },
      { position := ⟨150, 10⟩, color := white, texCoord := ⟨1, 0⟩ },
      { position := ⟨10, 150⟩, color := white, texCoord := ⟨0, 1⟩ }]
    s.renderer.geometry (some s.texture) quad

    -- Multiple triangles sharing vertices, using indices, to draw the whole
    -- texture. Move it over so it doesn't overlap, then add a 4th vertex.
    let shifted := quad.map (fun v => { v with position := ⟨v.position.x + 450, v.position.y⟩ })
    let quad2 := shifted.push
      { position := ⟨600, 150⟩, color := white, texCoord := ⟨1, 1⟩ }
    -- 4 vertices, but 6 places they are used.
    s.renderer.geometry (some s.texture) quad2 #[0, 1, 2, 1, 2, 3]

    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
