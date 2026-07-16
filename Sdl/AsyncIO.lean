module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Asynchronous I/O (`SDL_asyncio.h`)

Non-blocking file I/O: open a file (`AsyncIO.fromFile`), start read/write/close
tasks against an `AsyncIOQueue`, then collect completed tasks from the queue
with `getResult` (non-blocking) or `waitResult` (blocking). Task completion is
reported out of order via an `AsyncIOOutcome`, tagged with an app-chosen
`userdata` integer. `loadFileAsync` slurps a whole file in one task.

No `SDL_Init` is required — everything here works headless.

## Ownership

`AsyncIO` is a **consumable** handle (GPU-command-buffer archetype): `close`
NULLs the holder pointer on success, so any later use throws. The finalizer
does **not** close the handle (closing needs a queue and spawns an async task):
if you drop an unclosed `AsyncIO`, the OS file handle leaks — **always call
`close`**.

`AsyncIOQueue` is an **owned root** (leaf type): both `destroy` and the
finalizer call `SDL_DestroyAsyncIOQueue`. Destroying a queue with pending tasks
loses their results and (for read/write tasks started from Lean) leaks the
shim's staging buffers, so drain the queue first; never destroy a queue while
another thread is blocked in `waitResult` on it (signal and join it first).

## Buffer lifetime

SDL requires read/write buffers to stay valid until the task completes, but
Lean `ByteArray`s can be moved/collected. The C shim therefore owns a staging
buffer for every read and write, copies a completed read's bytes into a fresh
`ByteArray` when the outcome is retrieved, and frees the staging buffer then.
-/

namespace Sdl

/-- Types of asynchronous I/O tasks. C: `SDL_AsyncIOTaskType`. -/
sdl_enum AsyncIOTaskType : UInt32 where
  | read  => 0  -- C: SDL_ASYNCIO_TASK_READ
  | write => 1  -- C: SDL_ASYNCIO_TASK_WRITE
  | close => 2  -- C: SDL_ASYNCIO_TASK_CLOSE

/-- Possible outcomes of an asynchronous I/O task. C: `SDL_AsyncIOResult`. -/
sdl_enum AsyncIOResult : UInt32 where
  | complete => 0  -- C: SDL_ASYNCIO_COMPLETE
  | failure  => 1  -- C: SDL_ASYNCIO_FAILURE
  | canceled => 2  -- C: SDL_ASYNCIO_CANCELED

/-- The asynchronous I/O operation structure. C: `SDL_AsyncIO`. -/
sdl_opaque AsyncIO

/-- A queue of completed asynchronous I/O tasks. C: `SDL_AsyncIOQueue`. -/
sdl_opaque AsyncIOQueue

@[extern "lean_sdl_asyncio_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Information about a completed asynchronous I/O request.
C: `SDL_AsyncIOOutcome` (the `asyncio` pointer is deliberately not exposed — it
may already be invalid; identify tasks by their `userdata` tag instead). -/
structure AsyncIOOutcome where
  /-- What sort of task this was (read, write, or close). -/
  taskType         : AsyncIOTaskType
  /-- The result of the work (success, failure, or cancellation). -/
  result           : AsyncIOResult
  /-- For completed `read` tasks (incl. `loadFileAsync`): the bytes read.
      `none` for write/close tasks and for failed/canceled tasks. -/
  buffer           : Option ByteArray
  /-- Offset in the `AsyncIO` where data was read/written. -/
  offset           : UInt64
  /-- Number of bytes the task was to read/write. -/
  bytesRequested   : UInt64
  /-- Actual number of bytes that were read/written. -/
  bytesTransferred : UInt64
  /-- The `userdata` tag passed when the task was started. -/
  userdata         : UInt64
deriving Inhabited

/-- Maker called from C to hand an `AsyncIOOutcome` back to Lean. The two enum
values are pinned by `consts_check.c`; `.read`/`.failure` are safe fallbacks. C
builds the `Option ByteArray` itself. -/
@[export lean_sdl_mk_asyncio_outcome]
private def mkAsyncIOOutcome (taskType result : UInt32) (buffer : Option ByteArray)
    (offset bytesRequested bytesTransferred userdata : UInt64) : AsyncIOOutcome :=
  { taskType := AsyncIOTaskType.ofVal? taskType |>.getD .read
    result := AsyncIOResult.ofVal? result |>.getD .failure
    buffer, offset, bytesRequested, bytesTransferred, userdata }

namespace AsyncIO

/-- Create a new `AsyncIO` for reading from and/or writing to a named file. The
`mode` is one of `"r"`/`"w"`/`"r+"`/`"w+"` (there is no `"b"` or `"a"` mode).
Opening is synchronous; later reads and writes are async. Throws on failure
(e.g. a missing file with mode `"r"`). C: `SDL_AsyncIOFromFile`. -/
@[extern "lean_sdl_asyncio_from_file"]
opaque fromFile (file mode : @& String) : IO AsyncIO

/-- The size of the data stream, in bytes. Not asynchronous. Throws on failure
(a negative return). C: `SDL_GetAsyncIOSize`. -/
@[extern "lean_sdl_get_asyncio_size"]
opaque getSize (self : @& AsyncIO) : IO Int64

/-- Start an async read of up to `size` bytes from `offset`, placing the task in
`queue`. Returns immediately; the read may transfer fewer bytes than requested
(reading past EOF is not an error). Retrieve the bytes from the completed
outcome's `buffer`. `userdata` tags the resulting outcome. Throws only if the
task could not be *started*. C: `SDL_ReadAsyncIO`. -/
@[extern "lean_sdl_read_asyncio"]
opaque read (self : @& AsyncIO) (offset size : UInt64) (queue : @& AsyncIOQueue)
    (userdata : UInt64 := 0) : IO Unit

/-- Start an async write of `data` at `offset`, placing the task in `queue`. The
shim copies `data` into a staging buffer that it owns until the task completes.
Returns immediately; `userdata` tags the resulting outcome. Throws only if the
task could not be *started*. C: `SDL_WriteAsyncIO`. -/
@[extern "lean_sdl_write_asyncio"]
opaque write (self : @& AsyncIO) (data : @& ByteArray) (offset : UInt64)
    (queue : @& AsyncIOQueue) (userdata : UInt64 := 0) : IO Unit

/-- Close the `AsyncIO`, placing the (asynchronous!) close task in `queue`. With
`flush := true` the data is synced to physical media before the task completes
(slower, but crash-safe — use it for game saves). On success the handle is
consumed and any later use throws; on failure (the close never started) the
handle stays valid. `userdata` tags the resulting outcome.
C: `SDL_CloseAsyncIO`. -/
@[extern "lean_sdl_close_asyncio"]
opaque close (self : @& AsyncIO) (flush : Bool) (queue : @& AsyncIOQueue)
    (userdata : UInt64 := 0) : IO Unit

end AsyncIO

namespace AsyncIOQueue

/-- Create a task queue for tracking multiple I/O operations. Throws on failure.
C: `SDL_CreateAsyncIOQueue`. -/
@[extern "lean_sdl_create_asyncio_queue"]
opaque create : IO AsyncIOQueue

/-- Destroy the queue. If tasks are still pending this blocks until they finish;
their results are lost and `loadFileAsync` buffers still in the queue are freed
by SDL. Consumes the handle (later use throws). Never call while another thread
is blocked in `waitResult` on this queue. C: `SDL_DestroyAsyncIOQueue`. -/
@[extern "lean_sdl_destroy_asyncio_queue"]
opaque destroy (self : @& AsyncIOQueue) : IO Unit

/-- Non-blocking poll for a completed task. `none` means no task in the queue
has finished yet (this is *not* an error). C: `SDL_GetAsyncIOResult`. -/
@[extern "lean_sdl_get_asyncio_result"]
opaque getResult (self : @& AsyncIOQueue) : IO (Option AsyncIOOutcome)

/-- Block until a task completes, waiting at most `timeoutMs` milliseconds
(`-1` waits forever). `none` on timeout, spurious wakeup, or a `signal`. Do not
call with `-1` on the main thread unless another thread will `signal` the queue,
or it will block forever. C: `SDL_WaitAsyncIOResult`. -/
@[extern "lean_sdl_wait_asyncio_result"]
opaque waitResult (self : @& AsyncIOQueue) (timeoutMs : Int32) :
    IO (Option AsyncIOOutcome)

/-- Wake up any threads blocked in `waitResult` on this queue, causing them to
return `none`. Useful when shutting down. C: `SDL_SignalAsyncIOQueue`. -/
@[extern "lean_sdl_signal_asyncio_queue"]
opaque signal (self : @& AsyncIOQueue) : IO Unit

end AsyncIOQueue

/-- Load all the data from a file path, asynchronously, placing the task in
`queue`. SDL allocates a NUL-terminated buffer (the NUL is excluded from the
outcome's `bytesTransferred`); the completed outcome is a `read` whose `buffer`
holds the file contents. `userdata` tags the outcome. A missing file fails
*immediately* (throws) rather than reaching the queue. C: `SDL_LoadFileAsync`. -/
@[extern "lean_sdl_load_file_async"]
opaque loadFileAsync (file : @& String) (queue : @& AsyncIOQueue)
    (userdata : UInt64 := 0) : IO Unit

end Sdl

end
