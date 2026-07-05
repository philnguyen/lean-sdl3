import Sdl
import Tests.Harness

namespace Tests.Properties
open Sdl Tests.Harness

/-- Round-trips, defaults, types, copy, lock, global group, and use-after-destroy
for `Sdl.Properties`. -/
def run : IO Unit := do
  let p ← Sdl.createProperties
  -- set/get round-trips
  p.setStringProperty "s" "hello"
  check "string round-trip" ((← p.getStringProperty "s") == "hello")
  p.setNumberProperty "n" 42
  check "number round-trip" ((← p.getNumberProperty "n") == 42)
  p.setNumberProperty "neg" (-123456789012)
  check "negative number round-trip" ((← p.getNumberProperty "neg") == -123456789012)
  p.setFloatProperty "f" 1.5
  check "float round-trip" ((← p.getFloatProperty "f") == 1.5)
  p.setBooleanProperty "b" true
  check "boolean round-trip" ((← p.getBooleanProperty "b") == true)
  -- getters return defaults for missing keys
  check "string default" ((← p.getStringProperty "missing" "def") == "def")
  check "number default" ((← p.getNumberProperty "missing" 7) == 7)
  check "float default" ((← p.getFloatProperty "missing" 2.5) == 2.5)
  check "boolean default" ((← p.getBooleanProperty "missing" true) == true)
  -- hasProperty true/false
  check "hasProperty true" (← p.hasProperty "s")
  check "hasProperty false" (!(← p.hasProperty "nope"))
  -- getPropertyType per kind
  check "type string"  ((← p.getPropertyType "s") == .string)
  check "type number"  ((← p.getPropertyType "n") == .number)
  check "type float"   ((← p.getPropertyType "f") == .float)
  check "type boolean" ((← p.getPropertyType "b") == .boolean)
  check "type invalid" ((← p.getPropertyType "missing") == .invalid)
  -- clearProperty
  p.clearProperty "s"
  check "clearProperty" (!(← p.hasProperty "s"))
  -- copyProperties copies values
  let q ← Sdl.createProperties
  p.copyProperties q
  check "copy number"  ((← q.getNumberProperty "n") == 42)
  check "copy boolean" ((← q.getBooleanProperty "b") == true)
  -- lock/unlock pair doesn't deadlock
  p.lockProperties
  p.unlockProperties
  check "lock/unlock pair" true
  -- global properties usable
  let g ← Sdl.getGlobalProperties
  g.setStringProperty "lean.sdl3.test.key" "gv"
  check "global set/get" ((← g.getStringProperty "lean.sdl3.test.key") == "gv")
  -- use after destroy throws
  p.destroy
  checkThrows "use after destroy" (p.getNumberProperty "n")
  -- destroy on the borrowed global Properties throws
  checkThrows "destroy borrowed global" g.destroy
  q.destroy

end Tests.Properties
