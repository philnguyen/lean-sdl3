import Sdl
import Tests.Harness

namespace Tests.Audio
open Sdl Tests.Harness

/-! Little-endian byte packers for the hand-built WAV header. -/

private def u16le (v : UInt16) : ByteArray :=
  ⟨#[v.toUInt8, (v >>> 8).toUInt8]⟩

private def u32le (v : UInt32) : ByteArray :=
  ⟨#[v.toUInt8, (v >>> 8).toUInt8, (v >>> 16).toUInt8, (v >>> 24).toUInt8]⟩

/-- Float32 equality within a tolerance (audio gains/ratios round-trip through
32-bit floats; never compare with `==`). -/
private def approx (a b : Float32) (eps : Float := 0.001) : Bool :=
  (a.toFloat - b.toFloat).abs < eps

/-- Stream get/put callback bridges and the postmix lifecycle (split out of
`run`: one giant `do` block exceeds the elaborator's recursion depth). -/
def callbacks : IO Unit := do
  -- 14. stream get callback: fires synchronously inside getData on an unbound
  -- stream; the passed-in borrowed handle feeds data and dies with the call
  let s7 ← createAudioStream (some ⟨.f32le, 1, 8000⟩) (some ⟨.f32le, 1, 8000⟩)
  let getFired ← IO.mkRef 0
  let escaped ← IO.mkRef (none : Option AudioStream)
  s7.setGetCallback (some fun astream additional _total => do
    getFired.modify (· + 1)
    escaped.set (some astream)
    -- feed at least the additional amount, in whole f32 samples
    let n := (additional.toNatClampNeg + 3) / 4
    astream.putDataF32 ⟨Array.replicate n 0.25⟩)
  let cbOut ← s7.getData 64
  check "get callback fired inside getData" ((← getFired.get) > 0)
  check "get callback supplied the data" (cbOut.size == 64)
  match ← escaped.get with
  | some stored => checkThrows "escaped callback handle throws" stored.queued
  | none => check "callback handle was captured" false
  -- removal: no further firing
  s7.setGetCallback none
  getFired.set 0
  let _ ← s7.getData 16
  check "removed get callback does not fire" ((← getFired.get) == 0)

  -- 15. put callback fires synchronously inside putData; callback exceptions
  -- are swallowed
  let putFired ← IO.mkRef 0
  s7.setPutCallback (some fun _ _ _ => putFired.modify (· + 1))
  s7.putData ⟨Array.replicate 8 0⟩
  check "put callback fired inside putData" ((← putFired.get) == 1)
  s7.setPutCallback (some fun _ _ _ => throw (IO.userError "boom"))
  s7.putData ⟨Array.replicate 8 0⟩
  check "put callback exception swallowed" true
  s7.setPutCallback none
  -- destroy with a live get callback: unhooks first, closure released later
  s7.setGetCallback (some fun _ _ _ => pure ())
  s7.destroy
  checkThrows "setGetCallback after destroy throws" (s7.setGetCallback none)

  -- 16. postmix callback: register, replace, remove, and close-with-registered
  -- (on the dummy device the callback may or may not fire; only lifecycle is
  -- asserted here)
  let dev3 ← openAudioDevice .defaultPlayback
  let passthrough : AudioSpec → FloatArray → IO FloatArray := fun _spec samples => pure samples
  dev3.setPostmixCallback (some passthrough)
  dev3.setPostmixCallback (some passthrough)
  dev3.setPostmixCallback none
  check "postmix register/replace/remove ok" true
  dev3.setPostmixCallback (some passthrough)
  dev3.close
  check "close with postmix registered ok" true


/-- Audio tests (run under `SDL_AUDIO_DRIVER=dummy`). Initializes the audio
subsystem, then exercises drivers, device open/format/gain/pause, stream
round-trips and conversion math, WAV loading, mixing, silence values,
bind/unbind, the simplified device-stream path, frequency ratio, channel maps,
and the stream/postmix callback bridges. Does not `Sdl.quit` afterwards. -/
def run : IO Unit := do
  Sdl.init .audio

  -- 1/2. drivers
  check "getCurrentAudioDriver == some dummy" ((← getCurrentAudioDriver) == some "dummy")
  check "audioDrivers contains dummy" ((← audioDrivers).contains "dummy")

  -- 3. default playback device: name, format, playback flag, pause/resume, gain
  let dev ← openAudioDevice .defaultPlayback
  check "device name nonempty" (!(← dev.name).isEmpty)
  let (spec, _frames) ← dev.getFormat
  check "device format channels > 0" (spec.channels > 0)
  check "device format freq > 0" (spec.freq > 0)
  check "device isPlayback" (← dev.isPlayback)
  dev.resume
  check "device not paused after resume" (!(← dev.paused))
  dev.pause
  check "device paused after pause" (← dev.paused)
  dev.setGain 0.5
  check "device gain ~ 0.5" (approx (← dev.getGain) 0.5)
  dev.close

  -- 4. stream round-trip, f32le mono 8000 both sides
  let s ← createAudioStream (some ⟨.f32le, 1, 8000⟩) (some ⟨.f32le, 1, 8000⟩)
  let samples : FloatArray := ⟨Array.replicate 512 0.5⟩
  s.putDataF32 samples
  check "stream available == 2048" ((← s.available) == 2048)
  check "stream queued == 2048" ((← s.queued) == 2048)
  let out ← s.getData 2048
  check "getData returns 2048 bytes" (out.size == 2048)
  check "available == 0 after drain" ((← s.available) == 0)
  let bits := (0.5 : Float).toFloat32.toBits
  check "first output sample = f32 bits of 0.5"
    ((out.extract 0 4).toList == (u32le bits).toList)

  -- 5. conversion math: u8 mono -> s16le stereo (4x bytes) after flush
  let s2 ← createAudioStream (some ⟨.u8, 1, 4000⟩) (some ⟨.s16le, 2, 4000⟩)
  s2.putData ⟨Array.replicate 16 0x80⟩
  s2.flush
  check "converted available == 4*N" ((← s2.available) == 64)

  -- 6. convertAudioSamples: u8 mono -> s16le stereo, size 4x
  let input : ByteArray := ⟨Array.replicate 10 0x80⟩
  let converted ← convertAudioSamples ⟨.u8, 1, 8000⟩ input ⟨.s16le, 2, 8000⟩
  check "convertAudioSamples size == 4x input" (converted.size == 4 * input.size)

  -- 7. WAV: hand-built 48-byte u8 mono 8000 PCM, via loadWAVIO and loadWAV
  let wav :=
    "RIFF".toUTF8 ++ u32le 40 ++ "WAVE".toUTF8
      ++ "fmt ".toUTF8 ++ u32le 16 ++ u16le 1 ++ u16le 1
      ++ u32le 8000 ++ u32le 8000 ++ u16le 1 ++ u16le 8
      ++ "data".toUTF8 ++ u32le 4 ++ (⟨#[0x80, 0xFF, 0x00, 0x80]⟩ : ByteArray)
  let io ← ioFromConstMem wav
  let (wspec, wdata) ← loadWAVIO io
  check "loadWAVIO spec == u8/1/8000" (wspec == ⟨.u8, 1, 8000⟩)
  check "loadWAVIO data" (wdata.toList == [0x80, 0xFF, 0x00, 0x80])
  io.close
  let pref ← Sdl.getPrefPath "lean-sdl3" "test-audio"
  let path := pref ++ "probe.wav"
  IO.FS.writeBinFile path wav
  let (fspec, fdata) ← loadWAV path
  check "loadWAV spec == u8/1/8000" (fspec == ⟨.u8, 1, 8000⟩)
  check "loadWAV data" (fdata.toList == [0x80, 0xFF, 0x00, 0x80])
  Sdl.removePath path

  -- 8. mixAudio (u8, volume 1.0): mixing around the 0x80 silence value
  let mixed ← mixAudio (⟨#[0x80, 0x80]⟩ : ByteArray) (⟨#[0x80, 0x90]⟩ : ByteArray) .u8 1.0
  check "mixAudio u8 == [0x80, 0x90]" (mixed.toList == [0x80, 0x90])

  -- 9. silence values and format name
  check "silence u8 == 0x80" ((← getSilenceValueForFormat .u8) == 0x80)
  check "silence s16le == 0" ((← getSilenceValueForFormat .s16le) == 0)
  check "format name f32le nonempty" (!(← getAudioFormatName .f32le).isEmpty)

  -- 10. bind / unbind
  let dev2 ← openAudioDevice .defaultPlayback
  let s3 ← createAudioStream (some ⟨.f32le, 1, 8000⟩) (some ⟨.f32le, 1, 8000⟩)
  dev2.bindStream s3
  check "bound stream getDevice == some dev" ((← s3.getDevice) == some dev2)
  s3.unbind
  check "unbound stream getDevice == none" ((← s3.getDevice) == none)
  dev2.close

  -- 11. openAudioDeviceStream: paused device, resume, put/queued, destroy
  let s4 ← openAudioDeviceStream .defaultPlayback (some ⟨.f32le, 1, 8000⟩)
  check "device-stream paused initially" (← s4.devicePaused)
  s4.putData (⟨Array.replicate 8 0⟩ : ByteArray)
  check "device-stream queued > 0 while paused" ((← s4.queued) > 0)
  s4.resumeDevice
  check "device-stream not paused after resume" (!(← s4.devicePaused))
  s4.destroy
  checkThrows "use after destroy throws" s4.queued

  -- 12. frequency ratio
  let s5 ← createAudioStream (some ⟨.f32le, 1, 8000⟩) (some ⟨.f32le, 1, 8000⟩)
  s5.setFrequencyRatio 2.0
  check "frequency ratio ~ 2.0" (approx (← s5.getFrequencyRatio) 2.0)

  -- 13. channel maps on a fresh 2-channel stream
  let s6 ← createAudioStream (some ⟨.s16le, 2, 8000⟩) (some ⟨.s16le, 2, 8000⟩)
  check "input channel map none by default" ((← s6.getInputChannelMap) == none)
  s6.setInputChannelMap (some #[1, 0])
  check "input channel map round-trip" ((← s6.getInputChannelMap) == some #[1, 0])
  s6.setInputChannelMap none
  check "setInputChannelMap none accepted" true

  -- 14-16. stream and postmix callback bridges
  callbacks

end Tests.Audio
