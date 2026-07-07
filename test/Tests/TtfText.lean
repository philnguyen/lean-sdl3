import Sdl
import Tests.Harness
import Tests.Ttf

/-!
# SDL_ttf text-engine runtime tests

Exercises `Sdl/Ttf/Text.lean`: the surface / renderer / GPU text engines,
`TTF_Text` editing / layout / substrings / draws, and the GPU draw-data decode.

The surface-engine block runs fully headless with only `Ttf.init` (no
`Sdl.init`). The renderer-engine block initializes the video subsystem and uses
the dummy driver's software renderer. The GPU-engine block is gated exactly like
`Tests/GpuPipeline.run`: under the dummy driver there is no GPU backend, so
`createDevice` throws and we assert the skip path (the orchestrator runs the
real-Metal pass). Reuses `Tests.Ttf.systemFontPath`; on a font-less machine the
whole group degenerates to a single skip check.

Registers nothing — the entry point wires `test/Tests.lean`.
-/

namespace Tests.TtfText
open Sdl Sdl.Ttf Tests.Harness

/-- `a` within `tol` of `b` (Float32). -/
private def approxF (a b : Float32) (tol : Float32 := 1e-3) : Bool := (a - b).abs <= tol

/-- Whether some pixel of `surf` in the box `[x0,x1) × [y0,y1)` is opaque red. -/
private def hasOpaqueRed (surf : Surface) (x0 x1 y0 y1 : Nat) : IO Bool := do
  let mut found := false
  for yy in [y0:y1] do
    for xx in [x0:x1] do
      let px ← surf.readPixel (Int32.ofNat xx) (Int32.ofNat yy)
      if px.r == 255 && px.a == 255 then
        found := true
  return found

/-- Surface engine: create/edit/measure a `Text`, substring queries, draw. -/
def surfaceBlock (isHelvetica : Bool) (font : Font) : IO Unit := do
  let eng ← createSurfaceTextEngine
  let text ← eng.createText font "Hello, Lean!"
  let (w, h) ← text.size
  if isHelvetica then
    check "surface Text size == (126,24)" (w == 126 && h == 24)
  else
    check "surface Text size > 0" (w > 0 && h > 0)
  -- color round-trips
  text.setColor ⟨255, 0, 0, 255⟩
  check "color round-trips (255,0,0,255)" ((← text.color) == ⟨255, 0, 0, 255⟩)
  let fc ← text.colorFloat
  check "colorFloat ≈ (1,0,0,1)"
    (approxF fc.r 1 && approxF fc.g 0 && approxF fc.b 0 && approxF fc.a 1)
  -- append grows the width, updates the string
  text.appendString " More"
  check "string after append" ((← text.string) == "Hello, Lean! More")
  let (w2, _) ← text.size
  check "width grows after append" (w2 > w)
  -- delete from the front
  text.deleteString 0 5
  check "string after delete" ((← text.string) == ", Lean! More")
  -- substrings over a two-line string
  text.setString "Two\nlines"
  text.update
  let s1 ← text.subString 1
  check "subString 1 offset==1 length==1" (s1.offset == 1 && s1.length == 1)
  check "subString 1 direction==ltr" (s1.flags.direction == .ltr)
  let sl ← text.subStringForLine 1
  check "subStringForLine 1 offset==4 length==5" (sl.offset == 4 && sl.length == 5)
  let range ← text.subStringsForRange 0 9
  check "subStringsForRange size==2" (range.size == 2)
  check "subStringsForRange [0].offset==0" (range.size > 0 && range[0]!.offset == 0)
  let s0 ← text.subString 0
  check "subString 0 has textStart" (s0.flags.has .textStart)
  let sn ← text.nextSubString s0
  check "nextSubString advances offset" (sn.offset > s0.offset)
  let sp ← text.prevSubString sn
  check "prevSubString goes back" (sp.offset < sn.offset)
  -- position / wrap round-trips
  text.setPosition 3 4
  check "position round-trips (3,4)" ((← text.position) == (3, 4))
  text.setWrapWidth 50
  check "wrapWidth round-trips 50" ((← text.wrapWidth) == 50)
  text.setWrapWidth 0
  text.setWrapWhitespaceVisible true
  check "wrapWhitespaceVisible true" (← text.wrapWhitespaceVisible)
  text.setWrapWhitespaceVisible false
  check "wrapWhitespaceVisible false" ((← text.wrapWhitespaceVisible) == false)
  -- draw onto an ARGB surface, look for the red glyph pixels
  text.setString "Hello"
  text.setColor ⟨255, 0, 0, 255⟩
  text.setPosition 0 0
  let surf ← createSurface 128 64 .argb8888
  text.drawSurface 2 2 surf
  check "drawSurface leaves an opaque red pixel" (← hasOpaqueRed surf 2 20 2 24)
  -- manual destroy is a leaf: every subsequent shim throws
  text.destroy
  checkThrows "size after destroy throws" text.size
  checkThrows "second destroy throws" text.destroy

/-- Renderer engine (dummy driver's software renderer). -/
def rendererBlock (path : String) (font : Font) : IO Unit := do
  Sdl.initSubSystem .video
  let win ← createWindow "ttf-text" 128 64
  let ren ← createRenderer win (some softwareRenderer)
  let eng ← createRendererTextEngine ren
  let text ← eng.createText font "Hi"
  text.drawRenderer 4 4
  ren.present
  check "renderer engine draw + present" true
  -- setFont: identity preserved through the pair (same family)
  let font2 ← openFont path 24
  let fam ← font2.familyName
  text.setFont font2
  check "setFont preserves family via Text.font" ((← (← text.font).familyName) == fam)
  -- setEngine to a fresh renderer engine; draw still works
  let eng2 ← createRendererTextEngine ren
  text.setEngine eng2
  text.drawRenderer 4 4
  ren.present
  check "draw after setEngine" true

/-- GPU engine, gated like `Tests/GpuPipeline.run` (no backend under dummy). -/
def gpuBlock (font : Font) : IO Unit := do
  Sdl.initSubSystem .video
  -- class check runs headless: a surface engine is not a GPU engine
  let seng ← createSurfaceTextEngine
  checkThrows "setGpuWinding on a surface engine throws" (seng.setGpuWinding .clockwise)
  let dev? ← try some <$> Gpu.createDevice (.msl ||| .metallib) true catch _ => pure none
  match dev? with
  | none =>
    check "no GPU backend ⇒ SDL_VIDEO_DRIVER is dummy"
      ((← IO.getEnv "SDL_VIDEO_DRIVER") == some "dummy")
    IO.println "  ok: no GPU backend under dummy driver (expected)"
  | some dev =>
    let eng ← createGpuTextEngine dev
    eng.setGpuWinding .counterClockwise
    check "gpuWinding round-trips" ((← eng.gpuWinding) == .counterClockwise)
    let text ← eng.createText font "Hi"
    let data ← text.gpuDrawData
    check "gpuDrawData nonempty" (data.size > 0)
    if h : data.size > 0 then
      let seq := data[0]
      let nv := seq.xy.size / 2
      check "first sequence numVertices > 0" (nv > 0)
      check "xy.size == 2 * numVertices" (seq.xy.size == 2 * nv)
      check "uv.size == 2 * numVertices" (seq.uv.size == 2 * nv)
      check "indices nonempty" (seq.indices.size > 0)
      check "imageType == alpha (report if not)" (seq.imageType == .alpha)

def run : IO Unit := do
  match ← Tests.Ttf.systemFontPath with
  | none =>
    check "no system font found (skipping)" true
  | some path =>
    Ttf.init
    let isHelvetica := path == "/System/Library/Fonts/Helvetica.ttc"
    let font ← openFont path 24
    surfaceBlock isHelvetica font
    rendererBlock path font
    gpuBlock font
    Ttf.quit

end Tests.TtfText
