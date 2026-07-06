import Common

/-!
# renderer/20-blending

Demonstrates blend modes. Blending combines a source color `src` with the
pixels already on the screen `dst` to produce transparency and other effects
(`dst := (a * dst) op (b * src)`). Six checkerboard panels show the built-in
blend modes NONE/BLEND/ADD/MOD/MUL and a custom "screen" mode composed with
`composeCustomBlendMode`, each applied to overlapping red/green/blue rects whose
alpha is adjustable with the UP/DOWN arrow keys.

Port of the official example `examples/renderer/20-blending/blending.c`
(https://examples.libsdl.org/SDL3/renderer/20-blending/).

## Deviations
- `SDL_RenderDebugTextFormat` is C varargs and is not bound; the ALPHA readout
  is formatted with Lean string interpolation (`s!"…"`) and drawn with `debugText`.
- `SDL_SetTextureBlendMode` returns a "supported" boolean in C; the Lean binding
  throws on an unsupported mode instead, so `trySetBlend` recovers that boolean
  with `try`/`catch` (used, as in the C, to flag `[UNSUPPORTED]` panels).
- The 50×50 source `Surface` is not destroyed (surfaces are finalizer-only here,
  by binding design) where the C calls `SDL_DestroySurface`.
-/

open Sdl

def windowWidth : Float32 := 640
def windowHeight : Float32 := 480
def gridSize : Float32 := (640 - 1) / 18.0
def panelSize : Float32 := gridSize * 4
def rowOffset : Float32 := (windowHeight - 2 * panelSize) / 4
def colOffset : Float32 := gridSize * 3
def rectSize : Float32 := 50.0
def redOffset : Float32 := gridSize
def greenOffset : Float32 := rectSize / 3 + gridSize
def blueOffset : Float32 := rectSize * 2 / 3 + gridSize

structure State where
  window : Window
  renderer : Renderer
  redTex : Texture
  greenTex : Texture
  blueTex : Texture
  panels : Array FRect
  blendModes : Array BlendMode
  blendModeNames : Array String
  alpha : IO.Ref UInt8

/-- Set a texture's blend mode, returning whether the renderer supports it. SDL
returns `false` for an unsupported mode; the Lean binding turns that into a
thrown error, so recover the boolean via `try`/`catch`. -/
def trySetBlend (t : Texture) (mode : BlendMode) : IO Bool := do
  try
    t.setBlendMode mode
    return true
  catch _ =>
    return false

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Blending" "1.0" "com.example.blending"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/blending" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox

    -- Lay out the ROWS×COLS panel grid.
    let mut panels : Array FRect := #[]
    for row in [0:2] do
      for col in [0:3] do
        let cf := col.toFloat.toFloat32
        let rf := row.toFloat.toFloat32
        let rf1 := (row + 1).toFloat.toFloat32
        panels := panels.push
          ⟨cf * panelSize + cf * colOffset, rf * panelSize + rf1 * rowOffset, panelSize, panelSize⟩

    -- Our custom "screen" blend: dstRGB := 1 - (1 - dstRGB) * (1 - srcRGB).
    let screen := composeCustomBlendMode
      .oneMinusDstColor  -- srcRGB factor := (1 - dstRGB)
      .one               -- dstRGB factor := 1
      .add               -- RGB operation := +
      .zero              -- srcA factor   := 0
      .one               -- dstA factor   := dstA
      .add               -- A operation   := +
    let blendModes : Array BlendMode := #[.none, .blend, .add, .mod, .mul, screen]
    let blendModeNames : Array String := #["NONE", "BLEND", "ADD", "MOD", "MUL", "SCREEN \"CUSTOM\""]

    -- One 50×50 surface, refilled for each of the three colored textures.
    let surface ← createSurface rectSize.toInt32 rectSize.toInt32 .rgba8888
    surface.fillRect none 0xFF0000FF  -- Red
    let redTex ← renderer.createTextureFromSurface surface
    surface.fillRect none 0x00FF00FF  -- Green
    let greenTex ← renderer.createTextureFromSurface surface
    surface.fillRect none 0x0000FFFF  -- Blue
    let blueTex ← renderer.createTextureFromSurface surface

    let alpha ← IO.mkRef (255 : UInt8)
    return (.continue, some
      { window, renderer, redTex, greenTex, blueTex, panels, blendModes, blendModeNames, alpha })
  event := fun s e => do
    match e with
    | .quit _ => return .success
    | .keyDown ke =>
      -- UP arrow increases alpha, DOWN decreases it (by 8, clamped).
      if ke.key == Keycode.up then
        let a ← s.alpha.get
        if a <= 255 - 8 then s.alpha.set (a + 8)
      else if ke.key == Keycode.down then
        let a ← s.alpha.get
        if a >= 8 then s.alpha.set (a - 8)
      return .continue
    | _ => return .continue
  iterate := fun s => do
    let r := s.renderer
    r.setDrawColor 0 0 0 255
    r.clear

    -- Render checkerboard panels and their labels.
    for i in [0:s.panels.size] do
      let panel := s.panels[i]!
      let mut y := panel.y
      while y < panelSize + panel.y do
        let mut x := panel.x
        while x < panelSize + panel.x do
          let grid : FRect := ⟨x, y, gridSize, gridSize⟩
          let dark := (x / gridSize + y / gridSize).toInt32 % 2 != 0
          if dark then r.setDrawColor 70 70 70 255    -- darker
          else r.setDrawColor 110 110 110 255         -- lighter
          r.fillRect (some grid)
          x := x + gridSize
        y := y + gridSize
      -- Label the blend mode.
      r.setDrawColor 255 255 255 255
      r.debugText panel.x (panel.y - 15) s.blendModeNames[i]!

    -- Panel outlines.
    r.rects s.panels

    -- UI text.
    r.debugText ((windowWidth - 176) / 2) (windowHeight - 30) "UP/DOWN: CHANGE ALPHA"
    let alpha ← s.alpha.get
    r.debugText ((windowWidth - 80) / 2) (windowHeight - 20) s!"ALPHA: {alpha}"

    -- Update textures' alpha mod.
    s.redTex.setAlphaMod alpha
    s.greenTex.setAlphaMod alpha
    s.blueTex.setAlphaMod alpha

    -- Render the colored rects into each panel with that panel's blend mode.
    for i in [0:s.panels.size] do
      let panel := s.panels[i]!
      let redDst : FRect := ⟨panel.x + redOffset, panel.y + redOffset, rectSize, rectSize⟩
      let greenDst : FRect := ⟨panel.x + greenOffset, panel.y + greenOffset, rectSize, rectSize⟩
      let blueDst : FRect := ⟨panel.x + blueOffset, panel.y + blueOffset, rectSize, rectSize⟩
      let mode := s.blendModes[i]!
      let supported ← trySetBlend s.redTex mode  -- check whether the renderer supports it
      let _ ← trySetBlend s.greenTex mode
      let _ ← trySetBlend s.blueTex mode
      r.texture s.redTex (dstRect := some redDst)
      r.texture s.greenTex (dstRect := some greenDst)
      r.texture s.blueTex (dstRect := some blueDst)
      -- Not all renderers support all blend modes; flag the ones that don't.
      unless supported do
        let textwidth : Float32 := 104.0
        let dst : FRect := ⟨panel.x + (panel.w - textwidth) / 2, panel.y + (panel.h - 8), textwidth, 8⟩
        r.setDrawColor 0 0 0 255
        r.fillRect (some dst)
        r.setDrawColor 255 255 255 255
        r.debugText dst.x dst.y "[UNSUPPORTED]"

    r.present
    return .continue

def main : IO UInt32 := Examples.runApp app
