import Sdl.Core.Macros
import Sdl.Error
import Sdl.Properties

/-!
# I/O streams (`SDL_iostream.h`)

An `IOStream` handle wraps an `SDL_IOStream *`. One owned C external class backs
it (`lean_sdl_iostream`): the finalizer runs `SDL_CloseIO` (ignoring the result).
`IOStream.close` is a *manual* close — files need a prompt flush — and NULLs the
handle EVEN on failure, because SDL frees the stream regardless (see the
`SDL_CloseIO` docs). `getProperties` hands out a *borrowed* `Properties` tied to
the stream; using it after `close` fails cleanly in SDL (a stale
`SDL_PropertiesID` lookup, no raw-pointer deref).

`ioFromConstMem` keeps a reference to the source `ByteArray` (read-only aliasing
is sound under Lean copy-on-write) so the buffer outlives the stream.

Skipped (documented plan-level omissions):
* `SDL_OpenIO` / `SDL_IOStreamInterface` — custom stream implementations need a
  callback bridge; deferred.
* `SDL_IOFromMem` — writable aliasing into a Lean `ByteArray` is unsound; use
  `ioFromDynamicMem` for a writable stream instead.
* `SDL_IOprintf` / `SDL_IOvprintf` — varargs; write `s.toUTF8` with `write`.
* `SDL_PROP_IOSTREAM_DYNAMIC_MEMORY_POINTER` ownership-transfer property —
  retrieve dynamic-memory contents with `seek 0 .seekSet` + `read`/`loadFile`.
-/

namespace Sdl

/-- Stream status, set by a read or write operation. C: `SDL_IOStatus`. -/
sdl_enum IOStatus : UInt32 where
  | ready     => 0  -- C: SDL_IO_STATUS_READY
  | error     => 1  -- C: SDL_IO_STATUS_ERROR
  | eof       => 2  -- C: SDL_IO_STATUS_EOF
  | notReady  => 3  -- C: SDL_IO_STATUS_NOT_READY
  | readonly  => 4  -- C: SDL_IO_STATUS_READONLY
  | writeonly => 5  -- C: SDL_IO_STATUS_WRITEONLY

/-- `whence` reference point for seeking (like stdio's `fseek`).
C: `SDL_IOWhence`. -/
sdl_enum IOWhence : UInt32 where
  | seekSet => 0  -- C: SDL_IO_SEEK_SET (from the beginning)
  | seekCur => 1  -- C: SDL_IO_SEEK_CUR (relative to the current point)
  | seekEnd => 2  -- C: SDL_IO_SEEK_END (relative to the end)

/-- A read/write data stream. C: `SDL_IOStream`. -/
sdl_opaque IOStream

@[extern "lean_sdl_iostream_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Create a stream reading from and/or writing to a named file, with an
`fopen`-style `mode` (e.g. `"rb"`, `"w+b"`). C: `SDL_IOFromFile`. -/
@[extern "lean_sdl_io_from_file"]
opaque ioFromFile (file mode : @& String) : IO IOStream

/-- Create a read-only stream over a byte buffer. The stream keeps a reference
to `data` for its lifetime (read-only aliasing is sound under copy-on-write);
writing to it is an error. C: `SDL_IOFromConstMem`. -/
@[extern "lean_sdl_io_from_const_mem"]
opaque ioFromConstMem (data : ByteArray) : IO IOStream

/-- Create a stream backed by dynamically allocated memory (grows on write).
Retrieve the contents with `seek 0 .seekSet` then `read`/`loadFile`.
C: `SDL_IOFromDynamicMem`. -/
@[extern "lean_sdl_io_from_dynamic_mem"]
opaque ioFromDynamicMem : IO IOStream

namespace IOStream

/-- Close and free the stream, flushing buffered writes. Throws on a flush
failure, but the handle is invalid afterwards either way (SDL frees the stream
regardless), so later use is an IO error. Throws immediately (without closing)
on a *borrowed* stream — e.g. a process's stdin/stdout from
`Process.getInput`/`getOutput`, whose lifetime SDL owns. C: `SDL_CloseIO`. -/
@[extern "lean_sdl_close_io"]
opaque close (self : @& IOStream) : IO Unit

/-- The properties associated with the stream. Borrowed: tied to the stream's
lifetime, never destroyed from Lean. C: `SDL_GetIOProperties`. -/
@[extern "lean_sdl_get_io_properties"]
opaque getProperties (self : @& IOStream) : IO Properties

@[extern "lean_sdl_get_io_status"]
private opaque getIOStatusRaw (self : @& IOStream) : IO UInt32

/-- The current stream status (useful to tell a short read/write apart from an
error or EOF). C: `SDL_GetIOStatus`. -/
def status (self : @& IOStream) : IO IOStatus := do
  return IOStatus.ofVal? (← getIOStatusRaw self) |>.getD .error

/-- The size of the data stream in bytes. Throws if it can't be determined.
C: `SDL_GetIOSize`. -/
@[extern "lean_sdl_get_io_size"]
opaque size (self : @& IOStream) : IO Int64

@[extern "lean_sdl_seek_io"]
private opaque seekRaw (self : @& IOStream) (offset : Int64) (whence : UInt32) : IO Int64

/-- Seek to `offset` (in bytes, may be negative) relative to `whence`, returning
the new absolute offset. Throws if the stream can't seek.  C: `SDL_SeekIO`. -/
def seek (self : @& IOStream) (offset : Int64) (whence : IOWhence) : IO Int64 :=
  seekRaw self offset whence.val

/-- The current read/write offset. Throws if it can't be determined.
C: `SDL_TellIO`. -/
@[extern "lean_sdl_tell_io"]
opaque tell (self : @& IOStream) : IO Int64

/-- Read up to `maxBytes` bytes. Returns fewer (possibly empty) at end of file;
throws only on a genuine I/O error. C: `SDL_ReadIO`. -/
@[extern "lean_sdl_read_io"]
opaque read (self : @& IOStream) (maxBytes : USize) : IO ByteArray

/-- Write all of `data`. Throws if fewer than `data.size` bytes were written
(e.g. a read-only stream). C: `SDL_WriteIO`. -/
@[extern "lean_sdl_write_io"]
opaque write (self : @& IOStream) (data : @& ByteArray) : IO Unit

/-- Flush any buffered writes to the underlying stream. C: `SDL_FlushIO`. -/
@[extern "lean_sdl_flush_io"]
opaque flush (self : @& IOStream) : IO Unit

/-- Read all remaining data from the stream (does not close it).
C: `SDL_LoadFile_IO` (with `closeio = false`). -/
@[extern "lean_sdl_load_file_io"]
opaque loadFile (self : @& IOStream) : IO ByteArray

/-- Write `data` as the entire stream contents (does not close it).
C: `SDL_SaveFile_IO` (with `closeio = false`). -/
@[extern "lean_sdl_save_file_io"]
opaque saveFile (self : @& IOStream) (data : @& ByteArray) : IO Unit

/-! ### Endian read/write helpers
Each read throws on failure *or* end of file. Each write throws on failure. -/

/-- Read a byte. C: `SDL_ReadU8`. -/
@[extern "lean_sdl_read_u8"]
opaque readU8 (self : @& IOStream) : IO UInt8
/-- Read a signed byte. C: `SDL_ReadS8`. -/
@[extern "lean_sdl_read_s8"]
opaque readS8 (self : @& IOStream) : IO Int8
/-- Read 16 bits little-endian into native format. C: `SDL_ReadU16LE`. -/
@[extern "lean_sdl_read_u16le"]
opaque readU16LE (self : @& IOStream) : IO UInt16
/-- Read signed 16 bits little-endian. C: `SDL_ReadS16LE`. -/
@[extern "lean_sdl_read_s16le"]
opaque readS16LE (self : @& IOStream) : IO Int16
/-- Read 16 bits big-endian into native format. C: `SDL_ReadU16BE`. -/
@[extern "lean_sdl_read_u16be"]
opaque readU16BE (self : @& IOStream) : IO UInt16
/-- Read signed 16 bits big-endian. C: `SDL_ReadS16BE`. -/
@[extern "lean_sdl_read_s16be"]
opaque readS16BE (self : @& IOStream) : IO Int16
/-- Read 32 bits little-endian into native format. C: `SDL_ReadU32LE`. -/
@[extern "lean_sdl_read_u32le"]
opaque readU32LE (self : @& IOStream) : IO UInt32
/-- Read signed 32 bits little-endian. C: `SDL_ReadS32LE`. -/
@[extern "lean_sdl_read_s32le"]
opaque readS32LE (self : @& IOStream) : IO Int32
/-- Read 32 bits big-endian into native format. C: `SDL_ReadU32BE`. -/
@[extern "lean_sdl_read_u32be"]
opaque readU32BE (self : @& IOStream) : IO UInt32
/-- Read signed 32 bits big-endian. C: `SDL_ReadS32BE`. -/
@[extern "lean_sdl_read_s32be"]
opaque readS32BE (self : @& IOStream) : IO Int32
/-- Read 64 bits little-endian into native format. C: `SDL_ReadU64LE`. -/
@[extern "lean_sdl_read_u64le"]
opaque readU64LE (self : @& IOStream) : IO UInt64
/-- Read signed 64 bits little-endian. C: `SDL_ReadS64LE`. -/
@[extern "lean_sdl_read_s64le"]
opaque readS64LE (self : @& IOStream) : IO Int64
/-- Read 64 bits big-endian into native format. C: `SDL_ReadU64BE`. -/
@[extern "lean_sdl_read_u64be"]
opaque readU64BE (self : @& IOStream) : IO UInt64
/-- Read signed 64 bits big-endian. C: `SDL_ReadS64BE`. -/
@[extern "lean_sdl_read_s64be"]
opaque readS64BE (self : @& IOStream) : IO Int64

/-- Write a byte. C: `SDL_WriteU8`. -/
@[extern "lean_sdl_write_u8"]
opaque writeU8 (self : @& IOStream) (v : UInt8) : IO Unit
/-- Write a signed byte. C: `SDL_WriteS8`. -/
@[extern "lean_sdl_write_s8"]
opaque writeS8 (self : @& IOStream) (v : Int8) : IO Unit
/-- Write 16 bits (native) as little-endian. C: `SDL_WriteU16LE`. -/
@[extern "lean_sdl_write_u16le"]
opaque writeU16LE (self : @& IOStream) (v : UInt16) : IO Unit
/-- Write signed 16 bits as little-endian. C: `SDL_WriteS16LE`. -/
@[extern "lean_sdl_write_s16le"]
opaque writeS16LE (self : @& IOStream) (v : Int16) : IO Unit
/-- Write 16 bits (native) as big-endian. C: `SDL_WriteU16BE`. -/
@[extern "lean_sdl_write_u16be"]
opaque writeU16BE (self : @& IOStream) (v : UInt16) : IO Unit
/-- Write signed 16 bits as big-endian. C: `SDL_WriteS16BE`. -/
@[extern "lean_sdl_write_s16be"]
opaque writeS16BE (self : @& IOStream) (v : Int16) : IO Unit
/-- Write 32 bits (native) as little-endian. C: `SDL_WriteU32LE`. -/
@[extern "lean_sdl_write_u32le"]
opaque writeU32LE (self : @& IOStream) (v : UInt32) : IO Unit
/-- Write signed 32 bits as little-endian. C: `SDL_WriteS32LE`. -/
@[extern "lean_sdl_write_s32le"]
opaque writeS32LE (self : @& IOStream) (v : Int32) : IO Unit
/-- Write 32 bits (native) as big-endian. C: `SDL_WriteU32BE`. -/
@[extern "lean_sdl_write_u32be"]
opaque writeU32BE (self : @& IOStream) (v : UInt32) : IO Unit
/-- Write signed 32 bits as big-endian. C: `SDL_WriteS32BE`. -/
@[extern "lean_sdl_write_s32be"]
opaque writeS32BE (self : @& IOStream) (v : Int32) : IO Unit
/-- Write 64 bits (native) as little-endian. C: `SDL_WriteU64LE`. -/
@[extern "lean_sdl_write_u64le"]
opaque writeU64LE (self : @& IOStream) (v : UInt64) : IO Unit
/-- Write signed 64 bits as little-endian. C: `SDL_WriteS64LE`. -/
@[extern "lean_sdl_write_s64le"]
opaque writeS64LE (self : @& IOStream) (v : Int64) : IO Unit
/-- Write 64 bits (native) as big-endian. C: `SDL_WriteU64BE`. -/
@[extern "lean_sdl_write_u64be"]
opaque writeU64BE (self : @& IOStream) (v : UInt64) : IO Unit
/-- Write signed 64 bits as big-endian. C: `SDL_WriteS64BE`. -/
@[extern "lean_sdl_write_s64be"]
opaque writeS64BE (self : @& IOStream) (v : Int64) : IO Unit

end IOStream

/-- Read all the data from a file path. C: `SDL_LoadFile`. -/
@[extern "lean_sdl_load_file"]
opaque loadFile (path : @& String) : IO ByteArray

/-- Write all of `data` to a file path (creating/truncating it).
C: `SDL_SaveFile`. -/
@[extern "lean_sdl_save_file"]
opaque saveFile (path : @& String) (data : @& ByteArray) : IO Unit

end Sdl
