module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Properties
public meta import Sdl.Properties
public import Sdl.IOStream
public meta import Sdl.IOStream

public section

/-!
# Process control (`SDL_process.h`)

Spawn and manage OS-level subprocesses: create a process, optionally pipe its
standard I/O, read its output, wait for or kill it.

## Ownership

`Process` is an **owned root, finalizer-only-plus-manual-destroy**: the finalizer
(and the manual `destroy`) run `SDL_DestroyProcess`. Destroying a handle does
**not** stop the child — it only releases the SDL object tracking it (and closes
any piped standard-I/O streams). Use `kill` to actually terminate the process.

`getInput`/`getOutput` hand out **borrowed** `IOStream`s (owner = the process):
they are never closed from Lean, and `IOStream.close` throws on them. Use
`closeInput` to close the process's standard input (which the child sees as EOF).

Note: the `*_POINTER` create-keys in `Props` require an `SDL_IOStream` /
`SDL_Environment` *pointer* value, which the Lean binding has no setter for, so
`createProcessWithProperties` is today useful mainly for the number/string/boolean
options (stdio direction, working directory, background, …).
-/

namespace Sdl

/-- Description of where a standard I/O stream should be directed when creating
a process. C: `SDL_ProcessIO`. -/
sdl_enum ProcessIO : UInt32 where
  | inherited => 0  -- C: SDL_PROCESS_STDIO_INHERITED
  | null      => 1  -- C: SDL_PROCESS_STDIO_NULL
  | app       => 2  -- C: SDL_PROCESS_STDIO_APP
  | redirect  => 3  -- C: SDL_PROCESS_STDIO_REDIRECT

/-- A running (or finished) OS process. C: `SDL_Process`.

Destroying the handle does not stop the child; it only releases the SDL object
tracking it (and closes any piped streams). Use `Process.kill` to terminate. -/
sdl_opaque Process

@[extern "lean_sdl_process_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Maker called from C to pair the captured stdout bytes with the process exit
code (`Int32` crosses the maker boundary unboxed). -/
@[export lean_sdl_mk_process_read]
private def mkProcessRead (data : ByteArray) (exitcode : Int32) : ByteArray × Int32 :=
  (data, exitcode)

/-! Property names for `createProcessWithProperties` and `Process.getProperties`
(exact `SDL_PROP_PROCESS_*` string values from `SDL_process.h`). -/
namespace Process.Props

/-- Create key: array of arg strings + NULL (required). Needs a pointer value,
so it is not settable from Lean — use `createProcess`. C:
`SDL_PROP_PROCESS_CREATE_ARGS_POINTER`. -/
def createArgsPointer : String := "SDL.process.create.args"
/-- Create key: an `SDL_Environment` pointer (not settable from Lean). C:
`SDL_PROP_PROCESS_CREATE_ENVIRONMENT_POINTER`. -/
def createEnvironmentPointer : String := "SDL.process.create.environment"
/-- Create key: working directory (UTF-8 string). C:
`SDL_PROP_PROCESS_CREATE_WORKING_DIRECTORY_STRING`. -/
def createWorkingDirectoryString : String := "SDL.process.create.working_directory"
/-- Create key: an `SDL_ProcessIO` number for stdin. C:
`SDL_PROP_PROCESS_CREATE_STDIN_NUMBER`. -/
def createStdinNumber : String := "SDL.process.create.stdin_option"
/-- Create key: an `SDL_IOStream` pointer for redirected stdin (not settable
from Lean). C: `SDL_PROP_PROCESS_CREATE_STDIN_POINTER`. -/
def createStdinPointer : String := "SDL.process.create.stdin_source"
/-- Create key: an `SDL_ProcessIO` number for stdout. C:
`SDL_PROP_PROCESS_CREATE_STDOUT_NUMBER`. -/
def createStdoutNumber : String := "SDL.process.create.stdout_option"
/-- Create key: an `SDL_IOStream` pointer for redirected stdout (not settable
from Lean). C: `SDL_PROP_PROCESS_CREATE_STDOUT_POINTER`. -/
def createStdoutPointer : String := "SDL.process.create.stdout_source"
/-- Create key: an `SDL_ProcessIO` number for stderr. C:
`SDL_PROP_PROCESS_CREATE_STDERR_NUMBER`. -/
def createStderrNumber : String := "SDL.process.create.stderr_option"
/-- Create key: an `SDL_IOStream` pointer for redirected stderr (not settable
from Lean). C: `SDL_PROP_PROCESS_CREATE_STDERR_POINTER`. -/
def createStderrPointer : String := "SDL.process.create.stderr_source"
/-- Create key: redirect stderr into stdout (boolean). C:
`SDL_PROP_PROCESS_CREATE_STDERR_TO_STDOUT_BOOLEAN`. -/
def createStderrToStdoutBoolean : String := "SDL.process.create.stderr_to_stdout"
/-- Create key: run in the background (boolean). C:
`SDL_PROP_PROCESS_CREATE_BACKGROUND_BOOLEAN`. -/
def createBackgroundBoolean : String := "SDL.process.create.background"
/-- Create key: Windows command line (string; ignored elsewhere). C:
`SDL_PROP_PROCESS_CREATE_CMDLINE_STRING`. -/
def createCmdlineString : String := "SDL.process.create.cmdline"

/-- Read key: the process ID (number). C: `SDL_PROP_PROCESS_PID_NUMBER`. -/
def pidNumber : String := "SDL.process.pid"
/-- Read key: the stdin `SDL_IOStream` pointer. C:
`SDL_PROP_PROCESS_STDIN_POINTER`. -/
def stdinPointer : String := "SDL.process.stdin"
/-- Read key: the stdout `SDL_IOStream` pointer. C:
`SDL_PROP_PROCESS_STDOUT_POINTER`. -/
def stdoutPointer : String := "SDL.process.stdout"
/-- Read key: the stderr `SDL_IOStream` pointer. C:
`SDL_PROP_PROCESS_STDERR_POINTER`. -/
def stderrPointer : String := "SDL.process.stderr"
/-- Read key: whether the process runs in the background (boolean). C:
`SDL_PROP_PROCESS_BACKGROUND_BOOLEAN`. -/
def backgroundBoolean : String := "SDL.process.background"

end Process.Props

@[extern "lean_sdl_create_process"]
private opaque createProcessRaw (args : @& Array String) (pipeStdio : Bool) : IO Process

/-- Create and start a new process. `args[0]` is the executable path;
`args[1...]` are its command-line arguments. With `pipeStdio := true`, pipes are
created to the child's standard input and from its standard output (read via
`read` / `getOutput`, write via `getInput`); otherwise the child has no input
and inherits this application's output. Throws if the process cannot be created
— on macOS a nonexistent binary fails here, at creation time.
C: `SDL_CreateProcess`. -/
def createProcess (args : Array String) (pipeStdio : Bool := false) : IO Process :=
  createProcessRaw args pipeStdio

/-- Create a process from a property group (see `Process.Props`), e.g. to set
the working directory or per-stream stdio direction. Throws on failure.
C: `SDL_CreateProcessWithProperties`. -/
@[extern "lean_sdl_create_process_with_properties"]
opaque createProcessWithProperties (props : @& Properties) : IO Process

namespace Process

/-- The properties associated with the process (read keys in `Process.Props`,
e.g. `pidNumber`). Borrowed: tied to the process's lifetime, never destroyed
from Lean. Throws on failure. C: `SDL_GetProcessProperties`. -/
@[extern "lean_sdl_get_process_properties"]
opaque getProperties (self : @& Process) : IO Properties

/-- Read **all** output from the process, blocking until it exits, and return
the captured stdout bytes together with the process exit code. The process must
have been created with piped stdio. Throws on failure. C: `SDL_ReadProcess`. -/
@[extern "lean_sdl_read_process"]
opaque read (self : @& Process) : IO (ByteArray × Int32)

/-- The `IOStream` for writing to the process's standard input. Borrowed (owner
= the process); do not `close` it — use `closeInput` instead. Throws if the
process was not created with piped/APP standard input (also after `closeInput`).
C: `SDL_GetProcessInput`. -/
@[extern "lean_sdl_get_process_input"]
opaque getInput (self : @& Process) : IO IOStream

/-- The non-blocking `IOStream` for reading the process's standard output.
Borrowed (owner = the process); never `close` it. A read may return 0 bytes with
status `.notReady` when no output is available yet. Throws if the process was
not created with piped/APP standard output. C: `SDL_GetProcessOutput`. -/
@[extern "lean_sdl_get_process_output"]
opaque getOutput (self : @& Process) : IO IOStream

/-- Close the process's standard input (the child sees EOF). Safe: it detaches
the stdin stream from the process before closing so a later `SDL_DestroyProcess`
does not double-close it. Any input-stream handle previously obtained from
`getInput` is **invalid** afterwards, and a further `getInput` throws. Throws if
the process had no piped standard input. C: `SDL_CloseIO` on the stdin stream. -/
@[extern "lean_sdl_close_process_input"]
opaque closeInput (self : @& Process) : IO Unit

/-- Stop the process: gracefully by default, or immediately with `force := true`
(which may leave half-written data). Throws on failure. C: `SDL_KillProcess`. -/
@[extern "lean_sdl_kill_process"]
opaque kill (self : @& Process) (force : Bool := false) : IO Unit

/-- Wait for the process and report its exit code, or `none` if it is still
running. With `block := true` (the default) this blocks until the process
finishes (so it always returns `some`); with `block := false` it polls once.
The exit code is the normal exit status, a negative signal number if it was
killed by a signal, or `-255` otherwise. Throws only on an internal error.
C: `SDL_WaitProcess`. -/
@[extern "lean_sdl_wait_process"]
opaque wait (self : @& Process) (block : Bool := true) : IO (Option Int32)

/-- Destroy the SDL object tracking the process (does **not** stop the child;
closes any piped streams). The handle must not be used afterwards.
C: `SDL_DestroyProcess`. -/
@[extern "lean_sdl_destroy_process"]
opaque destroy (self : @& Process) : IO Unit

end Process
end Sdl

end
