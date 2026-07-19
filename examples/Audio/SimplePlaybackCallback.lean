import Common

/-!
# audio/02-simple-playback-callback

Creates a simple audio stream for playing sound, and generates a sine wave
sound effect for it to play as time goes on. Unlike the previous example, this
uses a callback to generate sound (the path of least resistance when moving an
SDL2 program's audio code to SDL3).

Port of the official example
`examples/audio/02-simple-playback-callback/simple-playback-callback.c`
(https://examples.libsdl.org/SDL3/audio/02-simple-playback-callback/).

## Deviations
- **Callback at open**: the C passes `FeedTheAudioStreamMore` to
  `SDL_OpenAudioDeviceStream`. The Lean binding opens the stream without a
  callback, so we install it with `AudioStream.setGetCallback` after opening
  and before `resumeDevice` — equivalent, since the device starts paused.
- Inside the callback we feed the borrowed `astream` handle passed in, never
  the captured stream: capturing the owning handle in its own callback is a
  reference cycle Lean's refcounting never collects. The phase counter is a
  captured `IO.Ref` (a plain value, safe to capture).
- No `Sdl.quit`; the C's `SDL_AppQuit` is empty. Finalizers release the audio
  stream/device at process exit.
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer
  stream : AudioStream
  -- Sine-wave phase counter, shared across callback invocations
  -- (C: `current_sine_sample`).
  currentSineSample : IO.Ref Int32

/-- The stream *get* callback (usually run on a background audio thread): SDL
wants `additional` more bytes than it currently has queued. Generate a 440Hz
tone into `astream` (the borrowed handle) in chunks of 128 samples until we've
supplied enough. C: `FeedTheAudioStreamMore`. -/
def feedTheAudioStreamMore (sampleRef : IO.Ref Int32)
    (astream : AudioStream) (additional : Int32) (_total : Int32) : IO Unit := do
  -- convert from bytes to samples
  let mut remaining := additional / 4
  while remaining > 0 do
    -- this will feed 128 samples each iteration until we have enough.
    let total := if remaining < 128 then remaining else 128
    let mut sample ← sampleRef.get
    let mut samples := FloatArray.emptyWithCapacity total.toNatClampNeg
    -- generate a 440Hz pure tone
    for _ in [0:total.toNatClampNeg] do
      let phase := (sample * 440).toFloat / 8000.0
      samples := samples.push (Float.sin (phase * 2 * Examples.pi))
      sample := sample + 1
    -- wrapping around to avoid floating-point errors
    sampleRef.set (sample % 8000)
    astream.putDataF32 samples
    -- subtract what we've just fed the stream.
    remaining := remaining - total

def app : App State where
  init _ := do
    setAppMetadata "Example Simple Audio Playback Callback" "1.0"
      "com.example.audio-simple-playback-callback"
    Sdl.init (.video ||| .audio)
    -- we don't _need_ a window for audio-only things but it's good policy to have one.
    let (window, renderer) ←
      createWindowAndRenderer "examples/audio/simple-playback-callback" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- Always feed audio in as mono, float32 data at 8000Hz; the stream converts
    -- it to whatever the hardware wants.
    let stream ← openAudioDeviceStream .defaultPlayback (some ⟨.f32, 1, 8000⟩)
    let currentSineSample ← IO.mkRef (0 : Int32)
    -- Install the get callback before resuming (see module Deviations).
    stream.setGetCallback (some (feedTheAudioStreamMore currentSineSample))
    -- SDL_OpenAudioDeviceStream starts the device paused. You have to start it!
    stream.resumeDevice
    return (.continue, some { window, renderer, stream, currentSineSample })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    -- all the work of feeding the audio stream happens in the callback.
    -- we're not doing anything with the renderer, so just blank it out.
    s.renderer.clear
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
