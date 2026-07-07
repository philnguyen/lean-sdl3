import Common

/-!
# demo/04-bytepusher

An implementation of the BytePusher VM — a minimal "one instruction set
computer" whose entire program is a chain of `ByteByteJump` copies. Drop a
`.BytePusher` ROM onto the window to run it. See
https://esolangs.org/wiki/BytePusher.

Port of the official example `examples/demo/04-bytepusher/bytepusher.c`
(https://examples.libsdl.org/SDL3/demo/04-bytepusher/). The VM core is a pure,
`#guard`-tested Lean reimplementation; the fixed-timestep loop, palette,
streaming texture, and audio wiring mirror the C.

## Deviations
- **RAM as a linear `ByteArray`**: the C keeps `Uint8 ram[RAM_SIZE + 8]` inline
  in the app struct. We hold it in an `IO.Ref ByteArray` and, each frame, take
  it out of the ref (leaving `ByteArray.empty` behind) so the VM step's 65536
  `set!` writes are uniquely referenced and mutate **in place** — a copying step
  would be terabytes of `memcpy` per frame. The pure `runFrame` never holds a
  second live reference across a `set!`.
- **Self-check (Snake precedent)**: when `SDL_LEAN_MAX_FRAMES` is set and a ROM
  path was given, a failed init-load prints the error and exits nonzero; and
  after the last capped frame, when the ROM is `hello.BytePusher`, the demo
  asserts the framebuffer gradient byte `ram[0x010000 + 256 + 2] == 3`. This is
  the milestone's "loads a program in test" gate.
- No `Sdl.quit`; SDL reclaims the window/renderer/audio at process exit.
-/

open Sdl

/-! ## Constants (C: the `#define`s) -/

def screenW : Nat := 256
def screenH : Nat := 256
def ramSize : Nat := 0x1000000
def framesPerSecond : Nat := 60
def samplesPerFrame : Nat := 256
def maxAudioLatencyFrames : UInt64 := 5

def ioKeyboard : Nat := 0
def ioPc : Nat := 2
def ioScreenPage : Nat := 5
def ioAudioBank : Nat := 6

/-! ## Pure VM core -/

/-- Read a big-endian 16-bit word at `addr`. C: `read_u16`. -/
def readU16 (ram : ByteArray) (addr : Nat) : UInt16 :=
  (ram[addr]!.toUInt16 <<< 8) ||| ram[addr + 1]!.toUInt16

/-- Read a big-endian 24-bit word at `addr`. C: `read_u24`. -/
def readU24 (ram : ByteArray) (addr : Nat) : Nat :=
  (ram[addr]!.toNat <<< 16) ||| (ram[addr + 1]!.toNat <<< 8) ||| ram[addr + 2]!.toNat

#guard readU16 ⟨#[0x12, 0x34]⟩ 0 == 0x1234
#guard readU16 ⟨#[0x00, 0x01]⟩ 0 == 1
#guard readU24 ⟨#[0xAB, 0xCD, 0xEF]⟩ 0 == 0xABCDEF
#guard readU24 ⟨#[0x00, 0x01, 0x00]⟩ 0 == 0x000100

/-- One VM instruction (`ByteByteJump`): copy `ram[src] → ram[dst]` and return
the updated RAM and the next program counter. Factored out of `runFrame` for
`#guard` testing on a tiny RAM. C: the body of the inner `for` loop. -/
def vmStep (ram : ByteArray) (pc : Nat) : ByteArray × Nat :=
  let src := readU24 ram pc
  let dst := readU24 ram (pc + 3)
  let ram := ram.set! dst ram[src]!
  (ram, readU24 ram (pc + 6))

-- Instruction at pc = 8: src = 0x000000, dst = 0x000007, next = 0x000008.
-- Copies ram[0] (0x42) to ram[7] and jumps back to pc = 8.
#guard
  let ram : ByteArray := ⟨#[0x42, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 8]⟩
  let (ram', pc') := vmStep ram 8
  ram'[7]! == 0x42 && pc' == 8

/-- Run one 65536-instruction VM frame: latch `keystate` big-endian at
`[0..1]`, then chase the `ByteByteJump` chain from `pc = read_u24 2`. Mutates
`ram` in place (see the module note on linearity). C: the `while` body's inner
loop. -/
def runFrame (ram : ByteArray) (keystate : UInt16) : ByteArray := Id.run do
  let mut ram := ram
  ram := ram.set! ioKeyboard (keystate >>> 8).toUInt8
  ram := ram.set! (ioKeyboard + 1) keystate.toUInt8
  let mut pc := readU24 ram ioPc
  for _ in [0:screenW * screenH] do
    let src := readU24 ram pc
    let dst := readU24 ram (pc + 3)
    ram := ram.set! dst ram[src]!
    pc := readU24 ram (pc + 6)
  return ram

/-- The keyboard bit for a symbolic-input keycode (`0`-`9`, `A`-`F`), or `0`.
C: `keycode_mask`. -/
def keycodeMask (key : Keycode) : UInt16 :=
  let k := key.val
  if Keycode.num0.val ≤ k ∧ k ≤ Keycode.num9.val then
    (1 : UInt16) <<< (k - Keycode.num0.val).toUInt16
  else if Keycode.a.val ≤ k ∧ k ≤ Keycode.f.val then
    (1 : UInt16) <<< (k - Keycode.a.val + 10).toUInt16
  else 0

#guard keycodeMask Keycode.num0 == 0x1
#guard keycodeMask Keycode.num9 == ((1 : UInt16) <<< 9)
#guard keycodeMask Keycode.a == ((1 : UInt16) <<< 10)
#guard keycodeMask Keycode.f == ((1 : UInt16) <<< 15)
#guard keycodeMask Keycode.g == 0

/-- The 4×4 positional bit index for a scancode (the physical hex keypad
layout), or `none`. C: the `scancode_mask` switch. -/
def scancodeBit (sc : Scancode) : Option UInt16 :=
  if sc == .num1 then some 0x1
  else if sc == .num2 then some 0x2
  else if sc == .num3 then some 0x3
  else if sc == .num4 then some 0xc
  else if sc == .q then some 0x4
  else if sc == .w then some 0x5
  else if sc == .e then some 0x6
  else if sc == .r then some 0xd
  else if sc == .a then some 0x7
  else if sc == .s then some 0x8
  else if sc == .d then some 0x9
  else if sc == .f then some 0xe
  else if sc == .z then some 0xa
  else if sc == .x then some 0x0
  else if sc == .c then some 0xb
  else if sc == .v then some 0xf
  else none

/-- The keyboard bit for a positional-input scancode, or `0`.
C: `scancode_mask`. -/
def scancodeMask (sc : Scancode) : UInt16 :=
  match scancodeBit sc with
  | some i => (1 : UInt16) <<< i
  | none   => 0

#guard scancodeMask Scancode.num1 == ((1 : UInt16) <<< 0x1)
#guard scancodeMask Scancode.num4 == ((1 : UInt16) <<< 0xc)
#guard scancodeMask Scancode.x == ((1 : UInt16) <<< 0x0)
#guard scancodeMask Scancode.v == ((1 : UInt16) <<< 0xf)
#guard scancodeMask Scancode.g == 0

/-! ## RAM construction and the web-safe palette -/

/-- A fresh zero-filled RAM of `ramSize + 8` bytes (the `+8` guards the final
`read_u24` at `pc + 6`). A 16 MiB push-fill is effectively instant. -/
def zeroRam : ByteArray := Id.run do
  let mut b := ByteArray.emptyWithCapacity (ramSize + 8)
  for _ in [0:ramSize + 8] do
    b := b.push 0
  return b

/-- RAM holding the first `min bytes.size ramSize` bytes of `bytes`, zero-padded
to `ramSize + 8`. C: the `SDL_memset` + `SDL_ReadIO` loop in `load`. -/
def buildRam (bytes : ByteArray) : ByteArray := Id.run do
  let n := min bytes.size ramSize
  let mut b := ByteArray.emptyWithCapacity (ramSize + 8)
  for i in [0:n] do
    b := b.push bytes[i]!
  for _ in [n:ramSize + 8] do
    b := b.push 0
  return b

/-- The 256-entry palette: the 216 web-safe colors (`r,g,b ∈ {0,0x33,…,0xFF}`)
then black for indices 216-255. C: the palette-fill loops in `SDL_AppInit`. -/
def buildPalette : Array Color := Id.run do
  let mut arr := Array.emptyWithCapacity 256
  for r in [0:6] do
    for g in [0:6] do
      for b in [0:6] do
        arr := arr.push
          { r := (r * 0x33).toUInt8, g := (g * 0x33).toUInt8,
            b := (b * 0x33).toUInt8, a := 255 }
  for _ in [216:256] do
    arr := arr.push { r := 0, g := 0, b := 0, a := 255 }
  return arr

#guard buildPalette.size == 256
#guard buildPalette[0]! == { r := 0, g := 0, b := 0, a := 255 }
#guard buildPalette[215]! == { r := 0xFF, g := 0xFF, b := 0xFF, a := 255 }
#guard buildPalette[216]! == { r := 0, g := 0, b := 0, a := 255 }

/-! ## App wiring -/

structure State where
  window : Window
  renderer : Renderer
  texture : Texture
  audiostream : AudioStream
  /-- The VM RAM (`ramSize + 8` bytes); taken out uniquely each frame. -/
  ram : IO.Ref ByteArray
  lastTick : IO.Ref UInt64
  tickAcc : IO.Ref UInt64
  keystate : IO.Ref UInt16
  status : IO.Ref String
  statusTicks : IO.Ref Nat
  displayHelp : IO.Ref Bool
  positionalInput : IO.Ref Bool
  /-- Frame counter for the headless self-check. -/
  frame : IO.Ref Nat
  /-- `SDL_LEAN_MAX_FRAMES`, if set. -/
  maxFrames : Option Nat
  /-- Whether the ROM given on the command line is the self-check test ROM. -/
  selfCheckRom : Bool

/-- The last path component (after the final `/` or `\`). C: `filename`. -/
def basename (path : String) : String :=
  ((path.replace "\\" "/").splitOn "/").getLastD path

/-- Set the transient status line, visible for 3 seconds. C: `set_status`
(truncated to `SCREEN_W / 8` characters). -/
def setStatus (s : State) (msg : String) : IO Unit := do
  s.status.set (String.ofList (msg.toList.take (screenW / 8 - 1)))
  s.statusTicks.set (framesPerSecond * 3)

/-- Load a ROM from `path`, rebuilding RAM. Returns `true` on success. On
failure RAM is zeroed and the help screen is shown. C: `load_file` + `load`. -/
def loadRom (s : State) (path : String) : IO Bool := do
  try
    let stream ← Sdl.ioFromFile path "rb"
    let bytes ← stream.loadFile
    stream.close
    if bytes.size > ramSize then
      throw (IO.userError s!"ROM larger than {ramSize} bytes")
    s.ram.set (buildRam bytes)
    s.audiostream.clear
    s.displayHelp.set false
    setStatus s s!"loaded {basename path}"
    return true
  catch _ =>
    s.ram.set zeroRam
    s.audiostream.clear
    s.displayHelp.set true
    setStatus s s!"load failed: {basename path}"
    return false

/-- Draw shadowed debug text: black at `(x+1, y+1)`, white at `(x, y)`.
C: `print`. -/
def print (r : Renderer) (x y : Int32) (str : String) : IO Unit := do
  r.setDrawColor 0 0 0 255
  r.debugText (x + 1).toFloat32 (y + 1).toFloat32 str
  r.setDrawColor 0xff 0xff 0xff 255
  r.debugText x.toFloat32 y.toFloat32 str
  r.setDrawColor 0 0 0 255

/-- The window zoom from the primary display's usable bounds
(`(w - x) * 2 / 3 / SCREEN_W`, likewise for height), min 1. Falls back to 2 if
the display can't be queried. C: the `zoom` computation in `SDL_AppInit`. -/
def computeZoom : IO Nat := do
  try
    let display ← getPrimaryDisplay
    let b ← display.usableBounds
    let zw := (b.w - b.x) * 2 / 3 / (Int32.ofNat screenW)
    let zh := (b.h - b.y) * 2 / 3 / (Int32.ofNat screenH)
    return max 1 (min zw zh).toNatClampNeg
  catch _ => return 2

def app : App State where
  init := fun args => do
    setAppMetadata "SDL 3 BytePusher" "1.0" "com.example.SDL3BytePusher"
    -- Extended metadata (C: the `extended_metadata[]` table).
    setAppMetadataProperty "SDL.app.metadata.url" "https://examples.libsdl.org/SDL3/demo/04-bytepusher/"
    setAppMetadataProperty "SDL.app.metadata.creator" "SDL team"
    setAppMetadataProperty "SDL.app.metadata.copyright" "Placed in the public domain"
    setAppMetadataProperty "SDL.app.metadata.type" "game"
    Sdl.init (.audio ||| .video)
    let zoom ← computeZoom
    let (window, renderer) ←
      createWindowAndRenderer "SDL 3 BytePusher"
        (Int32.ofNat (screenW * zoom)) (Int32.ofNat (screenH * zoom)) .resizable
    renderer.setLogicalPresentation
      (Int32.ofNat screenW) (Int32.ofNat screenH) .integerScale
    let palette ← createPalette 256
    palette.setColors buildPalette
    let texture ← renderer.createTexture .index8 .streaming
      (Int32.ofNat screenW) (Int32.ofNat screenH)
    texture.setPalette palette
    texture.setScaleMode .nearest
    let audiospec : AudioSpec := ⟨.s8, 1, Int32.ofNat (samplesPerFrame * framesPerSecond)⟩
    let audiostream ← openAudioDeviceStream .defaultPlayback (some audiospec)
    audiostream.setGain 0.1  -- examples are loud!
    audiostream.resumeDevice
    -- State.
    let ram ← IO.mkRef zeroRam
    let lastTick ← IO.mkRef (← getTicksNS)
    -- Start one frame "behind" so the first iterate runs a VM frame (C: tick_acc).
    let tickAcc ← IO.mkRef nsPerSecond
    let keystate ← IO.mkRef (0 : UInt16)
    let status ← IO.mkRef ""
    let statusTicks ← IO.mkRef 0
    let displayHelp ← IO.mkRef true
    let positionalInput ← IO.mkRef false
    let frame ← IO.mkRef 0
    let maxFrames := (← IO.getEnv "SDL_LEAN_MAX_FRAMES").bind (·.toNat?)
    let romPath? := args.head?
    let selfCheckRom := match romPath? with
      | some p => basename p == "hello.BytePusher"
      | none   => false
    let s : State :=
      { window, renderer, texture, audiostream, ram, lastTick, tickAcc, keystate,
        status, statusTicks, displayHelp, positionalInput, frame, maxFrames,
        selfCheckRom }
    setStatus s s!"renderer: {← renderer.name}"
    match romPath? with
    | some path =>
      let ok ← loadRom s path
      if !ok ∧ maxFrames.isSome then
        IO.eprintln s!"load failed: {path}"
        return (.failure, none)
    | none => pure ()
    return (.continue, some s)
  event := fun s e => do
    match e with
    | .quit _ => return .success
    | .dropFile de =>
      if let some path := de.data then
        let _ ← loadRom s path
      return .continue
    | .keyDown ke =>
      if ke.key == Keycode.escape then return .success
      if ke.key == Keycode.«return» then
        s.positionalInput.modify not
        s.keystate.set 0
        if (← s.positionalInput.get) then setStatus s "switched to positional input"
        else setStatus s "switched to symbolic input"
      let mask :=
        if (← s.positionalInput.get) then scancodeMask ke.scancode
        else keycodeMask ke.key
      s.keystate.modify (· ||| mask)
      return .continue
    | .keyUp ke =>
      let mask :=
        if (← s.positionalInput.get) then scancodeMask ke.scancode
        else keycodeMask ke.key
      s.keystate.modify (· &&& (~~~ mask))
      return .continue
    | _ => return .continue
  iterate := fun s => do
    let tick ← getTicksNS
    let delta := tick - (← s.lastTick.get)
    s.lastTick.set tick
    let mut tickAcc := (← s.tickAcc.get) + delta * framesPerSecond.toUInt64
    let updated := tickAcc ≥ nsPerSecond
    let skipAudio := tickAcc ≥ maxAudioLatencyFrames * nsPerSecond
    if skipAudio then
      -- Don't let audio fall too far behind.
      s.audiostream.clear
    let keystate ← s.keystate.get
    -- Take RAM out of the ref so the VM step mutates it in place.
    let mut ram ← s.ram.get
    s.ram.set ByteArray.empty
    while tickAcc ≥ nsPerSecond do
      tickAcc := tickAcc - nsPerSecond
      ram := runFrame ram keystate
      if (!skipAudio) ∨ tickAcc < nsPerSecond then
        let bankAddr := (readU16 ram ioAudioBank).toNat <<< 8
        s.audiostream.putData (ram.extract bankAddr (bankAddr + samplesPerFrame))
    s.tickAcc.set tickAcc
    if updated then
      let page := ram[ioScreenPage]!.toNat <<< 16
      s.texture.update none (ram.extract page (page + screenW * screenH))
        (Int32.ofNat screenW)
    s.ram.set ram
    -- Render.
    s.renderer.setDrawColor 0 0 0 255
    s.renderer.clear
    if (← s.displayHelp.get) then
      print s.renderer 4 4 "Drop a BytePusher file in this"
      print s.renderer 8 12 "window to load and run it!"
      print s.renderer 4 28 "Press ENTER to switch between"
      print s.renderer 8 36 "positional and symbolic input."
    else
      s.renderer.texture s.texture
    let st ← s.statusTicks.get
    if st > 0 then
      if updated then s.statusTicks.set (st - 1)
      print s.renderer 4 (Int32.ofNat (screenH - 12)) (← s.status.get)
    s.renderer.present
    -- Headless self-check on the last capped frame.
    match s.maxFrames with
    | some cap =>
      let f ← s.frame.get
      s.frame.set (f + 1)
      if s.selfCheckRom ∧ f + 1 == cap then
        let ramNow ← s.ram.get
        let v := ramNow[0x010000 + 256 + 2]!
        if v != 3 then
          throw <| IO.userError
            s!"bytepusher self-check failed: fb[1][2] = {v}, expected 3"
        IO.println "bytepusher self-check: fb[1][2] == 3 (ok)"
    | none => pure ()
    return .continue

def main (args : List String) : IO UInt32 := Examples.runApp app args
