import Common

/-!
# demo/02-woodeneye-008

A split-screen first-person shooter for up to four players, each bound to a
distinct mouse+keyboard pair (hot-plugged as devices produce input). Players
walk/strafe with WASD, jump with space, look with the mouse, and shoot with the
mouse button (a ray-sphere hit test that respawns anyone hit).

Port of the official example `examples/demo/02-woodeneye-008/woodeneye-008.c`
(https://examples.libsdl.org/SDL3/demo/02-woodeneye-008/). The physics, hit
test, projection, and scene assembly are a faithful reimplementation of the C;
pure logic (with `#guard` tests) is separated from the SDL app wiring, following
`examples/demo/01-snake`.

## Deviations
- **RNG**: the C respawn draws positions from SDL's global `SDL_rand`. We carry
  an `xorshift64` state in the app state (the Snake idiom), so `shoot` stays a
  pure function. Respawn positions therefore differ bit-for-bit from the C, but
  follow the same `MAP_BOX_SCALE * (rand%256 - 128) / 256` distribution.
- **Device ownership as `Option`**: C stores an unassigned mouse/keyboard as id
  `0`; we use `Option MouseId`/`Option KeyboardId` with `none` for unassigned,
  and match owners by `some id` equality (id `0` never owns a slot).
- **`SDL_HINT_WINDOWS_RAW_KEYBOARD`**: skipped — it is a Windows-only hint with
  no effect on this repo's platforms.
- **Pitch clamp intermediate**: C's `pitch - (int)yrel * 0x00080000` can
  transiently overflow `int`; we compute it in `Int64` before clamping to
  `±0x40000000`, matching the observable clamped result.
- No `Sdl.quit`; window/renderer are released by their finalizers at exit.
-/

open Sdl

/-! ## Constants (C: the `#define`s) -/

/-- C: `MAP_BOX_SCALE`. -/
def mapBoxScale : Nat := 16
/-- C: `MAP_BOX_EDGES_LEN` = `12 + MAP_BOX_SCALE * 2`. -/
def mapBoxEdgesLen : Nat := 12 + mapBoxScale * 2
/-- C: `MAX_PLAYER_COUNT`. -/
def maxPlayerCount : Nat := 4
/-- C: `CIRCLE_DRAW_SIDES`. -/
def circleDrawSides : Nat := 32
/-- C: `CIRCLE_DRAW_SIDES_LEN`. -/
def circleDrawSidesLen : Nat := circleDrawSides + 1

/-! ## State types -/

/-- One player. C: the `Player` struct. `yaw` is unsigned and wraps (Lean
`UInt32` arithmetic wraps identically to C's `unsigned int`); `pitch` is a
signed binary angle clamped to `±0x40000000`. -/
structure Player where
  mouse : Option MouseId
  keyboard : Option KeyboardId
  posX : Float
  posY : Float
  posZ : Float
  velX : Float
  velY : Float
  velZ : Float
  yaw : UInt32
  pitch : Int32
  radius : Float
  height : Float
  colorR : UInt8
  colorG : UInt8
  colorB : UInt8
  /-- Movement bitmask: 1=W 2=A 4=S 8=D 16=space (C: `wasd`). -/
  wasd : UInt8
deriving Repr, Inhabited

/-- One box/grid edge: endpoints `a` and `b`. C: a `float[6]` row of `edges`. -/
structure Edge where
  ax : Float
  ay : Float
  az : Float
  bx : Float
  «by» : Float
  bz : Float
deriving Repr, Inhabited, BEq

/-! ## Pure logic -/

/-- One step of the xorshift64 PRNG (never maps a nonzero state to zero). Same
generator as `demo/01-snake`. -/
def xorshift64 (s : UInt64) : UInt64 :=
  let s := s ^^^ (s <<< 13)
  let s := s ^^^ (s >>> 7)
  s ^^^ (s <<< 17)

/-- Advance `s` and return a value in `[0, n)` alongside the new state. Stands in
for C's `SDL_rand(n)`. -/
def randMod (s : UInt64) (n : UInt64) : UInt64 × UInt64 :=
  let s := xorshift64 s
  (s % n, s)

/-- Initialize all `maxPlayerCount` players. C: `initPlayers`. -/
def initPlayers : Array Player := Id.run do
  let mut players := Array.replicate maxPlayerCount (default : Player)
  for i in [0:maxPlayerCount] do
    let iOdd := i &&& 1 != 0
    let iBit2 := i &&& 2 != 0
    let base0 : UInt8 := if (1 <<< (i / 2)) &&& 2 != 0 then 0 else 0xff
    let base1 : UInt8 := if (1 <<< (i / 2)) &&& 1 != 0 then 0 else 0xff
    let base2 : UInt8 := if (1 <<< (i / 2)) &&& 4 != 0 then 0 else 0xff
    let p : Player := {
      mouse := none
      keyboard := none
      posX := 8.0 * (if iOdd then -1.0 else 1.0)
      posY := 0.0
      posZ := 8.0 * (if iOdd then -1.0 else 1.0) * (if iBit2 then -1.0 else 1.0)
      velX := 0.0, velY := 0.0, velZ := 0.0
      yaw := 0x20000000 + (if iOdd then 0x80000000 else 0) + (if iBit2 then 0x40000000 else 0)
      pitch := -0x08000000
      radius := 0.5, height := 1.5
      wasd := 0
      colorR := if iOdd then base0 else ~~~base0
      colorG := if iOdd then base1 else ~~~base1
      colorB := if iOdd then base2 else ~~~base2 }
    players := players.set! i p
  return players

#guard initPlayers.size == 4
#guard initPlayers[0]!.yaw == 0x20000000
#guard initPlayers[1]!.yaw == 0xA0000000   -- 0x20000000 + 0x80000000
#guard initPlayers[0]!.pitch == -0x08000000
-- Player 0 is green (0, 255, 0); player 1's colors are the complement path.
#guard initPlayers[0]!.colorR == 0
#guard initPlayers[0]!.colorG == 255
#guard initPlayers[0]!.colorB == 0
#guard initPlayers[0]!.posX == 8.0
#guard initPlayers[1]!.posX == -8.0

/-- A single corner coordinate of the box for 3-bit index `idx` at axis `bit`.
C: `(map[...] & (1 << j) ? r : -r)`. -/
def cornerCoord (idx bit : Nat) (r : Float) : Float :=
  if idx &&& (1 <<< bit) != 0 then r else -r

/-- Build the 44 box + floor-grid edges. C: `initEdges`. -/
def initEdges : Array Edge := Id.run do
  let r := (mapBoxScale : Nat).toFloat
  -- C: `map[24]` — the 12 cube edges as pairs of 3-bit corner indices.
  let map : Array Nat := #[
    0,1 , 1,3 , 3,2 , 2,0 ,
    7,6 , 6,4 , 4,5 , 5,7 ,
    6,2 , 3,7 , 0,4 , 5,1 ]
  let mut edges := Array.replicate mapBoxEdgesLen (default : Edge)
  -- The 12 cube edges.
  for i in [0:12] do
    let a := map[i * 2]!
    let b := map[i * 2 + 1]!
    edges := edges.set! i {
      ax := cornerCoord a 0 r, ay := cornerCoord a 1 r, az := cornerCoord a 2 r
      bx := cornerCoord b 0 r, «by» := cornerCoord b 1 r, bz := cornerCoord b 2 r }
  -- The floor grid lines (two families of `scale` lines each).
  for i in [0:mapBoxScale] do
    let d := ((i * 2 : Nat).toFloat)
    -- family 1 (edges[i+12]): a(-r,-r,d-r) → b(r,-r,d-r)
    edges := edges.set! (i + 12) {
      ax := -r, ay := -r, az := d - r
      bx := r,  «by» := -r, bz := d - r }
    -- family 2 (edges[i+12+scale]): a(d-r,-r,-r) → b(d-r,-r,r)
    edges := edges.set! (i + 12 + mapBoxScale) {
      ax := d - r, ay := -r, az := -r
      bx := d - r, «by» := -r, bz := r }
  return edges

#guard initEdges.size == 44
-- edge 0: corners 0 (-r,-r,-r) and 1 (r,-r,-r).
#guard initEdges[0]!.ax == -16.0 && initEdges[0]!.bx == 16.0
#guard initEdges[0]!.ay == -16.0 && initEdges[0]!.az == -16.0
-- edge 13: i=1, d=2, so az = d - r = 2 - 16 = -14.
#guard initEdges[13]!.az == -14.0
-- edge 28: i=0 of family 2, a(-16,-16,-16) → b(-16,-16,16).
#guard initEdges[28]!.ax == -16.0 && initEdges[28]!.bz == 16.0

/-- Player index owning `mouse` (searching the first `count`). C: `whoseMouse`. -/
def whoseMouse (mouse : MouseId) (players : Array Player) (count : Nat) : Option Nat := Id.run do
  for i in [0:count] do
    if players[i]!.mouse == some mouse then return some i
  return none

/-- Player index owning `keyboard`. C: `whoseKeyboard`. -/
def whoseKeyboard (keyboard : KeyboardId) (players : Array Player) (count : Nat) : Option Nat := Id.run do
  for i in [0:count] do
    if players[i]!.keyboard == some keyboard then return some i
  return none

/-- Integrate one player's physics over `dtNs` nanoseconds. C: the body of
`update`'s loop. -/
def updatePlayer (p : Player) (dtNs : UInt64) : Player := Id.run do
  let rate := 6.0
  let time := dtNs.toFloat * 1e-9
  let drag := Float.exp (-time * rate)
  let diff := 1.0 - drag
  let mult := 60.0
  let grav := 25.0
  let rad := p.yaw.toFloat * Examples.pi / 2147483648.0
  let cos := Float.cos rad
  let sin := Float.sin rad
  let wasd := p.wasd
  let dirX := (if wasd &&& 8 != 0 then 1.0 else 0.0) - (if wasd &&& 2 != 0 then 1.0 else 0.0)
  let dirZ := (if wasd &&& 4 != 0 then 1.0 else 0.0) - (if wasd &&& 1 != 0 then 1.0 else 0.0)
  let norm := dirX * dirX + dirZ * dirZ
  let accX := mult * (if norm == 0.0 then 0.0 else (cos * dirX + sin * dirZ) / Float.sqrt norm)
  let accZ := mult * (if norm == 0.0 then 0.0 else (-sin * dirX + cos * dirZ) / Float.sqrt norm)
  let velX := p.velX
  let velY := p.velY
  let velZ := p.velZ
  -- New velocities (drag on X/Z, gravity on Y, plus acceleration on X/Z).
  let mut nvelX := velX - velX * diff + diff * accX / rate
  let mut nvelY := velY - grav * time
  let mut nvelZ := velZ - velZ * diff + diff * accZ / rate
  -- New (pre-clamp) positions using the *original* velocities.
  let posX0 := p.posX + (time - diff / rate) * accX / rate + diff * velX / rate
  let posY0 := p.posY + (-0.5) * grav * time * time + velY * time
  let posZ0 := p.posZ + (time - diff / rate) * accZ / rate + diff * velZ / rate
  let scale := (mapBoxScale : Nat).toFloat
  let bound := scale - p.radius
  let posX := max (min bound posX0) (-bound)
  let posY := max (min bound posY0) (p.height - scale)
  let posZ := max (min bound posZ0) (-bound)
  if posX0 != posX then nvelX := 0.0
  if posY0 != posY then nvelY := (if wasd &&& 16 != 0 then 8.4375 else 0.0)
  if posZ0 != posZ then nvelZ := 0.0
  return { p with posX, posY, posZ, velX := nvelX, velY := nvelY, velZ := nvelZ }

/-- Integrate all active players. C: `update`. -/
def updateAll (players : Array Player) (count : Nat) (dtNs : UInt64) : Array Player := Id.run do
  let mut ps := players
  for i in [0:count] do
    ps := ps.set! i (updatePlayer ps[i]! dtNs)
  return ps

-- Physics smoke test: with no input a resting player only falls under gravity.
#guard
  let p := initPlayers[0]!
  let p' := updatePlayer { p with posY := 5.0 } 16000000  -- ~16ms
  p'.posY < 5.0 && p'.velY < 0.0

/-- Fire from player `shooter`: ray-sphere test every other player, respawning
those hit. Returns the updated players and the advanced RNG. C: `shoot`. -/
def shoot (shooter : Nat) (players : Array Player) (count : Nat) (rng0 : UInt64) :
    Array Player × UInt64 := Id.run do
  let sp := players[shooter]!
  let x0 := sp.posX
  let y0 := sp.posY
  let z0 := sp.posZ
  let binRad := Examples.pi / 2147483648.0
  let yawRad := binRad * sp.yaw.toFloat
  let pitchRad := binRad * sp.pitch.toFloat
  let cosYaw := Float.cos yawRad
  let sinYaw := Float.sin yawRad
  let cosPitch := Float.cos pitchRad
  let sinPitch := Float.sin pitchRad
  let vx := -sinYaw * cosPitch
  let vy := sinPitch
  let vz := -cosYaw * cosPitch
  let mut players := players
  let mut rng := rng0
  for i in [0:count] do
    if i == shooter then continue
    let target := players[i]!
    let mut hit := 0
    for j in [0:2] do
      let r := target.radius
      let h := target.height
      let dx := target.posX - x0
      let dy := target.posY - y0 + (if j == 0 then 0.0 else r - h)
      let dz := target.posZ - z0
      let vd := vx * dx + vy * dy + vz * dz
      let dd := dx * dx + dy * dy + dz * dz
      let vv := vx * vx + vy * vy + vz * vz
      let rr := r * r
      if vd < 0.0 then continue
      if vd * vd >= vv * (dd - rr) then hit := hit + 1
    if hit != 0 then
      let (v0, r0) := randMod rng 256
      let (v1, r1) := randMod r0 256
      let (v2, r2) := randMod r1 256
      rng := r2
      let coord (v : UInt64) : Float := ((mapBoxScale : Nat).toFloat * (v.toFloat - 128.0)) / 256.0
      players := players.set! i { target with posX := coord v0, posY := coord v1, posZ := coord v2 }
  return (players, rng)

/-! ## Drawing -/

/-- The `circleDrawSidesLen` points of a circle of radius `r` centered at
`(x, y)`, in render coordinates. C: `drawCircle`'s point loop. -/
def circlePoints (r x y : Float) : Array FPoint := Id.run do
  let mut pts := Array.emptyWithCapacity circleDrawSidesLen
  for i in [0:circleDrawSidesLen] do
    let ang := 2.0 * Examples.pi * (i : Nat).toFloat / (circleDrawSides : Nat).toFloat
    pts := pts.push {
      x := (x + r * Float.cos ang).toFloat32
      y := (y + r * Float.sin ang).toFloat32 }
  return pts

/-- Draw a circle as a connected line loop. C: `drawCircle`. -/
def drawCircle (ren : Renderer) (r x y : Float) : IO Unit :=
  ren.lines (circlePoints r x y)

/-- Draw a box edge with near-plane clipping then a perspective divide.
C: `drawClippedSegment`. -/
def drawClippedSegment (ren : Renderer)
    (ax ay az bx byy bz : Float) (x y z w : Float) : IO Unit := do
  -- Fully behind the near plane on both ends ⇒ nothing to draw.
  if az >= -w && bz >= -w then return
  let dx := ax - bx
  let dy := ay - byy
  let mut ax := ax; let mut ay := ay; let mut az := az
  let mut bx := bx; let mut byy := byy; let mut bz := bz
  if az > -w then
    let t := (-w - bz) / (az - bz)
    ax := bx + dx * t; ay := byy + dy * t; az := -w
  else if bz > -w then
    let t := (-w - az) / (bz - az)
    bx := ax - dx * t; byy := ay - dy * t; bz := -w
  ax := -z * ax / az
  ay := -z * ay / az
  bx := -z * bx / bz
  byy := -z * byy / bz
  ren.line (x + ax).toFloat32 (y - ay).toFloat32 (x + bx).toFloat32 (y - byy).toFloat32

/-- Render one player's split-screen cell. C: the body of `draw`'s player loop. -/
def drawPlayerView (ren : Renderer) (edges : Array Edge) (players : Array Player)
    (count i partHor : Nat) (sizeHor sizeVer : Float) : IO Unit := do
  let player := players[i]!
  let modX := (i % partHor).toFloat
  let modY := (i : Nat).toFloat / (partHor : Nat).toFloat  -- C: (float)i / part_hor (float division)
  let horOrigin := (modX + 0.5) * sizeHor
  let verOrigin := (modY + 0.5) * sizeVer
  let camOrigin := 0.5 * Float.sqrt (sizeHor * sizeHor + sizeVer * sizeVer)
  let horOffset := modX * sizeHor
  let verOffset := modY * sizeVer
  ren.setClipRect (some {
    x := horOffset.toInt32, y := verOffset.toInt32
    w := sizeHor.toInt32, h := sizeVer.toInt32 })
  let x0 := player.posX
  let y0 := player.posY
  let z0 := player.posZ
  let binRad := Examples.pi / 2147483648.0
  let yawRad := binRad * player.yaw.toFloat
  let pitchRad := binRad * player.pitch.toFloat
  let cosYaw := Float.cos yawRad
  let sinYaw := Float.sin yawRad
  let cosPitch := Float.cos pitchRad
  let sinPitch := Float.sin pitchRad
  -- Camera rotation matrix (C: `mat[9]`), row-major.
  let m0 := cosYaw;             let m1 := (0.0 : Float);  let m2 := -sinYaw
  let m3 := sinYaw * sinPitch;  let m4 := cosPitch;       let m5 := cosYaw * sinPitch
  let m6 := sinYaw * cosPitch;  let m7 := -sinPitch;      let m8 := cosYaw * cosPitch
  -- The 44 box/grid edges, in edge gray.
  ren.setDrawColor 64 64 64 255
  for e in edges do
    let ax := m0 * (e.ax - x0) + m1 * (e.ay - y0) + m2 * (e.az - z0)
    let ay := m3 * (e.ax - x0) + m4 * (e.ay - y0) + m5 * (e.az - z0)
    let az := m6 * (e.ax - x0) + m7 * (e.ay - y0) + m8 * (e.az - z0)
    let bx := m0 * (e.bx - x0) + m1 * (e.«by» - y0) + m2 * (e.bz - z0)
    let byy := m3 * (e.bx - x0) + m4 * (e.«by» - y0) + m5 * (e.bz - z0)
    let bz := m6 * (e.bx - x0) + m7 * (e.«by» - y0) + m8 * (e.bz - z0)
    drawClippedSegment ren ax ay az bx byy bz horOrigin verOrigin camOrigin 1.0
  -- Other players as two stacked circles, in that player's color.
  for j in [0:count] do
    if j != i then
      let target := players[j]!
      ren.setDrawColor target.colorR target.colorG target.colorB 255
      for k in [0:2] do
        let rx := target.posX - player.posX
        let ry := target.posY - player.posY + (target.radius - target.height) * (k : Nat).toFloat
        let rz := target.posZ - player.posZ
        let dx := m0 * rx + m1 * ry + m2 * rz
        let dy := m3 * rx + m4 * ry + m5 * rz
        let dz := m6 * rx + m7 * ry + m8 * rz
        let rEff := target.radius * camOrigin / dz
        if dz < 0.0 then
          drawCircle ren rEff (horOrigin - camOrigin * dx / dz) (verOrigin + camOrigin * dy / dz)
  -- White crosshair at the cell center.
  ren.setDrawColor 255 255 255 255
  ren.line horOrigin.toFloat32 (verOrigin - 10.0).toFloat32 horOrigin.toFloat32 (verOrigin + 10.0).toFloat32
  ren.line (horOrigin - 10.0).toFloat32 verOrigin.toFloat32 (horOrigin + 10.0).toFloat32 verOrigin.toFloat32

/-- Render the whole frame. C: `draw`. -/
def draw (ren : Renderer) (edges : Array Edge) (players : Array Player)
    (count : Nat) (debugStr : String) : IO Unit := do
  let (w, h) ← ren.getOutputSize
  ren.setDrawColor 0 0 0 255
  ren.clear
  if count > 0 then
    let wf := w.toFloat
    let hf := h.toFloat
    let partHor := if count > 2 then 2 else 1
    let partVer := if count > 1 then 2 else 1
    let sizeHor := wf / (partHor : Nat).toFloat
    let sizeVer := hf / (partVer : Nat).toFloat
    for i in [0:count] do
      drawPlayerView ren edges players count i partHor sizeHor sizeVer
  ren.setClipRect none
  ren.setDrawColor 255 255 255 255
  ren.debugText 0 0 debugStr
  ren.present

/-! ## App wiring -/

structure GameState where
  window : Window
  renderer : Renderer
  edges : Array Edge
  players : IO.Ref (Array Player)
  playerCount : IO.Ref Nat
  rng : IO.Ref UInt64
  /-- Timestamp of the previous frame (C: `past`). -/
  past : IO.Ref UInt64
  /-- Timestamp of the last fps-window reset (C: `last`). -/
  last : IO.Ref UInt64
  /-- Frames accumulated in the current fps window (C: `accu`). -/
  accu : IO.Ref UInt64
  /-- The fps debug string drawn each frame (C: `debug_string`). -/
  debugStr : IO.Ref String

/-- C: `SDL_EVENT_MOUSE_REMOVED`. -/
def handleMouseRemoved (s : GameState) (which : MouseId) : IO Unit := do
  let count ← s.playerCount.get
  s.players.modify fun ps => Id.run do
    let mut ps := ps
    for i in [0:count] do
      if ps[i]!.mouse == some which then
        ps := ps.set! i { ps[i]! with mouse := none }
    return ps

/-- C: `SDL_EVENT_KEYBOARD_REMOVED`. -/
def handleKeyboardRemoved (s : GameState) (which : KeyboardId) : IO Unit := do
  let count ← s.playerCount.get
  s.players.modify fun ps => Id.run do
    let mut ps := ps
    for i in [0:count] do
      if ps[i]!.keyboard == some which then
        ps := ps.set! i { ps[i]! with keyboard := none }
    return ps

/-- C: `SDL_EVENT_MOUSE_MOTION`. -/
def handleMouseMotion (s : GameState) (ev : MouseMotionEvent) : IO Unit := do
  let count ← s.playerCount.get
  let players ← s.players.get
  match whoseMouse ev.which players count with
  | some idx =>
    let p := players[idx]!
    -- yaw -= (int)xrel * 0x00080000 (unsigned wraparound).
    let xrelInt := ev.xrel.toInt32
    let newYaw := p.yaw - (xrelInt.toUInt32 * 0x00080000)
    -- pitch = clamp(pitch - (int)yrel * 0x00080000) to ±0x40000000 (Int64 math).
    let yrelInt := ev.yrel.toInt32
    let pitch64 := p.pitch.toInt64 - (yrelInt.toInt64 * 0x00080000)
    let clamped := max (-0x40000000 : Int64) (min (0x40000000 : Int64) pitch64)
    s.players.set (players.set! idx { p with yaw := newYaw, pitch := clamped.toInt32 })
  | none =>
    if ev.which.val != 0 then
      let mut ps := players
      let mut cnt := count
      for i in [0:maxPlayerCount] do
        if ps[i]!.mouse.isNone then
          ps := ps.set! i { ps[i]! with mouse := some ev.which }
          cnt := max cnt (i + 1)
          break
      s.players.set ps
      s.playerCount.set cnt

/-- C: `SDL_EVENT_MOUSE_BUTTON_DOWN`. -/
def handleMouseButtonDown (s : GameState) (ev : MouseButtonEvent) : IO Unit := do
  let count ← s.playerCount.get
  let players ← s.players.get
  match whoseMouse ev.which players count with
  | some idx =>
    let (ps, rng') := shoot idx players count (← s.rng.get)
    s.players.set ps
    s.rng.set rng'
  | none => pure ()

/-- The `wasd` bit for a movement key, or `0` for any other key. C: the
`SDLK_W|A|S|D|SPACE` cascade in the key-down handler. -/
def wasdBit (key : Keycode) : UInt8 :=
  if key == Keycode.w then 1
  else if key == Keycode.a then 2
  else if key == Keycode.s then 4
  else if key == Keycode.d then 8
  else if key == Keycode.space then 16
  else 0

/-- C: `SDL_EVENT_KEY_DOWN`. -/
def handleKeyDown (s : GameState) (ev : KeyboardEvent) : IO Unit := do
  let count ← s.playerCount.get
  let players ← s.players.get
  match whoseKeyboard ev.which players count with
  | some idx =>
    let p := players[idx]!
    s.players.set (players.set! idx { p with wasd := p.wasd ||| wasdBit ev.key })
  | none =>
    if ev.which.val != 0 then
      let mut ps := players
      let mut cnt := count
      for i in [0:maxPlayerCount] do
        if ps[i]!.keyboard.isNone then
          ps := ps.set! i { ps[i]! with keyboard := some ev.which }
          cnt := max cnt (i + 1)
          break
      s.players.set ps
      s.playerCount.set cnt

/-- C: `SDL_EVENT_KEY_UP` (escape quits; owners clear their `wasd` bits). The C
masks 30/29/27/23/15 clear bits 0..4 respectively; a non-movement key uses the
identity mask `0xFF`. -/
def handleKeyUp (s : GameState) (ev : KeyboardEvent) : IO AppResult := do
  if ev.key == Keycode.escape then return .success
  let count ← s.playerCount.get
  let players ← s.players.get
  match whoseKeyboard ev.which players count with
  | some idx =>
    let mask : UInt8 :=
      if ev.key == Keycode.w then 30
      else if ev.key == Keycode.a then 29
      else if ev.key == Keycode.s then 27
      else if ev.key == Keycode.d then 23
      else if ev.key == Keycode.space then 15
      else 0xFF
    let p := players[idx]!
    s.players.set (players.set! idx { p with wasd := p.wasd &&& mask })
    return .continue
  | none => return .continue

def app : App GameState where
  init _ := do
    setAppMetadata "Example splitscreen shooter game" "1.0" "com.example.woodeneye-008"
    -- C: the `extended_metadata[]` table (SDL_PROP_APP_METADATA_* strings).
    setAppMetadataProperty "SDL.app.metadata.url"
      "https://examples.libsdl.org/SDL3/demo/02-woodeneye-008/"
    setAppMetadataProperty "SDL.app.metadata.creator" "SDL team"
    setAppMetadataProperty "SDL.app.metadata.copyright" "Placed in the public domain"
    setAppMetadataProperty "SDL.app.metadata.type" "game"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/demo/woodeneye-008" 640 480 .resizable
    -- Keep vsync off; the loop paces itself with an explicit delay.
    renderer.setVSync Renderer.vsyncDisabled
    window.setRelativeMouseMode true
    -- SKIP: SDL_HINT_WINDOWS_RAW_KEYBOARD (Windows-only; no effect here).
    let players ← IO.mkRef initPlayers
    let playerCount ← IO.mkRef 1
    let rng ← IO.mkRef ((← getTicksNS) ||| 1)  -- seed nonzero for xorshift64
    let past ← IO.mkRef 0
    let last ← IO.mkRef 0
    let accu ← IO.mkRef 0
    let debugStr ← IO.mkRef ""
    return (.continue, some
      { window, renderer, edges := initEdges, players, playerCount, rng, past, last, accu, debugStr })
  event s e := do
    match e with
    | .quit _ => return .success
    | .mouseRemoved ev => handleMouseRemoved s ev.which; return .continue
    | .keyboardRemoved ev => handleKeyboardRemoved s ev.which; return .continue
    | .mouseMotion ev => handleMouseMotion s ev; return .continue
    | .mouseButtonDown ev => handleMouseButtonDown s ev; return .continue
    | .keyDown ev => handleKeyDown s ev; return .continue
    | .keyUp ev => handleKeyUp s ev
    | _ => return .continue
  iterate s := do
    let now ← getTicksNS
    let dtNs := now - (← s.past.get)
    let count ← s.playerCount.get
    s.players.modify (updateAll · count dtNs)
    draw s.renderer s.edges (← s.players.get) count (← s.debugStr.get)
    if now - (← s.last.get) > 999999999 then
      s.last.set now
      s.debugStr.set s!"{← s.accu.get} fps"
      s.accu.set 0
    s.past.set now
    s.accu.modify (· + 1)
    let elapsed := (← getTicksNS) - now
    if elapsed < 999999 then
      delayNS (999999 - elapsed)
    return .continue

def main : IO UInt32 := Examples.runApp app
