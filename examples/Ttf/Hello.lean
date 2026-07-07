import Common

/-!
# ttf/01-hello

Opens a system font with SDL_ttf, creates a renderer `TextEngine` and a
`Text` object, and draws "Hello from Lean + SDL_ttf!" centered in the window
with a slowly color-cycling tint; a static caption below names the font.

There is no official SDL_ttf example at examples.libsdl.org; this demo mirrors
the renderer examples' shape using the `Sdl.Ttf` API (M14).

## Deviations
- Uses the first available macOS system font (Helvetica/Monaco/Arial); if none
  exists the demo prints a note and exits successfully, keeping headless smoke
  runs green on font-less machines.
-/

open Sdl Sdl.Ttf

def winW : Int32 := 640
def winH : Int32 := 480

/-- The first macOS system font present on disk (same candidates as `test/`). -/
def findSystemFont : IO (Option String) := do
  let candidates := [
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Monaco.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf"]
  for p in candidates do
    if ← System.FilePath.pathExists p then
      return some p
  return none

structure State where
  window : Window
  renderer : Renderer
  text : Text
  caption : Text
  frames : IO.Ref Nat

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Ttf Hello" "1.0" "com.example.ttf-hello"
    let some path ← findSystemFont
      | IO.eprintln "ttf-hello: no system font found, skipping"
        return (.success, none)
    Sdl.init .video
    Ttf.init
    let (window, renderer) ← createWindowAndRenderer "examples/ttf/hello" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let font ← openFont path 48
    let engine ← createRendererTextEngine renderer
    -- The Text pins both the engine and the font by reference count.
    let text ← engine.createText font "Hello from Lean + SDL_ttf!"
    let caption ← engine.createText font s!"{← font.familyName} at {← font.height}px"
    let capFont ← font.copy
    capFont.setSize 20
    caption.setFont capFont
    caption.setColor ⟨160, 160, 160, 255⟩
    return (.continue, some { window, renderer, text, caption, frames := ← IO.mkRef 0 })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    let r := s.renderer
    r.setDrawColor 20 20 30 255
    r.clear
    -- Cycle the headline color through the hue-ish phases.
    let t := (← getTicks).toFloat / 1000
    let chan (phase : Float) : UInt8 :=
      (160 + 95 * Float.sin (t + phase)).toUInt8
    s.text.setColor ⟨chan 0, chan 2, chan 4, 255⟩
    -- Center both lines from their current layout sizes.
    let (tw, th) ← s.text.size
    let (cw, _) ← s.caption.size
    s.text.drawRenderer ((winW - tw).toFloat32 / 2) ((winH - th).toFloat32 / 2)
    s.caption.drawRenderer ((winW - cw).toFloat32 / 2) ((winH + th).toFloat32 / 2 + 8)
    r.present
    s.frames.modify (· + 1)
    return .continue
  quit := fun s _res => do
    IO.println s!"ttf-hello: drew {← s.frames.get} frames"

def main : IO UInt32 := Examples.runApp app
