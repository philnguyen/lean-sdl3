import Sdl.Core.Macros
import Sdl.Error

/-!
# Logging (`SDL_log.h`)

Priority-filtered logging by category. `LogCategory` is an open numeric domain
(apps may define their own categories at or above `.custom`); `LogPriority` is a
closed enum.

Skipped: `SDL_SetLogOutputFunction`, `SDL_GetLogOutputFunction`,
`SDL_GetDefaultLogOutputFunction` — need a callback bridge (M6 milestone).
`SDL_LogMessageV` — C `va_list` variant, not bindable.
-/

namespace Sdl

/-- A log category. Open domain: apps may use custom categories at or above
`.custom`. C: `SDL_LogCategory`. -/
sdl_id LogCategory : UInt32 where
  | application := 0   -- C: SDL_LOG_CATEGORY_APPLICATION
  | error       := 1   -- C: SDL_LOG_CATEGORY_ERROR
  | assert      := 2   -- C: SDL_LOG_CATEGORY_ASSERT
  | system      := 3   -- C: SDL_LOG_CATEGORY_SYSTEM
  | audio       := 4   -- C: SDL_LOG_CATEGORY_AUDIO
  | video       := 5   -- C: SDL_LOG_CATEGORY_VIDEO
  | render      := 6   -- C: SDL_LOG_CATEGORY_RENDER
  | input       := 7   -- C: SDL_LOG_CATEGORY_INPUT
  | test        := 8   -- C: SDL_LOG_CATEGORY_TEST
  | gpu         := 9   -- C: SDL_LOG_CATEGORY_GPU
  | custom      := 19  -- C: SDL_LOG_CATEGORY_CUSTOM

/-- A log priority. C: `SDL_LogPriority`. -/
sdl_enum LogPriority : UInt32 where
  | invalid  => 0  -- C: SDL_LOG_PRIORITY_INVALID
  | trace    => 1  -- C: SDL_LOG_PRIORITY_TRACE
  | verbose  => 2  -- C: SDL_LOG_PRIORITY_VERBOSE
  | debug    => 3  -- C: SDL_LOG_PRIORITY_DEBUG
  | info     => 4  -- C: SDL_LOG_PRIORITY_INFO
  | warn     => 5  -- C: SDL_LOG_PRIORITY_WARN
  | error    => 6  -- C: SDL_LOG_PRIORITY_ERROR
  | critical => 7  -- C: SDL_LOG_PRIORITY_CRITICAL

@[extern "lean_sdl_set_log_priorities"]
private opaque setLogPrioritiesRaw (priority : UInt32) : IO Unit

/-- Set the priority of all log categories. C: `SDL_SetLogPriorities`. -/
def setLogPriorities (priority : LogPriority) : IO Unit :=
  setLogPrioritiesRaw priority.val

@[extern "lean_sdl_set_log_priority"]
private opaque setLogPriorityRaw (category priority : UInt32) : IO Unit

/-- Set the priority of one log category. C: `SDL_SetLogPriority`. -/
def setLogPriority (category : LogCategory) (priority : LogPriority) : IO Unit :=
  setLogPriorityRaw category.val priority.val

@[extern "lean_sdl_get_log_priority"]
private opaque getLogPriorityRaw (category : UInt32) : IO UInt32

/-- Priority of one log category. C: `SDL_GetLogPriority`. -/
def getLogPriority (category : LogCategory) : IO LogPriority := do
  return LogPriority.ofVal? (← getLogPriorityRaw category.val) |>.getD .invalid

/-- Reset all category priorities to defaults. C: `SDL_ResetLogPriorities`. -/
@[extern "lean_sdl_reset_log_priorities"]
opaque resetLogPriorities : IO Unit

@[extern "lean_sdl_set_log_priority_prefix"]
private opaque setLogPriorityPrefixRaw (priority : UInt32) («prefix» : Option String) : IO Unit

/-- Set (or, with `none`, reset to the default) the text prepended to messages
of the given priority. C: `SDL_SetLogPriorityPrefix`. -/
def setLogPriorityPrefix (priority : LogPriority) («prefix» : Option String) : IO Unit :=
  setLogPriorityPrefixRaw priority.val «prefix»

/-- Log a message at `.info` priority in the application category.
C: `SDL_Log`. -/
@[extern "lean_sdl_log"]
opaque log (msg : @& String) : IO Unit

@[extern "lean_sdl_log_message"]
private opaque logMessageRaw (category priority : UInt32) (msg : @& String) : IO Unit

/-- Log a message with the given category and priority. C: `SDL_LogMessage`. -/
def logMessage (category : LogCategory) (priority : LogPriority) (msg : @& String) : IO Unit :=
  logMessageRaw category.val priority.val msg

/-- Log at `.trace` priority. C: `SDL_LogTrace`. -/
def logTrace (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .trace msg

/-- Log at `.verbose` priority. C: `SDL_LogVerbose`. -/
def logVerbose (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .verbose msg

/-- Log at `.debug` priority. C: `SDL_LogDebug`. -/
def logDebug (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .debug msg

/-- Log at `.info` priority. C: `SDL_LogInfo`. -/
def logInfo (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .info msg

/-- Log at `.warn` priority. C: `SDL_LogWarn`. -/
def logWarn (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .warn msg

/-- Log at `.error` priority. C: `SDL_LogError`. -/
def logError (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .error msg

/-- Log at `.critical` priority. C: `SDL_LogCritical`. -/
def logCritical (category : LogCategory := .application) (msg : String) : IO Unit :=
  logMessage category .critical msg

end Sdl
