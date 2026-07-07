import Sdl
import Tests.Harness

/-!
# AsyncIO runtime tests

Exercises the full async-I/O round trip (write / read / short-read-past-EOF /
getSize / close), `loadFileAsync`, immediate-failure paths, and use-after-
consume behavior, all inside a throwaway temp directory. Needs no `Sdl.init`.
-/

namespace Tests.AsyncIO
open Sdl Tests.Harness

/-- Wait up to 5s for the next completed task (a timeout is a test failure). -/
private def waitOne (q : AsyncIOQueue) : IO AsyncIOOutcome := do
  match ← q.waitResult 5000 with
  | some o => pure o
  | none   => throw (IO.userError "AsyncIO waitResult timed out")

/-- Open one file, write 13 bytes, read them back, short-read past EOF, query
the size, then close — checking each outcome. Ends by destroying the queue and
confirming use-after-consume throws. -/
def fileTests (path : String) : IO Unit := do
  let q ← AsyncIOQueue.create
  check "getResult on empty queue == none" ((← q.getResult).isNone)
  let bytes := "hello sdl3 io".toUTF8
  check "content is 13 bytes" (bytes.size == 13)
  let aio ← AsyncIO.fromFile path "w+"
  -- write
  aio.write bytes 0 q (userdata := 1)
  let wo ← waitOne q
  check "write taskType == .write" (wo.taskType == .write)
  check "write result == .complete" (wo.result == .complete)
  check "write bytesTransferred == 13" (wo.bytesTransferred == 13)
  check "write userdata == 1" (wo.userdata == 1)
  check "write buffer == none" wo.buffer.isNone
  -- full read
  aio.read 0 13 q (userdata := 2)
  let ro ← waitOne q
  check "read taskType == .read" (ro.taskType == .read)
  check "read result == .complete" (ro.result == .complete)
  check "read userdata == 2" (ro.userdata == 2)
  check "read buffer == written bytes" (ro.buffer == some bytes)
  -- short read past EOF (offset 5, size 64 -> 8 bytes)
  aio.read 5 64 q (userdata := 3)
  let so ← waitOne q
  check "short read result == .complete" (so.result == .complete)
  check "short read bytesTransferred == 8" (so.bytesTransferred == 8)
  check "short read buffer == tail 8 bytes" (so.buffer == some (bytes.extract 5 13))
  -- size
  check "getSize == 13" ((← aio.getSize) == 13)
  -- close (flush) then use-after-close throws
  aio.close true q (userdata := 4)
  let co ← waitOne q
  check "close taskType == .close" (co.taskType == .close)
  check "close result == .complete" (co.result == .complete)
  checkThrows "getSize after close throws" aio.getSize
  -- destroy queue then use-after-destroy throws
  q.destroy
  checkThrows "getResult after destroy throws" q.getResult

/-- `loadFileAsync` slurps the whole (now-closed) file back. -/
def loadTests (path : String) : IO Unit := do
  let q ← AsyncIOQueue.create
  Sdl.loadFileAsync path q (userdata := 7)
  let lo ← waitOne q
  check "loadFileAsync taskType == .read" (lo.taskType == .read)
  check "loadFileAsync result == .complete" (lo.result == .complete)
  check "loadFileAsync userdata == 7" (lo.userdata == 7)
  check "loadFileAsync buffer == content" (lo.buffer == some "hello sdl3 io".toUTF8)
  q.destroy

/-- Immediate-failure paths: a missing file both for `fromFile "r"` and for
`loadFileAsync` (the latter fails synchronously, never reaching the queue). -/
def missingTests (dir : String) : IO Unit := do
  let q ← AsyncIOQueue.create
  checkThrows "fromFile missing path mode r throws"
    (AsyncIO.fromFile (dir ++ "/does-not-exist.dat") "r")
  checkThrows "loadFileAsync missing path throws"
    (Sdl.loadFileAsync (dir ++ "/does-not-exist.dat") q)
  q.destroy

def run : IO Unit := do
  let dir ← IO.FS.createTempDir
  let path := dir.toString ++ "/aio.dat"
  try
    fileTests path
    loadTests path
    missingTests dir.toString
  finally
    IO.FS.removeDirAll dir

end Tests.AsyncIO
