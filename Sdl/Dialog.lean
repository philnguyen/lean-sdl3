import Sdl.Core.Macros
import Sdl.Error
import Sdl.Properties
import Sdl.Video

/-!
# File dialogs (`SDL_dialog.h`)

Native open/save/folder dialogs. Results arrive through a one-shot callback
that SDL invokes **exactly once** — synchronously (before the show-call
returns) for argument-validation errors, otherwise at some later point,
possibly on another thread. On macOS the dialog needs the main thread and a
running event loop (`Sdl.pumpEvents` / `Sdl.App`).

Filter patterns are semicolon-separated extension lists (`"jpg;png"`,
characters `[a-zA-Z0-9_.-]` only) or a lone `"*"` for all files; they must be
nonempty (SDL misvalidates the empty string). An invalid pattern makes the
callback fire synchronously with `.error`.

Skipped: `SDL_DialogFileFilter` as a C struct — filters cross the FFI as two
parallel string arrays. The `SDL_PROP_FILE_DIALOG_FILTERS_POINTER` property
cannot be set from Lean (raw pointer); use the direct functions for filters.
-/

namespace Sdl

/-- A filename filter: a display `name` and a `pattern` — a semicolon-separated
extension list (`"jpg;png"`) or `"*"` for all files. Must be nonempty.
C: `SDL_DialogFileFilter`. -/
structure DialogFileFilter where
  /-- Display name of the filter (e.g. shown in the dialog's dropdown). -/
  name : String
  /-- Extension list, e.g. `"jpg;png"`, or `"*"`. -/
  pattern : String
deriving Repr, BEq, Inhabited

/-- Outcome delivered to a file-dialog callback. -/
inductive DialogResult where
  /-- The dialog failed (the message is `SDL_GetError` at callback time). -/
  | error (msg : String)
  /-- The user chose nothing or dismissed the dialog. -/
  | cancelled
  /-- The user chose one or more paths. `filterIndex` is the selected filter's
  index into the `filters` array, or `none` when unavailable (no filters, or
  the platform cannot report it). -/
  | selected (paths : Array String) (filterIndex : Option UInt32)
deriving Repr, BEq, Inhabited

/-- Maker called from C to build a `DialogResult` (kind: 0 error, 1 cancelled,
2 selected; negative `filterIndex` encodes `none`). -/
@[export lean_sdl_mk_dialog_result]
private def mkDialogResult (kind : UInt8) (err : String) (paths : Array String)
    (filterIndex : Int32) : DialogResult :=
  match kind with
  | 0 => .error err
  | 1 => .cancelled
  | _ => .selected paths (if filterIndex < 0 then none else some filterIndex.toUInt32)

#guard mkDialogResult 0 "boom" #[] (-1) == .error "boom"
#guard mkDialogResult 1 "" #[] (-1) == .cancelled
#guard mkDialogResult 2 "" #["/a", "/b"] 1 == .selected #["/a", "/b"] (some 1)
#guard mkDialogResult 2 "" #["/a"] (-1) == .selected #["/a"] none

@[extern "lean_sdl_show_open_file_dialog"]
private opaque showOpenFileDialogRaw (cb : DialogResult → IO Unit)
    (window : @& Option Window) (filterNames filterPatterns : @& Array String)
    (defaultLocation : @& Option String) (allowMany : Bool) : IO Unit

/-- Show an "open file" dialog and deliver the outcome to `cb` (exactly once;
see the module docstring for threading). `window` makes the dialog modal to
that window; `defaultLocation` is the initially-browsed directory or file.
Never throws — failures arrive as `.error`. C: `SDL_ShowOpenFileDialog`. -/
def showOpenFileDialog (cb : DialogResult → IO Unit)
    (window : Option Window := none) (filters : Array DialogFileFilter := #[])
    (defaultLocation : Option String := none) (allowMany : Bool := false) :
    IO Unit :=
  showOpenFileDialogRaw cb window (filters.map (·.name)) (filters.map (·.pattern))
    defaultLocation allowMany

@[extern "lean_sdl_show_save_file_dialog"]
private opaque showSaveFileDialogRaw (cb : DialogResult → IO Unit)
    (window : @& Option Window) (filterNames filterPatterns : @& Array String)
    (defaultLocation : @& Option String) : IO Unit

/-- Show a "save file" dialog (same contract as `showOpenFileDialog`; a
`.selected` result has exactly one path). C: `SDL_ShowSaveFileDialog`. -/
def showSaveFileDialog (cb : DialogResult → IO Unit)
    (window : Option Window := none) (filters : Array DialogFileFilter := #[])
    (defaultLocation : Option String := none) : IO Unit :=
  showSaveFileDialogRaw cb window (filters.map (·.name)) (filters.map (·.pattern))
    defaultLocation

@[extern "lean_sdl_show_open_folder_dialog"]
private opaque showOpenFolderDialogRaw (cb : DialogResult → IO Unit)
    (window : @& Option Window) (defaultLocation : @& Option String)
    (allowMany : Bool) : IO Unit

/-- Show an "open folder" dialog (same contract as `showOpenFileDialog`; no
filters, and `filterIndex` is always `none`). C: `SDL_ShowOpenFolderDialog`. -/
def showOpenFolderDialog (cb : DialogResult → IO Unit)
    (window : Option Window := none) (defaultLocation : Option String := none)
    (allowMany : Bool := false) : IO Unit :=
  showOpenFolderDialogRaw cb window defaultLocation allowMany

/-- Kind of dialog shown by `showFileDialogWithProperties`.
C: `SDL_FileDialogType`. -/
sdl_enum FileDialogType : UInt32 where
  | openFile   => 0  -- C: SDL_FILEDIALOG_OPENFILE
  | saveFile   => 1  -- C: SDL_FILEDIALOG_SAVEFILE
  | openFolder => 2  -- C: SDL_FILEDIALOG_OPENFOLDER

@[extern "lean_sdl_show_file_dialog_with_properties"]
private opaque showFileDialogWithPropertiesRaw (type : UInt32)
    (cb : DialogResult → IO Unit) (props : @& Properties) : IO Unit

/-- Show a dialog configured through properties (`SDL.filedialog.title`,
`.location`, `.many`, `.accept`, `.cancel`, … — see `SDL_dialog.h`). Filters
cannot be attached this way from Lean (raw-pointer property); use the direct
functions instead. C: `SDL_ShowFileDialogWithProperties`. -/
def showFileDialogWithProperties (type : FileDialogType)
    (cb : DialogResult → IO Unit) (props : @& Properties) : IO Unit :=
  showFileDialogWithPropertiesRaw type.val cb props

end Sdl
