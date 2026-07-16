module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# GUIDs (`SDL_guid.h`)

A `Guid` is a 128-bit identifier (16 bytes) used by SDL to identify input
devices across runs. SDL exposes only two operations, and both are **pure**
functions of their input (no SDL state, no errors), so they are bound as pure
externs (no world argument; the shim returns the value directly).
-/

namespace Sdl

/-- A 128-bit globally-unique identifier. C: `SDL_GUID` (a `Uint8 data[16]`).

Invariant: `bytes` always holds exactly 16 bytes. Every constructor in this
module (`Sdl.stringToGuid`, the `Inhabited` default) preserves it, and the C
side zero-pads/truncates any foreign input to 16 bytes. -/
structure Guid where
  /-- The 16 raw bytes of the GUID. -/
  bytes : ByteArray
deriving BEq

/-- The all-zero GUID (16 zero bytes). -/
instance : Inhabited Guid := ⟨⟨ByteArray.mk (Array.replicate 16 0)⟩⟩

@[extern "lean_sdl_guid_to_string"]
private opaque guidToStringRaw (bytes : @& ByteArray) : String

/-- ASCII (lowercase hex) string representation, 32 characters. Pure.
C: `SDL_GUIDToString`. -/
def Guid.toString (g : Guid) : String := guidToStringRaw g.bytes

instance : ToString Guid := ⟨Guid.toString⟩

@[extern "lean_sdl_string_to_guid"]
private opaque stringToGuidRaw (s : @& String) : ByteArray

/-- Parse a GUID from its ASCII representation. Performs no error checking:
invalid input silently yields a (useless, typically zero) GUID rather than
throwing. Pure. C: `SDL_StringToGUID`. -/
def stringToGuid (s : String) : Guid := ⟨stringToGuidRaw s⟩

end Sdl

end
