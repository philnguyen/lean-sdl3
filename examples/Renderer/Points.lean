import Common

/-!
# renderer/04-points

Creates an SDL window and renderer, then draws some points to it every frame.

Port of the official example `examples/renderer/04-points/points.c`
(https://examples.libsdl.org/SDL3/renderer/04-points/).

## Deviations

* Randomness: point placement and speeds use `IO.rand` instead of
  `SDL_rand`/`SDL_randf` (SDL's stdinc RNG is unbound by design). Statistical
  quality is irrelevant here.
* `quit` is omitted: SDL cleans up the window/renderer at process exit (see
  `examples/Common.lean`).
-/

open Sdl

def windowWidth : Float32 := 640
def windowHeight : Float32 := 480

def numPoints : Nat := 500
/-- Move at least this many pixels per second. -/
def minPixelsPerSecond : Float32 := 30
/-- Move this many pixels per second at most. -/
def maxPixelsPerSecond : Float32 := 60

/-- A substitute for `SDL_randf`: a uniform-ish random `Float32` in `[0, 1)`. -/
def randf : IO Float32 := do
  return ((← IO.rand 0 999999).toFloat / 1000000.0).toFloat32

/-- A random per-point speed, in pixels per second. -/
def randSpeed : IO Float32 := do
  return minPixelsPerSecond + (← randf) * (maxPixelsPerSecond - minPixelsPerSecond)

/- (track the speeds in a parallel array instead of an array of structs,
   so we can pass the coordinates to the renderer in a single function call.) -/

structure State where
  window : Window
  renderer : Renderer
  /-- Points are plotted as a set of X and Y coordinates.
  (0, 0) is the top left of the window, and larger numbers go down
  and to the right. This isn't how geometry works, but this is pretty
  standard in 2D graphics. -/
  points : IO.Ref (Array FPoint)
  pointSpeeds : IO.Ref (Array Float32)
  lastTime : IO.Ref UInt64

def app : App State where
  init _ := do
    setAppMetadata "Example Renderer Points" "1.0" "com.example.renderer-points"
    Sdl.init .video
    let (window, renderer) ←
      createWindowAndRenderer "examples/renderer/points" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- set up the data for a bunch of points.
    let mut pts := Array.emptyWithCapacity numPoints
    let mut speeds := Array.emptyWithCapacity numPoints
    for _ in [0:numPoints] do
      pts := pts.push { x := (← randf) * windowWidth, y := (← randf) * windowHeight : FPoint }
      speeds := speeds.push (← randSpeed)
    let points ← IO.mkRef pts
    let pointSpeeds ← IO.mkRef speeds
    let lastTime ← IO.mkRef (← getTicks)
    return (.continue, some { window, renderer, points, pointSpeeds, lastTime })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    let now ← getTicks
    -- seconds since last iteration
    let elapsed := ((now - (← s.lastTime.get)).toFloat / 1000.0).toFloat32
    -- let's move all our points a little for a new frame.
    let mut pts ← s.points.get
    let mut speeds ← s.pointSpeeds.get
    for i in [0:pts.size] do
      let distance := elapsed * speeds[i]!
      let mut p := pts[i]!
      p := { p with x := p.x + distance, y := p.y + distance }
      if p.x >= windowWidth || p.y >= windowHeight then
        -- off the screen; restart it elsewhere!
        if (← IO.rand 0 1) == 1 then
          p := { x := (← randf) * windowWidth, y := 0.0 }
        else
          p := { x := 0.0, y := (← randf) * windowHeight }
        speeds := speeds.set! i (← randSpeed)
      pts := pts.set! i p
    s.points.set pts
    s.pointSpeeds.set speeds
    s.lastTime.set now
    -- as you can see from this, rendering draws over whatever was drawn before it.
    s.renderer.setDrawColor 0 0 0 255        -- black, full alpha
    s.renderer.clear                          -- start with a blank canvas.
    s.renderer.setDrawColor 255 255 255 255  -- white, full alpha
    s.renderer.points pts                     -- draw all the points!
    -- You can also draw single points with `Renderer.point`, but it's
    -- cheaper (sometimes significantly so) to do them all at once.
    s.renderer.present                        -- put it all on the screen!
    return .continue

def main : IO UInt32 := Examples.runApp app
