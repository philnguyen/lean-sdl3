import Sdl
import Tests.Harness

/-!
# SDL_ttf core runtime tests

Everything here runs fully headless with NO `Sdl.init` — `Ttf.init` is enough
for font open/metrics/render-to-surface (probe-verified on macOS, SDL_ttf
3.2.2). Uses a system font if one is present; on a machine without any of the
probed fonts the whole group degenerates to a single skip check (CI safety).

Registers nothing — the entry point wires `test/Tests.lean`.
-/

namespace Tests.Ttf
open Sdl Sdl.Ttf Tests.Harness

/-- First of the probed system fonts (macOS, then common Linux paths) that
exists on disk. -/
def systemFontPath : IO (Option String) := do
  let candidates := [
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/Monaco.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",     -- Debian/Ubuntu
    "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",   -- Fedora
    "/usr/share/fonts/TTF/DejaVuSans.ttf",                 -- Arch
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"]
  for p in candidates do
    if ← System.FilePath.pathExists p then
      return some p
  return none

/-- Opaque white and an opaque black background. -/
def white : Color := ⟨255, 255, 255, 255⟩
def black : Color := ⟨0, 0, 0, 255⟩

/-- Init + version checks (before any font is opened). -/
def initChecks : IO Unit := do
  check "wasInit 0 before init" ((← Ttf.wasInit) == 0)
  Ttf.init
  check "wasInit 1 after init" ((← Ttf.wasInit) == 1)
  check "version ≥ 3002002" ((← Ttf.version) ≥ 3002002)
  let (maj, _, _) ← Ttf.getFreeTypeVersion
  check "freetype major > 0 after init" (maj > 0)

/-- Attribute getters/setters and their round-trips. -/
def attrChecks (font : Font) (isHelvetica : Bool) : IO Unit := do
  check "familyName nonempty" ((← font.familyName).length > 0)
  check "height > 0" ((← font.height) > 0)
  check "ascent > 0" ((← font.ascent) > 0)
  check "descent < 0" ((← font.descent) < 0)
  check "numFaces ≥ 1" ((← font.numFaces) ≥ 1)
  check "isScalable" (← font.isScalable)
  check "weight > 0" ((← font.weight) > 0)
  if isHelvetica then
    check "Helvetica weight == 400" ((← font.weight) == 400)
    check "Helvetica height == 24" ((← font.height) == 24)
  -- size round-trip
  font.setSize 32
  check "size == 32 after setSize" ((← font.size) == 32)
  font.setSize 24
  check "size == 24 restored" ((← font.size) == 24)
  -- style round-trip
  font.setStyle (.bold ||| .italic)
  check "style == bold|italic" ((← font.style) == (FontStyle.bold ||| FontStyle.italic))
  font.setStyle .none
  check "style == none restored" ((← font.style) == FontStyle.none)
  -- outline / lineSkip / kerning / wrapAlignment / hinting / SDF
  font.setOutline 2
  check "outline == 2" ((← font.outline) == 2)
  font.setOutline 0
  font.setLineSkip 30
  check "lineSkip == 30" ((← font.lineSkip) == 30)
  font.setKerning false
  check "kerning == false" ((← font.kerning) == false)
  font.setKerning true
  font.setWrapAlignment .center
  check "wrapAlignment == center" ((← font.wrapAlignment) == .center)
  font.setWrapAlignment .left
  font.setHinting .mono
  check "hinting == mono" ((← font.hinting) == .mono)
  font.setHinting .normal
  font.setSDF true
  check "sdf == true" (← font.sdf)
  font.setSDF false
  check "sdf == false restored" ((← font.sdf) == false)

/-- Direction and script shaping round-trips. -/
def scriptChecks (font : Font) : IO Unit := do
  check "direction default == invalid" ((← font.direction) == .invalid)
  font.setDirection .rtl
  check "direction == rtl" ((← font.direction) == .rtl)
  font.setDirection .ltr
  check "direction == ltr restored" ((← font.direction) == .ltr)
  let latn := stringToTag "Latn"
  check "stringToTag/tagToString round-trips" (tagToString latn == "Latn")
  check "getGlyphScript 'A' == Latn" ((← getGlyphScript 'A') == latn)
  font.setScript latn
  check "script == Latn after setScript" ((← font.script) == latn)

/-- Glyph queries and rendering. -/
def glyphChecks (font : Font) (isHelvetica : Bool) : IO Unit := do
  check "hasGlyph 'A'" (← font.hasGlyph 'A')
  if isHelvetica then
    check "NOT hasGlyph emoji" ((← font.hasGlyph (Char.ofNat 0x1F600)) == false)
  let m ← font.glyphMetrics 'A'
  check "glyphMetrics 'A' advance > 0" (m.advance > 0)
  let (gsurf, gtype) ← font.glyphImage 'A'
  check "glyphImage 'A' w > 0" ((← gsurf.width) > 0)
  check "glyphImage 'A' h > 0" ((← gsurf.height) > 0)
  check "glyphImage 'A' type == alpha" (gtype == .alpha)
  let text := "Hello, Lean!"
  let (sw, sh) ← font.stringSize text
  check "stringSize width > 0" (sw > 0)
  check "stringSize height == font height" (sh == (← font.height))
  let (mw, mlen) ← font.measureString text 60
  check "measureString width ≤ 60" (mw ≤ 60)
  check "measureString length < text bytes" (mlen < text.toUTF8.size)
  -- Blended render (ARGB8888)
  let bsurf ← font.renderBlended "Hello" white
  check "renderBlended width > 0" ((← bsurf.width) > 0)
  check "renderBlended height == font height" ((← bsurf.height) == (← font.height))
  check "renderBlended format == argb8888" ((← bsurf.format) == .argb8888)
  if isHelvetica then
    let px ← bsurf.readPixel 2 1
    check "renderBlended (2,1) opaque white" (px.a == 255 && px.r == 255)
  -- Solid + Shaded succeed (no pixel pins)
  let _ ← font.renderSolid "Hello" white
  check "renderSolid succeeds" true
  let _ ← font.renderShaded "Hello" white black
  check "renderShaded succeeds" true

/-- Copy, IOStream-backed open, and fallback-font management. -/
def lifecycleChecks (path : String) (font : Font) : IO Unit := do
  let fam ← font.familyName
  let copy ← font.copy
  check "copy familyName matches" ((← copy.familyName) == fam)
  -- const-mem IOStream-backed open keeps the ByteArray alive by RC
  let bytes ← IO.FS.readBinFile path
  let stream ← ioFromConstMem bytes
  let ioFont ← openFontIO stream 24
  check "openFontIO familyName matches" ((← ioFont.familyName) == fam)
  -- fallback fonts (Monaco if present, else the same file again): just no throw
  let fbPath := "/System/Library/Fonts/Monaco.ttf"
  let fb ← if ← System.FilePath.pathExists fbPath then openFont fbPath 24 else font.copy
  font.addFallbackFont fb
  font.removeFallbackFont fb
  font.clearFallbackFonts
  check "fallback add/remove/clear no throw" true

def run : IO Unit := do
  match ← systemFontPath with
  | none =>
    check "no system font found (skipping)" true
  | some path =>
    initChecks
    let isHelvetica := path == "/System/Library/Fonts/Helvetica.ttc"
    let font ← openFont path 24
    attrChecks font isHelvetica
    scriptChecks font
    glyphChecks font isHelvetica
    lifecycleChecks path font
    checkThrows "openFont nonexistent throws" (openFont "/nonexistent.ttf" 24)
    Ttf.quit

end Tests.Ttf
