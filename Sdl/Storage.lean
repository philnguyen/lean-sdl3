module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Filesystem
public meta import Sdl.Filesystem
public import Sdl.Properties
public meta import Sdl.Properties

public section

/-!
# Storage containers (`SDL_storage.h`)

A portable, restrictive filesystem abstraction. Open a container for title
(read-only game content), user (read/write save data), or a local directory,
then read/write/enumerate files within it using Unix-style (`/`) relative paths
(no `.`/`..` — path escapes are rejected). Reuses the filesystem module's
`PathInfo`, `GlobFlags`, `PathType`, and `EnumerationResult` types.

No `SDL_Init` is required — everything here works headless.

## Ownership

`Storage` is an **owned root**: both `close` and the finalizer call
`SDL_CloseStorage`. SDL frees the container even when `SDL_CloseStorage`
reports an error, so `close` always consumes the handle (later use throws)
and then throws if SDL reported an error (files may still be in flight); the
finalizer ignores the result.

Skipped: `SDL_OpenStorage` — it takes a custom `SDL_StorageInterface` (a struct
of C callbacks), the same kind of custom-implementation entry point deferred
for `SDL_OpenIO`. The built-in `openTitle`/`openUser`/`openFile` cover normal
use.
-/

namespace Sdl

/-- An abstract interface for filesystem access. C: `SDL_Storage`. -/
sdl_opaque Storage

@[extern "lean_sdl_storage_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

namespace Storage

@[extern "lean_sdl_open_title_storage"]
private opaque openTitleRaw (override : Option String) (props : Option Properties) :
    IO Storage

/-- Open a read-only container for the application's title (game content). With
`override := none` the backend uses `SDL_GetBasePath` as its root. `props` may
carry backend-specific options. Throws on failure. C: `SDL_OpenTitleStorage`. -/
def openTitle (override : Option String := none) (props : Option Properties := none) :
    IO Storage :=
  openTitleRaw override props

@[extern "lean_sdl_open_user_storage"]
private opaque openUserRaw (org app : @& String) (props : Option Properties) : IO Storage

/-- Open a read/write container for a user's save data under `org`/`app`. Open
it only while actively reading/writing so the backend can batch and flush.
`props` may carry backend-specific options. Throws on failure.
C: `SDL_OpenUserStorage`. -/
def openUser (org app : String) (props : Option Properties := none) : IO Storage :=
  openUserRaw org app props

/-- Open a container over a local directory (`path` is prefixed to every storage
path). For development and tools; portable apps should prefer `openTitle`/
`openUser`. Throws on failure. C: `SDL_OpenFileStorage`. -/
@[extern "lean_sdl_open_file_storage"]
opaque openFile (path : @& String) : IO Storage

/-- Close and free the container, flushing any batched writes. The handle is
always consumed (SDL frees the container even on error), so later use throws;
additionally throws if SDL reports an error (files may still be in flight).
C: `SDL_CloseStorage`. -/
@[extern "lean_sdl_close_storage"]
opaque close (self : @& Storage) : IO Unit

/-- Whether the container is ready for access. Poll this (e.g. once per frame,
not in a spin loop) after opening. No error state. C: `SDL_StorageReady`. -/
@[extern "lean_sdl_storage_ready"]
opaque ready (self : @& Storage) : IO Bool

/-- The size of the file at `path`, in bytes. Throws if it can't be queried (a
missing file, or a `..`/`.`-escaping path). C: `SDL_GetStorageFileSize`. -/
@[extern "lean_sdl_get_storage_file_size"]
opaque getFileSize (self : @& Storage) (path : @& String) : IO UInt64

/-- Read the entire file at `path`. The shim sizes the buffer from
`getFileSize`, then reads straight into it. Throws on failure.
C: `SDL_ReadStorageFile` (via `SDL_GetStorageFileSize`). -/
@[extern "lean_sdl_read_storage_file"]
opaque readFile (self : @& Storage) (path : @& String) : IO ByteArray

/-- Write `data` as the file at `path` (in a writable container). Throws on
failure. C: `SDL_WriteStorageFile`. -/
@[extern "lean_sdl_write_storage_file"]
opaque writeFile (self : @& Storage) (path : @& String) (data : @& ByteArray) : IO Unit

/-- Create a directory (in a writable container). C: `SDL_CreateStorageDirectory`. -/
@[extern "lean_sdl_create_storage_directory"]
opaque createDirectory (self : @& Storage) (path : @& String) : IO Unit

@[extern "lean_sdl_enumerate_storage_directory"]
private opaque enumerateDirectoryRaw (self : @& Storage) (path : @& String)
    (cb : String → String → IO UInt32) : IO Unit

/-- Call `cb dirname fname` for each entry of directory `path` (the root if
`path` is empty), synchronously on this thread, in no guaranteed order. `cb`
returns `.continue` to keep walking, `.success` to stop early, or `.failure` to
abort — `.failure` (or a thrown exception) surfaces as an IO error.
C: `SDL_EnumerateStorageDirectory`. -/
def enumerateDirectory (self : @& Storage) (path : @& String)
    (cb : (dirname fname : String) → IO EnumerationResult) : IO Unit :=
  enumerateDirectoryRaw self path fun d f => do return (← cb d f).val

/-- Remove a file or an empty directory (in a writable container).
C: `SDL_RemoveStoragePath`. -/
@[extern "lean_sdl_remove_storage_path"]
opaque removePath (self : @& Storage) (path : @& String) : IO Unit

/-- Rename a file or directory (in a writable container).
C: `SDL_RenameStoragePath`. -/
@[extern "lean_sdl_rename_storage_path"]
opaque renamePath (self : @& Storage) (oldpath newpath : @& String) : IO Unit

/-- Copy a file (in a writable container). C: `SDL_CopyStorageFile`. -/
@[extern "lean_sdl_copy_storage_file"]
opaque copyFile (self : @& Storage) (oldpath newpath : @& String) : IO Unit

/-- Information about `path` within the container. Throws if the file doesn't
exist (or another failure). C: `SDL_GetStoragePathInfo`. -/
@[extern "lean_sdl_get_storage_path_info"]
opaque getPathInfo (self : @& Storage) (path : @& String) : IO PathInfo

/-- The remaining space in the container, in bytes (file storage reports
`UInt64.max`). No error state. C: `SDL_GetStorageSpaceRemaining`. -/
@[extern "lean_sdl_get_storage_space_remaining"]
opaque spaceRemaining (self : @& Storage) : IO UInt64

@[extern "lean_sdl_glob_storage_directory"]
private opaque globDirectoryRaw (self : @& Storage) (path : Option String)
    (pattern : Option String) (flags : UInt32) : IO (Array String)

/-- Enumerate a directory tree (the root if `path` is `none`), filtered by
`pattern` (wildcards `*` and `?`; `none` matches everything). The listing is
recursive, with `/` separators. Throws on failure.
C: `SDL_GlobStorageDirectory`. -/
def globDirectory (self : @& Storage) (path : Option String := none)
    (pattern : Option String := none) (flags : GlobFlags := .none) : IO (Array String) :=
  globDirectoryRaw self path pattern flags.val

end Storage
end Sdl

end
