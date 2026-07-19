import Common

/-!
# audio/04-multiple-streams

Loads two .wav files, puts them in audio streams and binds them for playback,
repeating both sounds on loop. This shows several streams mixing into a single
playback device.

Port of the official example `examples/audio/04-multiple-streams/multiple-streams.c`
(https://examples.libsdl.org/SDL3/audio/04-multiple-streams/).

## Deviations
- **Asset paths**: the C builds `SDL_GetBasePath() + fname`. We resolve the
  vendored assets with `Examples.assetPath`.
- No `Sdl.quit`; the C's `SDL_AppQuit` closes the device, destroys the streams
  and frees the wav data. Here the audio device, streams and decoded
  `ByteArray`s are released by Lean finalizers / process exit.
-/

open Sdl

/-- A thing that plays sound: the audio stream plus the original PCM, so we can
refill to loop. C: `struct Sound`. -/
structure Sound where
  data : ByteArray
  stream : AudioStream

/-- Load `fname`, wrap it in an audio stream (source format = the wav's format,
dest format left unset until bound), and bind that stream to `device`.
C: `init_sound`. -/
def initSound (device : AudioDeviceId) (fname : String) : IO Sound := do
  let (spec, data) ← loadWAV (← Examples.assetPath fname).toString
  -- Create an audio stream. Set the source format to the wav's format; leave
  -- the dest format unset here (it changes to what the device wants once bound).
  let stream ← createAudioStream (some spec) none
  -- once bound, it'll start playing when there is data available!
  device.bindStream stream
  return { data, stream }

structure State where
  window : Window
  renderer : Renderer
  device : AudioDeviceId
  sounds : Array Sound

def app : App State where
  init _ := do
    setAppMetadata "Example Audio Multiple Streams" "1.0" "com.example.audio-multiple-streams"
    Sdl.init (.video ||| .audio)
    let (window, renderer) ←
      createWindowAndRenderer "examples/audio/multiple-streams" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    -- open the default audio device in whatever format it prefers; our audio
    -- streams will adjust to it.
    let device ← openAudioDevice .defaultPlayback
    let sound0 ← initSound device "sample.wav"
    let sound1 ← initSound device "sword.wav"
    return (.continue, some { window, renderer, device, sounds := #[sound0, sound1] })
  event _ e := do
    if let .quit _ := e then return .success
    return .continue
  iterate s := do
    for sound in s.sounds do
      -- If less than a full copy of the audio is queued for playback, put
      -- another copy in there. Overkill, but easy when lots of RAM is cheap.
      if (← sound.stream.queued).toNatClampNeg < sound.data.size then
        sound.stream.putData sound.data
    -- just blank the screen.
    s.renderer.setDrawColor 0 0 0 255
    s.renderer.clear
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
