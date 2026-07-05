import Sdl
import Tests.Harness

namespace Tests.Guid
open Sdl Tests.Harness

/-- Pure string↔GUID round-trips (no SDL state), the zero GUID, and robustness
against garbage input. -/
def run : IO Unit := do
  -- known string round-trips through parse then format (SDL emits lowercase hex)
  let s := "030000005e0400008e02000014010000"
  check "string→guid→string round-trip" ((Sdl.stringToGuid s).toString == s)
  -- the zero GUID formats as 32 zeros
  check "zero guid = 32 zeros"
    ((default : Guid).toString == "00000000000000000000000000000000")
  -- output is always 32 characters
  check "toString length 32" ((Sdl.stringToGuid s).toString.length == 32)
  -- garbage input silently yields some GUID and does not crash
  check "garbage input no crash" ((Sdl.stringToGuid "not a valid guid!!").toString.length == 32)

end Tests.Guid
