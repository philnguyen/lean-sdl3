import Sdl

/-- Print linked-SDL info; doubles as the build's smoke test. -/
def main : IO Unit := do
  let v ← Sdl.getVersion
  IO.println s!"SDL {v} (revision {← Sdl.getRevision})"
  IO.println s!"platform: {← Sdl.getPlatform}"
  Sdl.init .events
  let active ← Sdl.wasInit
  IO.println s!"events subsystem active: {active.has .events}"
  Sdl.quit
