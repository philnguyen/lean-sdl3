import Common

/-!
# audio/03-load-wav

Creates a simple audio stream for playing sound, and loads a .wav file that is
pushed through the stream in a loop.

Port of the official example `examples/audio/03-load-wav/load-wav.c`
(https://examples.libsdl.org/SDL3/audio/03-load-wav/).

The .wav file is a sample from Will Provost's song, *The Living Proof*, used
with permission (from the album *The Living Proof*, publisher 5 Guys Named
Will, copyright 1996 Will Provost).

## Deviations
- **Asset path**: the C builds `SDL_GetBasePath() + "sample.wav"`. We resolve
  the vendored asset with `Examples.assetPath "sample.wav"`.
- No `Sdl.quit`; the C's `SDL_AppQuit` frees `wav_data`, but here the decoded
  `ByteArray` and the audio stream/device are released by Lean finalizers /
  process exit.
-/

open Sdl

structure State where
  window : Window
  renderer : Renderer
  stream : AudioStream
  -- The decoded WAV PCM; a whole copy is re-queued whenever the queue drains.
  wavData : ByteArray

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Audio Load Wave" "1.0" "com.example.audio-load-wav"
    Sdl.init (.video ||| .audio)
    -- we don't _need_ a window for audio-only things but it's good policy to have one.
    let (window, renderer) ←
      createWindowAndRenderer "examples/audio/load-wav" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- Load the .wav file.
    let (spec, wavData) ← loadWAV (← Examples.assetPath "sample.wav").toString
    -- Create our audio stream in the same format as the .wav file. It'll
    -- convert to what the audio hardware wants.
    let stream ← openAudioDeviceStream .defaultPlayback (some spec)
    -- SDL_OpenAudioDeviceStream starts the device paused. You have to start it!
    stream.resumeDevice
    return (.continue, some { window, renderer, stream, wavData })
  event := fun _ e => do
    if let .quit _ := e then return .success
    return .continue
  iterate := fun s => do
    -- if there's less than the entire wav file left to play, shove a whole copy
    -- of it into the queue, so we always have _tons_ of data queued for playback.
    if (← s.stream.queued).toNatClampNeg < s.wavData.size then
      s.stream.putData s.wavData
    -- we're not doing anything with the renderer, so just blank it out.
    s.renderer.clear
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
