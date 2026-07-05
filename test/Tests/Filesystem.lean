import Sdl
import Tests.Harness

namespace Tests.Filesystem
open Sdl Tests.Harness

/-- Path queries plus a full round of directory-tree operations inside the
per-user pref directory (create/write/info/copy/rename/glob/remove). -/
def run : IO Unit := do
  -- base/pref/user/cwd path queries
  let base ← Sdl.getBasePath
  check "getBasePath nonempty" (!base.isEmpty)
  let pref ← Sdl.getPrefPath "lean-sdl3" "test-harness"
  check "getPrefPath nonempty" (!pref.isEmpty)
  check "getPrefPath ends with separator" (pref.endsWith "/" || pref.endsWith "\\")
  let home ← Sdl.getUserFolder .home
  check "getUserFolder home nonempty" (!home.isEmpty)
  let cwd ← Sdl.getCurrentDirectory
  check "getCurrentDirectory nonempty" (!cwd.isEmpty)
  -- sandbox: write a probe file into the pref dir
  let content := "hello sdl3 filesystem\n"
  let expectedSize := content.toUTF8.size.toUInt64
  let filePath := pref ++ "probe.txt"
  IO.FS.writeFile filePath content
  let info ← Sdl.getPathInfo filePath
  check "getPathInfo type == .file" (info.type == .file)
  check "getPathInfo size matches" (info.size == expectedSize)
  -- copyFile preserves size
  let copyPath := pref ++ "probe-copy.txt"
  Sdl.copyFile filePath copyPath
  let copyInfo ← Sdl.getPathInfo copyPath
  check "copyFile size matches" (copyInfo.size == info.size)
  -- renamePath moves the copy away
  let renamedPath := pref ++ "probe-renamed.txt"
  Sdl.renamePath copyPath renamedPath
  check "renamePath preserved size" ((← Sdl.getPathInfo renamedPath).size == info.size)
  checkThrows "getPathInfo of renamed-away path throws" (Sdl.getPathInfo copyPath)
  -- glob finds the probe files by pattern
  let globbed ← Sdl.globDirectory pref (some "probe*.txt")
  check "globDirectory finds probe.txt" (globbed.contains "probe.txt")
  -- createDirectory + directory path info
  let dirPath := pref ++ "probe-dir"
  Sdl.createDirectory dirPath
  check "createDirectory type == .directory" ((← Sdl.getPathInfo dirPath).type == .directory)
  -- removePath cleans up; afterwards the path info throws
  Sdl.removePath filePath
  Sdl.removePath renamedPath
  Sdl.removePath dirPath
  checkThrows "getPathInfo of removed file throws" (Sdl.getPathInfo filePath)
  -- a never-existing path also throws
  checkThrows "getPathInfo of nonexistent path throws"
    (Sdl.getPathInfo (pref ++ "definitely-does-not-exist-xyz.dat"))

end Tests.Filesystem
