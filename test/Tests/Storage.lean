import Sdl
import Tests.Harness

/-!
# Storage runtime tests

A full round of file-storage operations (write / read / info / mkdir / copy /
rename / recursive glob / enumerate / space / path-escape rejection / remove /
close) inside a throwaway temp directory, plus a user-storage round trip under
the real pref path. Needs no `Sdl.init`.
-/

namespace Tests.Storage
open Sdl Tests.Harness

/-- File storage over a scratch directory: build a small tree and verify every
operation, including the recursive glob listing and path-escape rejection. -/
def fileStorageTests (dir : String) : IO Unit := do
  let st ← Storage.openFile dir
  check "openFile ready == true" (← st.ready)
  let data := "abcd".toUTF8
  st.writeFile "save.dat" data
  check "getFileSize save.dat == 4" ((← st.getFileSize "save.dat") == 4)
  check "readFile round-trips" ((← st.readFile "save.dat") == data)
  -- build a subtree: sub/dir/renamed.dat
  st.createDirectory "sub/dir"
  st.copyFile "save.dat" "sub/dir/copy.dat"
  st.renamePath "sub/dir/copy.dat" "sub/dir/renamed.dat"
  let info ← st.getPathInfo "save.dat"
  check "getPathInfo type == .file" (info.type == .file)
  check "getPathInfo size == 4" (info.size == 4)
  checkThrows "getPathInfo missing throws" (st.getPathInfo "does-not-exist.dat")
  -- recursive glob of the root
  let entries ← st.globDirectory
  check "glob contains save.dat" (entries.contains "save.dat")
  check "glob contains sub" (entries.contains "sub")
  check "glob contains sub/dir" (entries.contains "sub/dir")
  check "glob contains sub/dir/renamed.dat" (entries.contains "sub/dir/renamed.dat")
  -- enumerate a single directory into an accumulator
  let acc ← IO.mkRef (#[] : Array String)
  st.enumerateDirectory "sub" fun _ fname => do
    acc.modify (·.push fname)
    pure .«continue»
  check "enumerateDirectory sub contains dir" ((← acc.get).contains "dir")
  -- space + escape rejection
  check "spaceRemaining == UInt64.max" ((← st.spaceRemaining) == 0xFFFFFFFFFFFFFFFF)
  checkThrows "getFileSize ../x escape throws" (st.getFileSize "../x")
  -- remove the tree, close, then use-after-close throws
  st.removePath "sub/dir/renamed.dat"
  st.removePath "sub/dir"
  st.removePath "sub"
  st.removePath "save.dat"
  st.close
  checkThrows "ready after close throws" st.ready

/-- User storage under the real pref path: a write/read round trip, cleaned up
afterwards (the empty org/app dirs may remain, which is fine). -/
def userStorageTests : IO Unit := do
  let st ← Storage.openUser "com.example" "lean-sdl3-test"
  check "openUser ready == true" (← st.ready)
  let data := "save".toUTF8
  st.writeFile "probe.sav" data
  check "openUser readFile round-trips" ((← st.readFile "probe.sav") == data)
  st.removePath "probe.sav"
  st.close

def run : IO Unit := do
  let dir ← IO.FS.createTempDir
  try
    fileStorageTests dir.toString
    userStorageTests
  finally
    IO.FS.removeDirAll dir

end Tests.Storage
