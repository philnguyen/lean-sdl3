import Sdl
import Tests.Harness

namespace Tests.IOStream
open Sdl Tests.Harness

/-- Dynamic/const/file streams: write/seek/read/size, endian round-trips, EOF
and read-only behavior, use-after-close, and the `loadFile`/`saveFile` helpers
(file variants sandboxed under the pref directory). -/
def run : IO Unit := do
  -- dynamic memory: write, tell, seek, read back, size
  let s ← Sdl.ioFromDynamicMem
  s.write (ByteArray.mk #[1, 2, 3, 4])
  check "dynamic tell == 4" ((← s.tell) == 4)
  let _ ← s.seek 0 .seekSet
  check "dynamic read 4 back" ((← s.read 4) == ByteArray.mk #[1, 2, 3, 4])
  check "dynamic size == 4" ((← s.size) == 4)
  s.close

  -- endian: little- vs big-endian reads of the same two bytes
  let sLE ← Sdl.ioFromConstMem (ByteArray.mk #[0x01, 0x02])
  check "readU16LE == 0x0201" ((← sLE.readU16LE) == 0x0201)
  sLE.close
  let sBE ← Sdl.ioFromConstMem (ByteArray.mk #[0x01, 0x02])
  check "readU16BE == 0x0102" ((← sBE.readU16BE) == 0x0102)
  sBE.close

  -- endian: dynamic-mem write/read round-trips (seek 0 in between)
  let sU32 ← Sdl.ioFromDynamicMem
  sU32.writeU32LE 0xDEADBEEF
  let _ ← sU32.seek 0 .seekSet
  check "writeU32LE/readU32LE round-trip" ((← sU32.readU32LE) == 0xDEADBEEF)
  sU32.close
  let sS64 ← Sdl.ioFromDynamicMem
  sS64.writeS64BE (-1234567890123)
  let _ ← sS64.seek 0 .seekSet
  check "writeS64BE/readS64BE round-trip (negative)" ((← sS64.readS64BE) == -1234567890123)
  sS64.close

  -- const-mem: reading past the end gives empty + status .eof
  let sEof ← Sdl.ioFromConstMem (ByteArray.mk #[0xAA])
  let _ ← sEof.read 1
  check "read past end is empty" ((← sEof.read 4).size == 0)
  check "status is .eof at end" ((← sEof.status) == .eof)
  sEof.close

  -- const-mem is read-only: writing reports a short write, which we throw on
  let sRO ← Sdl.ioFromConstMem (ByteArray.mk #[0x00, 0x00])
  checkThrows "write to const-mem throws" (sRO.write (ByteArray.mk #[1]))
  sRO.close

  -- use-after-close is an IO error (not UB)
  let sClosed ← Sdl.ioFromDynamicMem
  sClosed.close
  checkThrows "tell after close throws" sClosed.tell
  checkThrows "double close throws" sClosed.close

  -- top-level loadFile/saveFile round-trip, sandboxed under the pref dir
  let pref ← Sdl.getPrefPath "lean-sdl3" "test-iostream"
  let path := pref ++ "io-probe.bin"
  let payload := ByteArray.mk #[10, 20, 30, 40, 50]
  Sdl.saveFile path payload
  check "loadFile/saveFile round-trip" ((← Sdl.loadFile path) == payload)
  Sdl.removePath path

  -- IOStream.loadFile drains a const-mem stream to the original bytes
  let orig := ByteArray.mk #[5, 6, 7, 8, 9]
  let sAll ← Sdl.ioFromConstMem orig
  check "IOStream.loadFile == original" ((← sAll.loadFile) == orig)
  sAll.close

end Tests.IOStream
