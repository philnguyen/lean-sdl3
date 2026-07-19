import Common

/-!
# audio/01-simple-playback

Creates a simple audio stream for playing sound, and generates a sine wave
sound effect for it to play as time goes on. This is the simplest way to get
up and running with procedural sound.

Port of the official example `examples/audio/01-simple-playback/simple-playback.c`
(https://examples.libsdl.org/SDL3/audio/01-simple-playback/).

## Deviations
- No `Sdl.quit`; the C's (empty) `SDL_AppQuit` only notes that SDL cleans up
  the window/renderer. The audio stream/device are released by Lean finalizers
  at process exit.
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer
  stream : AudioStream
  -- Per-frame mutable sine-wave phase counter (C: `current_sine_sample`).
  currentSineSample : IO.Ref Int32

/-- Generate a frame's worth (512 samples) of a 440Hz pure tone and feed it to
the stream, advancing the shared phase counter (wrapping at 8000 to avoid
floating-point drift). C: the body of `SDL_AppIterate`'s `if`. -/
def feedStream (stream : AudioStream) (sampleRef : IO.Ref Int32) : IO Unit := do
  let mut sample ← sampleRef.get
  let mut samples := FloatArray.emptyWithCapacity 512
  -- this will feed 512 samples each frame until we get to our maximum.
  for _ in [0:512] do
    -- generate a 440Hz pure tone
    let phase := (sample * 440).toFloat / 8000.0
    samples := samples.push (Float.sin (phase * 2 * Examples.pi))
    sample := sample + 1
  -- wrapping around to avoid floating-point errors
  sampleRef.set (sample % 8000)
  -- feed the new data to the stream. It will queue at the end, and trickle out
  -- as the hardware needs more data.
  stream.putDataF32 samples

def app : App State where
  init _ := do
    setAppMetadata "Example Audio Simple Playback" "1.0" "com.example.audio-simple-playback"
    Sdl.init (.video ||| .audio)
    -- we don't _need_ a window for audio-only things but it's good policy to have one.
    let (window, renderer) ←
      createWindowAndRenderer "examples/audio/simple-playback" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- We're just playing a single thing here, so we'll use the simplified option.
    -- We always feed audio in as mono, float32 data at 8000Hz; the stream converts
    -- it to whatever the hardware wants on the other side.
    let stream ← openAudioDeviceStream .defaultPlayback (some ⟨.f32, 1, 8000⟩)
    -- SDL_OpenAudioDeviceStream starts the device paused. You have to start it!
    stream.resumeDevice
    let currentSineSample ← IO.mkRef (0 : Int32)
    return (.continue, some { window, renderer, stream, currentSineSample })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    -- see if we need to feed the audio stream more data yet. We're being lazy:
    -- if there's less than half a second queued, generate more. 8000 float
    -- samples per second, half of that.
    let minimumAudio : Int32 := (8000 * 4) / 2
    if (← s.stream.queued) < minimumAudio then
      feedStream s.stream s.currentSineSample
    -- we're not doing anything with the renderer, so just blank it out.
    s.renderer.clear
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
