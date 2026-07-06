import Sdl.Core.Macros
import Sdl.Error
import Sdl.Time

/-!
# Filesystem paths and directory operations (`SDL_filesystem.h`)

Path queries (base/pref/user/current directories), directory-tree
manipulation (create/remove/rename/copy), path info, and pattern globbing.

`globDirectory` gives a materialized (recursive) listing; `enumerateDirectory`
streams one directory's entries through a callback with early-stop.
-/

namespace Sdl

/-- Directory where the application was run from (SDL-owned, cached). Guaranteed
to end with a path separator. C: `SDL_GetBasePath`. -/
@[extern "lean_sdl_get_base_path"]
opaque getBasePath : IO String

@[extern "lean_sdl_get_pref_path"]
private opaque getPrefPathRaw (org app : @& String) : IO String

/-- User-and-app-specific writable directory (created if needed). Guaranteed to
end with a path separator. C: `SDL_GetPrefPath`. -/
def getPrefPath (org app : String) : IO String := getPrefPathRaw org app

/-- An OS-provided user folder for a specific purpose. C: `SDL_Folder`
(the `SDL_FOLDER_COUNT` sentinel is intentionally omitted). -/
sdl_enum Folder : UInt32 where
  | home        => 0   -- C: SDL_FOLDER_HOME
  | desktop     => 1   -- C: SDL_FOLDER_DESKTOP
  | documents   => 2   -- C: SDL_FOLDER_DOCUMENTS
  | downloads   => 3   -- C: SDL_FOLDER_DOWNLOADS
  | music       => 4   -- C: SDL_FOLDER_MUSIC
  | pictures    => 5   -- C: SDL_FOLDER_PICTURES
  | publicshare => 6   -- C: SDL_FOLDER_PUBLICSHARE
  | savedgames  => 7   -- C: SDL_FOLDER_SAVEDGAMES
  | screenshots => 8   -- C: SDL_FOLDER_SCREENSHOTS
  | templates   => 9   -- C: SDL_FOLDER_TEMPLATES
  | videos      => 10  -- C: SDL_FOLDER_VIDEOS

@[extern "lean_sdl_get_user_folder"]
private opaque getUserFolderRaw (folder : UInt32) : IO String

/-- Path of the OS folder for `folder`, ending with a path separator. Throws if
the platform doesn't provide it. C: `SDL_GetUserFolder`. -/
def getUserFolder (folder : Folder) : IO String := getUserFolderRaw folder.val

/-- Create a directory and any missing parents (succeeds if it already exists).
C: `SDL_CreateDirectory`. -/
@[extern "lean_sdl_create_directory"]
opaque createDirectory (path : @& String) : IO Unit

/-- Remove a file or an empty directory. C: `SDL_RemovePath`. -/
@[extern "lean_sdl_remove_path"]
opaque removePath (path : @& String) : IO Unit

/-- Rename a file or directory (replacing `newpath` if it exists).
C: `SDL_RenamePath`. -/
@[extern "lean_sdl_rename_path"]
opaque renamePath (oldpath newpath : @& String) : IO Unit

/-- Copy a file, overwriting `newpath` if it exists. C: `SDL_CopyFile`. -/
@[extern "lean_sdl_copy_file"]
opaque copyFile (oldpath newpath : @& String) : IO Unit

/-- Type of a filesystem entry. C: `SDL_PathType`. -/
sdl_enum PathType : UInt32 where
  | none      => 0  -- C: SDL_PATHTYPE_NONE (path does not exist)
  | file      => 1  -- C: SDL_PATHTYPE_FILE
  | directory => 2  -- C: SDL_PATHTYPE_DIRECTORY
  | other     => 3  -- C: SDL_PATHTYPE_OTHER (device node, etc.)

/-- Information about a filesystem path. C: `SDL_PathInfo`. -/
structure PathInfo where
  /-- The path type. -/
  type : PathType
  /-- File size in bytes. -/
  size : UInt64
  /-- When the path was created. -/
  createTime : Time
  /-- When the path was last modified. -/
  modifyTime : Time
  /-- When the path was last read. -/
  accessTime : Time
deriving Repr, Inhabited

/-- Maker called from C to hand a `PathInfo` back to Lean.
C: builds the result of `SDL_GetPathInfo`. -/
@[export lean_sdl_mk_path_info]
private def mkPathInfo (type : UInt32) (size : UInt64) (createNs modifyNs accessNs : Int64) :
    PathInfo :=
  { type := PathType.ofVal? type |>.getD .none
    size
    createTime := ⟨createNs⟩
    modifyTime := ⟨modifyNs⟩
    accessTime := ⟨accessNs⟩ }

/-- Information about `path` (symlinks are followed). Throws if the path does
not exist. C: `SDL_GetPathInfo`. -/
@[extern "lean_sdl_get_path_info"]
opaque getPathInfo (path : @& String) : IO PathInfo

/-- Flags for `globDirectory`. C: `SDL_GlobFlags`. -/
sdl_flags GlobFlags : UInt32 where
  /-- Case-insensitive pattern matching. C: `SDL_GLOB_CASEINSENSITIVE`. -/
  | caseInsensitive := 0x1

@[extern "lean_sdl_glob_directory"]
private opaque globDirectoryRaw (path : @& String) (pattern : Option String) (flags : UInt32) :
    IO (Array String)

/-- Enumerate a directory tree filtered by `pattern` (wildcards `*` and `?`;
`none` matches everything). Subdirectories use `/` separators. Throws on
failure. C: `SDL_GlobDirectory`. -/
def globDirectory (path : String) (pattern : Option String := none)
    (flags : GlobFlags := .none) : IO (Array String) :=
  globDirectoryRaw path pattern flags.val

/-- The system's current working directory, ending with a path separator.
C: `SDL_GetCurrentDirectory`. -/
@[extern "lean_sdl_get_current_directory"]
opaque getCurrentDirectory : IO String

/-- What a directory-enumeration callback asks the walk to do next.
C: `SDL_EnumerationResult`. -/
sdl_enum EnumerationResult : UInt32 where
  | «continue» => 0  -- C: SDL_ENUM_CONTINUE
  | success    => 1  -- C: SDL_ENUM_SUCCESS (stop, successfully)
  | failure    => 2  -- C: SDL_ENUM_FAILURE (stop, as a failure)

@[extern "lean_sdl_enumerate_directory"]
private opaque enumerateDirectoryRaw (path : @& String)
    (cb : String → String → IO UInt32) : IO Unit

/-- Call `cb dirname fname` for each entry of the single directory `path`
(not recursive), synchronously on this thread, in no guaranteed order. `cb`
returns `.continue` to keep walking, `.success` to stop early, or `.failure`
to abort — `.failure` (or a thrown exception) surfaces as an IO error.
C: `SDL_EnumerateDirectory`. -/
def enumerateDirectory (path : String)
    (cb : (dirname fname : String) → IO EnumerationResult) : IO Unit :=
  enumerateDirectoryRaw path fun d f => do return (← cb d f).val

end Sdl
