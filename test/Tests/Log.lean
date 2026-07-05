import Sdl
import Tests.Harness

namespace Tests.Log
open Sdl Tests.Harness

/-- Priority round-trips per category, emitting one message at each level, and
`setLogPriorityPrefix` some/none. Messages are printed to stderr by SDL. -/
def run : IO Unit := do
  -- set/get/reset priority round-trip per several categories
  Sdl.setLogPriority .application .warn
  check "app priority round-trip" ((← Sdl.getLogPriority .application) == .warn)
  Sdl.setLogPriority .video .error
  check "video priority round-trip" ((← Sdl.getLogPriority .video) == .error)
  Sdl.setLogPriority .audio .debug
  check "audio priority round-trip" ((← Sdl.getLogPriority .audio) == .debug)
  Sdl.setLogPriority .render .verbose
  check "render priority round-trip" ((← Sdl.getLogPriority .render) == .verbose)
  Sdl.resetLogPriorities
  -- default is sane (not invalid) after reset
  check "default priority sane" ((← Sdl.getLogPriority .application) != .invalid)
  -- emit one message at each level (no crash)
  Sdl.setLogPriorities .trace
  Sdl.logTrace    (msg := "trace message")
  Sdl.logVerbose  (msg := "verbose message")
  Sdl.logDebug    (msg := "debug message")
  Sdl.logInfo     (msg := "info message")
  Sdl.logWarn     (msg := "warn message")
  Sdl.logError    (msg := "error message")
  Sdl.logCritical (msg := "critical message")
  Sdl.log "plain SDL_Log message"
  Sdl.logMessage .video .info "logMessage with explicit category"
  check "emit all levels (no crash)" true
  -- setLogPriorityPrefix some/none
  Sdl.setLogPriorityPrefix .info (some "[lean-info] ")
  Sdl.logInfo (msg := "prefixed info message")
  Sdl.setLogPriorityPrefix .info none
  Sdl.logInfo (msg := "unprefixed info message")
  check "setLogPriorityPrefix some/none" true
  Sdl.resetLogPriorities

end Tests.Log
