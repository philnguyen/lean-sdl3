import Sdl
import Tests.Harness

namespace Tests.Clipboard
open Sdl Tests.Harness

/-- True iff `needle` occurs somewhere in `haystack`. -/
private def containsStr (haystack needle : String) : Bool :=
  (haystack.splitOn needle).length > 1

/-- Clipboard tests (run under `SDL_VIDEO_DRIVER=dummy`, after the Video group).
Exercises the text clipboard and primary-selection round-trips, the mime-type
listing, and the mime-typed data path via the generic clipboard layer. Adds its
own `Sdl.init .video` (reference-counted) so the group is self-sufficient. No
MessageBox tests: on macOS they open a real blocking dialog. -/
def run : IO Unit := do
  Sdl.init .video

  -- text clipboard round-trip
  let probe := "lean-sdl3 clipboard probe"
  setClipboardText probe
  check "hasClipboardText true after set" (← hasClipboardText)
  check "getClipboardText round-trips" ((← getClipboardText) == probe)

  -- empty text clears the clipboard (SDL treats "" as clearing); relax to
  -- no-throw if a driver disagrees
  setClipboardText ""
  check "hasClipboardText false after empty" (!(← hasClipboardText))

  -- primary selection round-trip (generic layer backs it under the dummy driver)
  setPrimarySelectionText probe
  check "hasPrimarySelectionText true after set" (← hasPrimarySelectionText)
  check "getPrimarySelectionText round-trips" ((← getPrimarySelectionText) == probe)
  setPrimarySelectionText ""
  check "hasPrimarySelectionText false after empty" (!(← hasPrimarySelectionText))

  -- re-set the probe, then inspect the mime types and mime-typed data
  setClipboardText probe
  let mimeTypes ← getClipboardMimeTypes
  check "getClipboardMimeTypes no-throw" true
  if mimeTypes.isEmpty then
    check "mime types empty on this driver (tolerated)" true
  else
    check "mime types contain a text/plain entry"
      (mimeTypes.any (fun m => "text/plain".isPrefixOf m))
    let mime := mimeTypes[0]!
    check "hasClipboardData true for first mime" (← hasClipboardData mime)
    let data ← getClipboardData mime
    match String.fromUTF8? data with
    | some decoded =>
      check "getClipboardData contains probe text" (containsStr decoded probe)
    | none =>
      check "getClipboardData decodes as UTF-8" false

  -- clearClipboardData empties the text clipboard
  clearClipboardData
  check "hasClipboardText false after clear" (!(← hasClipboardText))

end Tests.Clipboard
