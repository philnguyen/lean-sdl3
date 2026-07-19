import Sdl
import Tests.Harness

/-!
# Process runtime tests

Run headless with no `Sdl.init` (process control needs no subsystem). Only the
whitelisted binaries `/bin/echo`, `/bin/cat`, `/bin/sleep` are spawned.
-/

namespace Tests.Process
open Sdl Tests.Harness

/-- `echo` with piped stdio: `read` blocks to exit and returns the stdout bytes
plus exit code 0. -/
def echoTests : IO Unit := do
  let p ← createProcess #["/bin/echo", "hello-proc"] (pipeStdio := true)
  let (data, code) ← p.read
  check "echo read == \"hello-proc\\n\"" (data == "hello-proc\n".toUTF8)
  check "echo exit code 0" (code == 0)
  p.destroy

/-- `getProperties` exposes the pid (a positive number). -/
def pidTests : IO Unit := do
  let p ← createProcess #["/bin/sleep", "10"]
  let props ← p.getProperties
  let pid ← props.getNumberProperty Process.Props.pidNumber
  check "process pid > 0" (pid > 0)
  p.kill (force := true)
  let _ ← p.wait
  p.destroy

/-- `cat` with piped stdio: write then `closeInput` (EOF), and poll the
NON-BLOCKING output stream until the echoed bytes arrive or EOF. Also: `getInput`
after `closeInput` throws. -/
def catTests : IO Unit := do
  let p ← createProcess #["/bin/cat"] (pipeStdio := true)
  let inp ← p.getInput
  inp.write "ping\n".toUTF8
  p.closeInput
  checkThrows "getInput after closeInput throws" p.getInput
  let out ← p.getOutput
  let mut acc : ByteArray := .emptyWithCapacity 8
  let mut tries := 0
  let mut done := false
  while !done && tries < 300 do
    let chunk ← out.read 64
    if chunk.size > 0 then
      acc := acc ++ chunk
    if acc.size ≥ 5 then
      done := true
    else
      let st ← out.status
      if st == .eof then
        done := true
      else if chunk.size == 0 && st == .notReady then
        Sdl.delay 10
    tries := tries + 1
  check "cat echoes \"ping\\n\" via poll loop" (acc == "ping\n".toUTF8)
  let _ ← p.wait
  p.destroy

/-- Blocking `wait` on a quick process returns `some 0`. -/
def waitTests : IO Unit := do
  let p ← createProcess #["/bin/echo", "x"]
  match ← p.wait (block := true) with
  | some c => check "wait (block:=true) → some 0" (c == 0)
  | none   => check "wait (block:=true) → some 0" false
  p.destroy

/-- A running process: non-blocking `wait` is `none`; after a forced `kill`,
blocking `wait` returns a nonzero (signal) exit code. -/
def killTests : IO Unit := do
  let p ← createProcess #["/bin/sleep", "10"]
  check "wait (block:=false) on running → none" ((← p.wait (block := false)).isNone)
  p.kill (force := true)
  match ← p.wait (block := true) with
  | some c => check "killed process exit code != 0" (c != 0)
  | none   => check "killed process exit code != 0" false
  p.destroy

/-- Failure paths: a nonexistent binary fails at create time (macOS), and a
destroyed handle throws on further use. -/
def failureTests : IO Unit := do
  checkThrows "createProcess of nonexistent binary throws"
    (createProcess #["/nonexistent/definitely-not-a-binary-xyz"])
  let p ← createProcess #["/bin/echo", "z"]
  p.destroy
  checkThrows "use after destroy throws" (p.wait (block := false))
  -- a borrowed stream handle outliving its process's destroy throws, never UB
  let p2 ← createProcess #["/bin/cat"] (pipeStdio := true)
  let inp ← p2.getInput
  let out ← p2.getOutput
  p2.kill (force := true)
  discard <| p2.wait (block := true)
  p2.destroy
  checkThrows "stale stdin stream after destroy throws" (inp.write "x".toUTF8)
  checkThrows "stale stdout stream after destroy throws" (out.read 8)

def run : IO Unit := do
  echoTests
  pidTests
  catTests
  waitTests
  killTests
  failureTests

end Tests.Process
