import Sdl
import Tests.Harness

namespace Tests.TouchPen
open Sdl Tests.Harness

/-- Touch and pen tests. The dummy driver reports no touch/pen hardware, so the
list query just must not throw and every per-device query on a bogus id must
throw (the error sentinels `SDL_TOUCH_DEVICE_INVALID` / `SDL_PEN_DEVICE_TYPE_INVALID`
are converted to IO errors before reaching Lean). -/
def run : IO Unit := do
  -- touch devices (any size, including empty)
  let _ ← getTouchDevices
  check "getTouchDevices no-throw" true

  -- per-device queries on a bogus touch id throw
  checkThrows "TouchId.name bogus throws" (TouchId.name ⟨999999⟩)
  checkThrows "TouchId.deviceType bogus throws" (TouchId.deviceType ⟨999999⟩)
  checkThrows "TouchId.fingers bogus throws" (TouchId.fingers ⟨999999⟩)

  -- pen device type on the invalid pen (0) throws
  checkThrows "PenId.deviceType 0 throws" (PenId.deviceType ⟨0⟩)

end Tests.TouchPen
