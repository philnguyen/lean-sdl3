import Sdl.Core.Macros
import Sdl.Error

/-!
# Clipboard access (`SDL_clipboard.h`)

Reading from and publishing to the system clipboard, plus the X11/Wayland
"primary selection" and arbitrary mime-typed data.

**Main thread only.** Per SDL, every function here should be called on the main
thread, and all require the video subsystem to be initialized (`Sdl.init
.video`).

`getClipboardText` / `getPrimarySelectionText` follow the SDL contract of
returning the empty string on failure *or* when the clipboard is empty — the two
are not distinguishable (a genuine allocation failure and an empty clipboard both
yield `""`).

`setClipboardData` offers mime-typed data lazily through a provider callback;
`clearClipboardData` cancels the offer.
-/

namespace Sdl

/-- Put UTF-8 `text` into the clipboard. Throws on failure.
C: `SDL_SetClipboardText`. -/
@[extern "lean_sdl_set_clipboard_text"]
opaque setClipboardText (text : @& String) : IO Unit

/-- The UTF-8 text currently in the clipboard, or `""` if the clipboard is empty
or unavailable (SDL returns `""` on failure too; the two cases are
indistinguishable). The SDL-allocated copy is freed after copying into Lean.
C: `SDL_GetClipboardText`. -/
@[extern "lean_sdl_get_clipboard_text"]
opaque getClipboardText : IO String

/-- Whether the clipboard exists and holds a non-empty text string.
C: `SDL_HasClipboardText`. -/
@[extern "lean_sdl_has_clipboard_text"]
opaque hasClipboardText : IO Bool

/-- Put UTF-8 `text` into the primary selection. Throws on failure. On platforms
without a primary selection SDL keeps a copy for later retrieval.
C: `SDL_SetPrimarySelectionText`. -/
@[extern "lean_sdl_set_primary_selection_text"]
opaque setPrimarySelectionText (text : @& String) : IO Unit

/-- The UTF-8 text currently in the primary selection, or `""` if empty or
unavailable (same indistinguishable-failure contract as `getClipboardText`).
C: `SDL_GetPrimarySelectionText`. -/
@[extern "lean_sdl_get_primary_selection_text"]
opaque getPrimarySelectionText : IO String

/-- Whether the primary selection exists and holds a non-empty text string.
C: `SDL_HasPrimarySelectionText`. -/
@[extern "lean_sdl_has_primary_selection_text"]
opaque hasPrimarySelectionText : IO Bool

/-- Clear the clipboard data (cancels any offer made via `SDL_SetClipboardData`).
Throws on failure. C: `SDL_ClearClipboardData`. -/
@[extern "lean_sdl_clear_clipboard_data"]
opaque clearClipboardData : IO Unit

/-- The clipboard data for `mimeType`, copied into a fresh `ByteArray` (the
SDL-allocated buffer is freed after copying). Throws when no data is offered for
that mime type (an SDL error). C: `SDL_GetClipboardData`. -/
@[extern "lean_sdl_get_clipboard_data"]
opaque getClipboardData (mimeType : @& String) : IO ByteArray

/-- Whether the clipboard holds data for `mimeType`. C: `SDL_HasClipboardData`. -/
@[extern "lean_sdl_has_clipboard_data"]
opaque hasClipboardData (mimeType : @& String) : IO Bool

/-- The list of mime types available in the clipboard (copied out). Throws on
failure (SDL returns `NULL`). C: `SDL_GetClipboardMimeTypes`. -/
@[extern "lean_sdl_get_clipboard_mime_types"]
opaque getClipboardMimeTypes : IO (Array String)

@[extern "lean_sdl_set_clipboard_data"]
private opaque setClipboardDataRaw (getData : String → IO ByteArray)
    (mimeTypes : @& Array String) : IO Unit

/-- Offer clipboard data for the given (nonempty) list of mime types, produced
lazily: `getData mime` runs when someone requests that mime type — possibly on
another thread, and possibly synchronously *during this call* on text-only or
headless backends. SDL copies the returned bytes immediately; the binding also
retains the last returned `ByteArray` until the next request or until the
offer ends. An exception in `getData` means "no data" for that request.

The offer ends — releasing the closure — when new clipboard content is set
(`setClipboardText`, another `setClipboardData`), on `clearClipboardData`, or
when the video subsystem quits. C: `SDL_SetClipboardData`. -/
def setClipboardData (mimeTypes : Array String)
    (getData : String → IO ByteArray) : IO Unit :=
  setClipboardDataRaw getData mimeTypes

end Sdl
