import Common

/-!
# renderer/19-affine-textures

Draws a spinning cube by rendering a PNG texture onto each visible face with an
affine transform. Each frame builds a rotation matrix (axis `(3,4,5)/√50`,
angle sweeping a full turn every two seconds), projects the eight cube corners,
and renders the (up to three) front-facing faces with `renderTextureAffine`.

Port of the official example
`examples/renderer/19-affine-textures/affine-textures.c`
(https://examples.libsdl.org/SDL3/renderer/19-affine-textures/).

## Deviations
- Assets: the C example builds the PNG path from `SDL_GetBasePath()`. Here we
  load the vendored `examples/assets/sample.png` via `Examples.assetPath`.
- Surfaces are finalizer-only in this binding, so the C `SDL_DestroySurface`
  becomes letting the surface go out of scope.
- The matrix/corner math runs in `Float` (64-bit) and converts to `Float32`
  only at the `FPoint` boundary, per the repo's math convention. The C uses
  32-bit `float` throughout; results are equivalent for this demo.
-/

open Sdl

def windowWidth : Float := 640.0
def windowHeight : Float := 480.0

structure State where
  window : Window
  renderer : Renderer
  /-- The static texture painted onto each cube face. -/
  texture : Texture

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Renderer Affine Textures" "1.0"
      "com.example.renderer-affine-textures"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/affine-textures" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let surface ← loadPNG (← Examples.assetPath "sample.png").toString
    let texture ← renderer.createTextureFromSurface surface
    return (.continue, some { window, renderer, texture })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let x0 := 0.5 * windowWidth
    let y0 := 0.5 * windowHeight
    let px := (min windowWidth windowHeight) / Float.sqrt 3.0

    let now ← getTicks
    let rad := ((now % 2000).toFloat / 2000.0) * Examples.pi * 2.0
    let cos := Float.cos rad
    let sin := Float.sin rad
    let sqrt50 := Float.sqrt 50.0
    let k0 := 3.0 / sqrt50
    let k1 := 4.0 / sqrt50
    let k2 := 5.0 / sqrt50
    let omc := 1.0 - cos
    -- Rodrigues rotation matrix (row-major, 3x3) for axis (k0,k1,k2).
    let mat : Array Float := #[
      cos       + omc*k0*k0,  -sin*k2 + omc*k0*k1,   sin*k1 + omc*k0*k2,
      sin*k2    + omc*k0*k1,   cos    + omc*k1*k1,   -sin*k0 + omc*k1*k2,
      -sin*k1   + omc*k0*k2,   sin*k0 + omc*k1*k2,    cos    + omc*k2*k2 ]

    -- Project the eight cube corners: `corners[2*i], corners[2*i+1]` are the
    -- rotated x,y of corner i (the ±0.5 cube). z is dropped (orthographic).
    let mut corners : Array Float := Array.replicate 16 0.0
    for i in [0:8] do
      let x : Float := if (i &&& 1) != 0 then -0.5 else 0.5
      let y : Float := if (i &&& 2) != 0 then -0.5 else 0.5
      let z : Float := if (i &&& 4) != 0 then -0.5 else 0.5
      corners := corners.set! (2*i)     (mat[0]!*x + mat[1]!*y + mat[2]!*z)
      corners := corners.set! (2*i + 1) (mat[3]!*x + mat[4]!*y + mat[5]!*z)

    s.renderer.setDrawColor 0x42 0x87 0xf5 255  -- light blue background.
    s.renderer.clear

    -- For each of the six faces (encoded by i), pick the face's axis (`dir`)
    -- and winding (`odd`), cull the back-facing ones, then render the texture
    -- across its three defining corners.
    for i in [1:7] do
      let dir := if (i &&& 4) != 0 then (i &&& 3) ^^^ 3 else i &&& 3
      let odd := (i &&& 1) ^^^ ((i &&& 2) >>> 1) ^^^ ((i &&& 4) >>> 2)
      let sign : Float := if odd != 0 then 1.0 else -1.0
      if 0.0 < sign * mat[5 + dir]! then
        continue
      let mut originIdx := 1 <<< ((dir - 1) % 3)
      let mut rightIdx := (1 <<< ((dir + odd) % 3)) ||| originIdx
      let mut downIdx := (1 <<< ((dir + (odd ^^^ 1)) % 3)) ||| originIdx
      if odd == 0 then
        originIdx := originIdx ^^^ 7
        rightIdx := rightIdx ^^^ 7
        downIdx := downIdx ^^^ 7
      let origin : FPoint :=
        { x := (x0 + px * corners[2*originIdx]!).toFloat32,
          y := (y0 + px * corners[2*originIdx + 1]!).toFloat32 }
      let right : FPoint :=
        { x := (x0 + px * corners[2*rightIdx]!).toFloat32,
          y := (y0 + px * corners[2*rightIdx + 1]!).toFloat32 }
      let down : FPoint :=
        { x := (x0 + px * corners[2*downIdx]!).toFloat32,
          y := (y0 + px * corners[2*downIdx + 1]!).toFloat32 }
      s.renderer.textureAffine s.texture none (some origin) (some right) (some down)

    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
