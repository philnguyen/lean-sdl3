import Sdl.Core.Macros
import Sdl.Error
import Sdl.Properties
import Sdl.IOStream

/-!
# Audio playback, recording, and conversion (`SDL_audio.h`)

All audio in SDL3 flows through an `AudioStream`. An app opens an
`AudioDeviceID` (a *logical* device), binds streams to it, and feeds/consumes
data through those streams. `AudioStream` is also a standalone format converter
and queue.

## Ownership

* `AudioStream` is an **owned root**: the finalizer runs `SDL_DestroyAudioStream`
  (and releases any per-stream callback closures). `AudioStream.destroy` is a
  *manual* destroy that NULLs the handle, so later use is a clean IO error.
  Destroying a stream returned by `openAudioDeviceStream` also closes the audio
  device that was opened alongside it (SDL semantics).
* An `AudioDeviceID` is a plain numeric id (not a handle): close it with
  `AudioDeviceID.close` when you opened it with `openAudioDevice`.

The stream's external holder carries the two per-stream callback closures
(`AudioStream.setGetCallback`/`setPutCallback`, locked-slot primitive):
replaced under the stream lock, released by the finalizer after
`SDL_DestroyAudioStream` (see `docs/DESIGN.md` §"Callbacks", primitive 2).
The device postmix callback (`AudioDeviceID.setPostmixCallback`) uses the
gen-key registry (primitive 1) keyed by device id and is dropped on `close`.

## Skipped (documented plan-level omissions)

* `SDL_OpenAudioDeviceStream`'s callback argument — open the stream, then
  `AudioStream.setGetCallback` (playback) / `setPutCallback` (recording)
  before resuming: the device starts paused, so this is equivalent.
* `SDL_PutAudioStreamDataNoCopy` — the no-copy handoff plus completion callback
  has no safe Lean shape (a Lean `ByteArray` is copy-on-write and could move);
  `putData` copies, and SDL buffers internally anyway.
-/

namespace Sdl

/-! ## Audio formats -/

/-- Audio sample format. The low byte is the bit size; bits 8/12/15 flag
float/big-endian/signed. C: `SDL_AudioFormat`. -/
sdl_enum_open AudioFormat : UInt32 where
  | unknown => 0x0000  -- C: SDL_AUDIO_UNKNOWN
  | u8      => 0x0008  -- C: SDL_AUDIO_U8
  | s8      => 0x8008  -- C: SDL_AUDIO_S8
  | s16le   => 0x8010  -- C: SDL_AUDIO_S16LE
  | s16be   => 0x9010  -- C: SDL_AUDIO_S16BE
  | s32le   => 0x8020  -- C: SDL_AUDIO_S32LE
  | s32be   => 0x9020  -- C: SDL_AUDIO_S32BE
  | f32le   => 0x8120  -- C: SDL_AUDIO_F32LE
  | f32be   => 0x9120  -- C: SDL_AUDIO_F32BE

/-- Native-endian signed 16-bit samples (little-endian on all supported
targets). C: `SDL_AUDIO_S16`. -/
def AudioFormat.s16 : AudioFormat := .s16le
/-- Native-endian signed 32-bit samples (little-endian on all supported
targets). C: `SDL_AUDIO_S32`. -/
def AudioFormat.s32 : AudioFormat := .s32le
/-- Native-endian 32-bit float samples (little-endian on all supported
targets). C: `SDL_AUDIO_F32`. -/
def AudioFormat.f32 : AudioFormat := .f32le

namespace AudioFormat

/-- Sample size in bits (e.g. `16` for `s16le`). C: `SDL_AUDIO_BITSIZE`. -/
def bitsize (f : AudioFormat) : UInt32 := f.val &&& 0xFF
/-- Sample size in bytes (e.g. `2` for `s16le`). C: `SDL_AUDIO_BYTESIZE`. -/
def bytesize (f : AudioFormat) : UInt32 := f.bitsize / 8
/-- Whether the format holds floating-point samples. C: `SDL_AUDIO_ISFLOAT`. -/
def isFloat (f : AudioFormat) : Bool := f.val &&& 0x100 != 0
/-- Whether the format is big-endian. C: `SDL_AUDIO_ISBIGENDIAN`. -/
def isBigEndian (f : AudioFormat) : Bool := f.val &&& 0x1000 != 0
/-- Whether the format is little-endian. C: `SDL_AUDIO_ISLITTLEENDIAN`. -/
def isLittleEndian (f : AudioFormat) : Bool := !f.isBigEndian
/-- Whether the format holds signed samples. C: `SDL_AUDIO_ISSIGNED`. -/
def isSigned (f : AudioFormat) : Bool := f.val &&& 0x8000 != 0
/-- Whether the format holds integer (non-float) samples. C: `SDL_AUDIO_ISINT`. -/
def isInt (f : AudioFormat) : Bool := !f.isFloat
/-- Whether the format holds unsigned samples. C: `SDL_AUDIO_ISUNSIGNED`. -/
def isUnsigned (f : AudioFormat) : Bool := !f.isSigned

#guard AudioFormat.u8.bitsize == 8
#guard AudioFormat.s16le.bitsize == 16
#guard AudioFormat.f32le.bitsize == 32
#guard (AudioFormat.other 0x9010).bitsize == 16
#guard AudioFormat.u8.bytesize == 1
#guard AudioFormat.s16le.bytesize == 2
#guard AudioFormat.s32le.bytesize == 4
#guard AudioFormat.f32le.bytesize == 4
#guard AudioFormat.f32le.isFloat == true
#guard AudioFormat.f32be.isFloat == true
#guard AudioFormat.s16le.isFloat == false
#guard (AudioFormat.other 0x8120).isFloat == true
#guard AudioFormat.s16be.isBigEndian == true
#guard AudioFormat.s16le.isBigEndian == false
#guard AudioFormat.s16le.isLittleEndian == true
#guard AudioFormat.s16be.isLittleEndian == false
#guard AudioFormat.s8.isSigned == true
#guard AudioFormat.s16le.isSigned == true
#guard AudioFormat.u8.isSigned == false
#guard AudioFormat.s16le.isInt == true
#guard AudioFormat.f32le.isInt == false
#guard AudioFormat.u8.isUnsigned == true
#guard AudioFormat.s16le.isUnsigned == false

end AudioFormat

/-! ## Audio device ids -/

/-- The instance id of a logical or physical audio device. Zero is never a
valid id. C: `SDL_AudioDeviceID`. -/
sdl_id AudioDeviceID : UInt32 where
  /-- Request a default playback device. C: `SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK`. -/
  | defaultPlayback := 0xFFFFFFFF
  /-- Request a default recording device. C: `SDL_AUDIO_DEVICE_DEFAULT_RECORDING`. -/
  | defaultRecording := 0xFFFFFFFE

/-! ## Audio specs -/

/-- Format specification for audio data. C: `SDL_AudioSpec`. -/
structure AudioSpec where
  /-- Sample format. -/
  format   : AudioFormat
  /-- Number of channels (1 mono, 2 stereo, …). -/
  channels : Int32
  /-- Sample rate (sample frames per second). -/
  freq     : Int32
  deriving Repr, BEq, Inhabited

/-- Size in bytes of a single sample frame (`bytesize × channels`). Channels is
non-negative in practice, so the `Int32 → UInt32` conversion is value-preserving.
C: `SDL_AUDIO_FRAMESIZE`. -/
def AudioSpec.frameSize (s : AudioSpec) : UInt32 :=
  s.format.bytesize * s.channels.toUInt32

#guard (AudioSpec.mk .u8 1 8000).frameSize == 1
#guard (AudioSpec.mk .s16le 2 44100).frameSize == 4
#guard (AudioSpec.mk .f32le 2 48000).frameSize == 8
#guard (AudioSpec.mk .s32le 1 8000).frameSize == 4

/-- Maker called from C to hand an `AudioSpec` back to Lean (flattened scalars;
the raw format value is decoded with the total `AudioFormat.ofVal`). -/
@[export lean_sdl_mk_audio_spec]
private def mkAudioSpec (format : UInt32) (channels freq : Int32) : AudioSpec :=
  ⟨.ofVal format, channels, freq⟩

/-- Flatten an `Option AudioSpec` to the `(present, format, channels, freq)`
shape the raw externs take (zeros when absent). -/
private def optSpecArgs : Option AudioSpec → Bool × UInt32 × Int32 × Int32
  | some s => (true, s.format.val, s.channels, s.freq)
  | none   => (false, 0, 0, 0)

/-! ## Audio streams -/

/-- An audio conversion/queue interface, and the core of the SDL3 audio API.
C: `SDL_AudioStream`. -/
sdl_opaque AudioStream

@[extern "lean_sdl_audio_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-! ## Drivers -/

/-- The number of audio drivers compiled into SDL.
C: `SDL_GetNumAudioDrivers`. -/
@[extern "lean_sdl_get_num_audio_drivers"]
opaque getNumAudioDrivers : IO Int32

/-- The name of the built-in audio driver at `index` (a simple low-ASCII id like
`"coreaudio"`/`"alsa"`), or `none` if `index` is out of range.
C: `SDL_GetAudioDriver`. -/
@[extern "lean_sdl_get_audio_driver"]
opaque getAudioDriver (index : Int32) : IO (Option String)

/-- The names of all built-in audio drivers, in initialization-check order.
Convenience loop over `getNumAudioDrivers` / `getAudioDriver`. -/
def audioDrivers : IO (Array String) := do
  let n ← getNumAudioDrivers
  let mut drivers := #[]
  for i in [0:n.toNatClampNeg] do
    if let some name ← getAudioDriver (Int32.ofNat i) then
      drivers := drivers.push name
  return drivers

/-- The name of the currently initialized audio driver, or `none` if the audio
subsystem is not initialized. C: `SDL_GetCurrentAudioDriver`. -/
@[extern "lean_sdl_get_current_audio_driver"]
opaque getCurrentAudioDriver : IO (Option String)

/-! ## Device enumeration -/

@[extern "lean_sdl_get_audio_playback_devices"]
private opaque getAudioPlaybackDevicesRaw : IO (Array UInt32)

/-- The currently-connected physical audio playback devices. Throws on failure.
C: `SDL_GetAudioPlaybackDevices`. -/
def getAudioPlaybackDevices : IO (Array AudioDeviceID) := do
  return (← getAudioPlaybackDevicesRaw).map (⟨·⟩)

@[extern "lean_sdl_get_audio_recording_devices"]
private opaque getAudioRecordingDevicesRaw : IO (Array UInt32)

/-- The currently-connected physical audio recording devices. Throws on failure.
C: `SDL_GetAudioRecordingDevices`. -/
def getAudioRecordingDevices : IO (Array AudioDeviceID) := do
  return (← getAudioRecordingDevicesRaw).map (⟨·⟩)

/-! ## Opening devices and streams -/

@[extern "lean_sdl_open_audio_device"]
private opaque openAudioDeviceRaw (devid : UInt32)
  (hasSpec : Bool) (format : UInt32) (channels freq : Int32) : IO UInt32

/-- Open a logical audio device on top of the physical device `devid` (or
`.defaultPlayback`/`.defaultRecording`). `spec` is only a hint; streams convert
as needed. Close the returned device with `AudioDeviceID.close`. Throws on
failure. C: `SDL_OpenAudioDevice`. -/
def openAudioDevice (devid : AudioDeviceID) (spec : Option AudioSpec := none) :
    IO AudioDeviceID := do
  let (hs, f, c, fr) := optSpecArgs spec
  return ⟨← openAudioDeviceRaw devid.val hs f c fr⟩

@[extern "lean_sdl_create_audio_stream"]
private opaque createAudioStreamRaw
  (hasSrc : Bool) (srcFormat : UInt32) (srcChannels srcFreq : Int32)
  (hasDst : Bool) (dstFormat : UInt32) (dstChannels dstFreq : Int32) : IO AudioStream

/-- Create a new audio stream converting `srcSpec` (input) to `dstSpec`
(output); either may be `none` and set later with `AudioStream.setFormat` or by
binding to a device. Throws on failure. C: `SDL_CreateAudioStream`. -/
def createAudioStream (srcSpec dstSpec : Option AudioSpec) : IO AudioStream :=
  let (hs, sf, sc, sfr) := optSpecArgs srcSpec
  let (hd, df, dc, dfr) := optSpecArgs dstSpec
  createAudioStreamRaw hs sf sc sfr hd df dc dfr

@[extern "lean_sdl_open_audio_device_stream"]
private opaque openAudioDeviceStreamRaw (devid : UInt32)
  (hasSpec : Bool) (format : UInt32) (channels freq : Int32) : IO AudioStream

/-- Convenience: open `devid`, create a stream in `spec` (the app's side of the
data), and bind them, returning just the stream. The device begins **paused** —
call `AudioStream.resumeDevice` to start it. Destroying the returned stream also
closes the device. Throws on failure. C: `SDL_OpenAudioDeviceStream` (with a
`NULL` callback; see the module note on stream callbacks). -/
def openAudioDeviceStream (devid : AudioDeviceID) (spec : Option AudioSpec := none) :
    IO AudioStream :=
  let (hs, f, c, fr) := optSpecArgs spec
  openAudioDeviceStreamRaw devid.val hs f c fr

/-! ## WAV loading -/

/-- Load a WAVE file from `path`, returning its format spec and the decoded PCM
data. Throws on failure. C: `SDL_LoadWAV`. -/
@[extern "lean_sdl_load_wav"]
opaque loadWAV (path : @& String) : IO (AudioSpec × ByteArray)

/-- Load a WAVE file from an open `IOStream`, returning its format spec and the
decoded PCM data. Always leaves the stream open (`closeio = false`); Lean owns
its lifetime. Throws on failure. C: `SDL_LoadWAV_IO`. -/
@[extern "lean_sdl_load_wav_io"]
opaque loadWAVIO (src : @& IOStream) : IO (AudioSpec × ByteArray)

/-! ## Mixing and conversion -/

@[extern "lean_sdl_mix_audio"]
private opaque mixAudioRaw (dst src : @& ByteArray) (format : UInt32)
  (volume : Float32) : IO ByteArray

/-- Mix `src` into a copy of `dst` (both interpreted as `format` samples) at
`volume` (`0.0`–`1.0`), with saturating addition. Returns a fresh `ByteArray`
that copies `dst` and has `min dst.size src.size` bytes of `src` mixed into its
start. Throws on failure. C: `SDL_MixAudio`. -/
def mixAudio (dst src : @& ByteArray) (format : AudioFormat) (volume : Float32) :
    IO ByteArray :=
  mixAudioRaw dst src format.val volume

@[extern "lean_sdl_convert_audio_samples"]
private opaque convertAudioSamplesRaw
  (srcFormat : UInt32) (srcChannels srcFreq : Int32) (src : @& ByteArray)
  (dstFormat : UInt32) (dstChannels dstFreq : Int32) : IO ByteArray

/-- Convert `src` (in `srcSpec`) entirely to `dstSpec` in one call, returning the
converted data. Not for block-by-block resampling — use an `AudioStream` for
that. Throws on failure. C: `SDL_ConvertAudioSamples`. -/
def convertAudioSamples (srcSpec : AudioSpec) (src : @& ByteArray)
    (dstSpec : AudioSpec) : IO ByteArray :=
  convertAudioSamplesRaw srcSpec.format.val srcSpec.channels srcSpec.freq src
    dstSpec.format.val dstSpec.channels dstSpec.freq

/-! ## Format helpers -/

@[extern "lean_sdl_get_audio_format_name"]
private opaque getAudioFormatNameRaw (format : UInt32) : IO String

/-- The human-readable name of an audio format (e.g. `"SDL_AUDIO_F32LE"`), or
`"SDL_AUDIO_UNKNOWN"` if unrecognized. C: `SDL_GetAudioFormatName`. -/
def getAudioFormatName (format : AudioFormat) : IO String :=
  getAudioFormatNameRaw format.val

@[extern "lean_sdl_get_silence_value_for_format"]
private opaque getSilenceValueForFormatRaw (format : UInt32) : IO UInt8

/-- The byte value that fills a buffer of `format` with silence (e.g. `0x80` for
`u8`, `0` for signed/float formats). C: `SDL_GetSilenceValueForFormat`. -/
def getSilenceValueForFormat (format : AudioFormat) : IO UInt8 :=
  getSilenceValueForFormatRaw format.val

/-! ## Stream (un)binding -/

/-- Unbind each stream in `streams` from its device (a legal no-op for an
unbound stream). Throws if any element was already destroyed.
C: `SDL_UnbindAudioStreams`. -/
@[extern "lean_sdl_unbind_audio_streams"]
opaque unbindAudioStreams (streams : @& Array AudioStream) : IO Unit

namespace AudioDeviceID

@[extern "lean_sdl_get_audio_device_name"]
private opaque nameRaw (devid : UInt32) : IO String

/-- The human-readable name of the device. Throws on failure.
C: `SDL_GetAudioDeviceName`. -/
def name (self : AudioDeviceID) : IO String := nameRaw self.val

@[extern "lean_sdl_get_audio_device_format"]
private opaque getFormatRaw (devid : UInt32) : IO (AudioSpec × Int32)

/-- The device's current audio format together with its buffer size, in sample
frames (the amount fed to the hardware per chunk). Throws on failure.
C: `SDL_GetAudioDeviceFormat`. -/
def getFormat (self : AudioDeviceID) : IO (AudioSpec × Int32) := getFormatRaw self.val

@[extern "lean_sdl_get_audio_device_channel_map"]
private opaque getChannelMapRaw (devid : UInt32) : IO (Option (Array Int32))

/-- The device's channel map, or `none` for the default channel order (which is
not an error). C: `SDL_GetAudioDeviceChannelMap`. -/
def getChannelMap (self : AudioDeviceID) : IO (Option (Array Int32)) :=
  getChannelMapRaw self.val

@[extern "lean_sdl_is_audio_device_physical"]
private opaque isPhysicalRaw (devid : UInt32) : IO Bool

/-- Whether the device id is a physical device (vs a logical one from
`openAudioDevice`). C: `SDL_IsAudioDevicePhysical`. -/
def isPhysical (self : AudioDeviceID) : IO Bool := isPhysicalRaw self.val

@[extern "lean_sdl_is_audio_device_playback"]
private opaque isPlaybackRaw (devid : UInt32) : IO Bool

/-- Whether the device is a playback device (vs a recording device).
C: `SDL_IsAudioDevicePlayback`. -/
def isPlayback (self : AudioDeviceID) : IO Bool := isPlaybackRaw self.val

@[extern "lean_sdl_pause_audio_device"]
private opaque pauseRaw (devid : UInt32) : IO Unit

/-- Pause audio processing on the (logical) device. Throws on failure.
C: `SDL_PauseAudioDevice`. -/
def pause (self : AudioDeviceID) : IO Unit := pauseRaw self.val

@[extern "lean_sdl_resume_audio_device"]
private opaque resumeRaw (devid : UInt32) : IO Unit

/-- Resume audio processing on the (logical) device. Throws on failure.
C: `SDL_ResumeAudioDevice`. -/
def resume (self : AudioDeviceID) : IO Unit := resumeRaw self.val

@[extern "lean_sdl_audio_device_paused"]
private opaque pausedRaw (devid : UInt32) : IO Bool

/-- Whether the device is valid and paused (physical/invalid ids report
`false`). C: `SDL_AudioDevicePaused`. -/
def paused (self : AudioDeviceID) : IO Bool := pausedRaw self.val

@[extern "lean_sdl_get_audio_device_gain"]
private opaque getGainRaw (devid : UInt32) : IO Float32

/-- The device gain (volume; `1.0` is unchanged). Throws on failure (physical
devices always fail here, returning the `-1.0` sentinel).
C: `SDL_GetAudioDeviceGain`. -/
def getGain (self : AudioDeviceID) : IO Float32 := getGainRaw self.val

@[extern "lean_sdl_set_audio_device_gain"]
private opaque setGainRaw (devid : UInt32) (gain : Float32) : IO Unit

/-- Set the device gain (`1.0` is unchanged, `0.0` is silence). Only logical
devices can change gain. Throws on failure. C: `SDL_SetAudioDeviceGain`. -/
def setGain (self : AudioDeviceID) (gain : Float32) : IO Unit := setGainRaw self.val gain

@[extern "lean_sdl_close_audio_device"]
private opaque closeRaw (devid : UInt32) : IO Unit

/-- Close a logical device previously opened with `openAudioDevice`. Only close
ids you opened. C: `SDL_CloseAudioDevice`. -/
def close (self : AudioDeviceID) : IO Unit := closeRaw self.val

@[extern "lean_sdl_bind_audio_stream"]
private opaque bindStreamRaw (devid : UInt32) (stream : @& AudioStream) : IO Unit

/-- Bind `stream` to the device so data flows through it. Throws on failure
(e.g. the stream is already bound). C: `SDL_BindAudioStream`. -/
def bindStream (self : AudioDeviceID) (stream : @& AudioStream) : IO Unit :=
  bindStreamRaw self.val stream

@[extern "lean_sdl_bind_audio_streams"]
private opaque bindStreamsRaw (devid : UInt32) (streams : @& Array AudioStream) : IO Unit

/-- Bind every stream in `streams` to the device atomically. Throws on failure
or if any element was already destroyed. C: `SDL_BindAudioStreams`. -/
def bindStreams (self : AudioDeviceID) (streams : @& Array AudioStream) : IO Unit :=
  bindStreamsRaw self.val streams

@[extern "lean_sdl_set_audio_postmix_callback"]
private opaque setPostmixCallbackRaw (devid : UInt32)
  (cb : Option (AudioSpec → FloatArray → IO FloatArray)) : IO Unit

/-- Install (`some`) or remove (`none`) a callback that runs on the device
thread after all bound streams are mixed, just before the buffer reaches the
hardware: it receives the device format and the mixed samples (32-bit floats
widened to `Float`) and returns the samples to play instead (narrowed back;
only the first `min` input-length elements are written). The callback stays
registered until replaced, removed, or the device is closed. An exception
thrown by the callback leaves the buffer as SDL mixed it.
C: `SDL_SetAudioPostmixCallback`. -/
def setPostmixCallback (self : AudioDeviceID)
    (cb : Option (AudioSpec → FloatArray → IO FloatArray)) : IO Unit :=
  setPostmixCallbackRaw self.val cb

end AudioDeviceID

namespace AudioStream

/-- Destroy the stream now (SDL guarantees no callback runs after this returns).
The handle is invalid afterwards, so later use is a clean IO error. If the
stream came from `openAudioDeviceStream`, its device is closed too.
C: `SDL_DestroyAudioStream`. -/
@[extern "lean_sdl_destroy_audio_stream"]
opaque destroy (self : @& AudioStream) : IO Unit

/-- The properties associated with the stream. Borrowed: tied to the stream's
lifetime, never destroyed from Lean. Throws on failure.
C: `SDL_GetAudioStreamProperties`. -/
@[extern "lean_sdl_get_audio_stream_properties"]
opaque getProperties (self : @& AudioStream) : IO Properties

/-- The stream's current `(src, dst)` formats. Throws on failure.
C: `SDL_GetAudioStreamFormat`. -/
@[extern "lean_sdl_get_audio_stream_format"]
opaque getFormat (self : @& AudioStream) : IO (AudioSpec × AudioSpec)

@[extern "lean_sdl_set_audio_stream_format"]
private opaque setFormatRaw (self : @& AudioStream)
  (hasSrc : Bool) (srcFormat : UInt32) (srcChannels srcFreq : Int32)
  (hasDst : Bool) (dstFormat : UInt32) (dstChannels dstFreq : Int32) : IO Unit

/-- Change the stream's input and/or output format (`none` leaves that side
unchanged). The device-bound side of a bound stream cannot change (silently
ignored). Throws on failure. C: `SDL_SetAudioStreamFormat`. -/
def setFormat (self : @& AudioStream) (srcSpec dstSpec : Option AudioSpec) : IO Unit :=
  let (hs, sf, sc, sfr) := optSpecArgs srcSpec
  let (hd, df, dc, dfr) := optSpecArgs dstSpec
  setFormatRaw self hs sf sc sfr hd df dc dfr

/-- The stream's frequency ratio (playback speed/pitch multiplier). Throws on
failure (`0.0` is the error sentinel). C: `SDL_GetAudioStreamFrequencyRatio`. -/
@[extern "lean_sdl_get_audio_stream_frequency_ratio"]
opaque getFrequencyRatio (self : @& AudioStream) : IO Float32

/-- Set the stream's frequency ratio (`1.0` is normal; must be between `0.01`
and `100`). Throws on failure. C: `SDL_SetAudioStreamFrequencyRatio`. -/
@[extern "lean_sdl_set_audio_stream_frequency_ratio"]
opaque setFrequencyRatio (self : @& AudioStream) (ratio : Float32) : IO Unit

/-- The stream gain (volume; `1.0` is unchanged). Throws on failure (`-1.0` is
the error sentinel). C: `SDL_GetAudioStreamGain`. -/
@[extern "lean_sdl_get_audio_stream_gain"]
opaque getGain (self : @& AudioStream) : IO Float32

/-- Set the stream gain (`1.0` is unchanged, `0.0` is silence). Throws on
failure. C: `SDL_SetAudioStreamGain`. -/
@[extern "lean_sdl_set_audio_stream_gain"]
opaque setGain (self : @& AudioStream) (gain : Float32) : IO Unit

/-- The stream's input channel map, or `none` for the default order (not an
error). C: `SDL_GetAudioStreamInputChannelMap`. -/
@[extern "lean_sdl_get_audio_stream_input_channel_map"]
opaque getInputChannelMap (self : @& AudioStream) : IO (Option (Array Int32))

/-- The stream's output channel map, or `none` for the default order (not an
error). C: `SDL_GetAudioStreamOutputChannelMap`. -/
@[extern "lean_sdl_get_audio_stream_output_channel_map"]
opaque getOutputChannelMap (self : @& AudioStream) : IO (Option (Array Int32))

/-- Set the stream's input channel map (`none` resets to default). Its length
must equal the input channel count. Throws on failure.
C: `SDL_SetAudioStreamInputChannelMap`. -/
@[extern "lean_sdl_set_audio_stream_input_channel_map"]
opaque setInputChannelMap (self : @& AudioStream) (chmap : @& Option (Array Int32)) : IO Unit

/-- Set the stream's output channel map (`none` resets to default). Its length
must equal the output channel count. Throws on failure.
C: `SDL_SetAudioStreamOutputChannelMap`. -/
@[extern "lean_sdl_set_audio_stream_output_channel_map"]
opaque setOutputChannelMap (self : @& AudioStream) (chmap : @& Option (Array Int32)) : IO Unit

/-- Queue `data` into the stream (interpreted as the stream's current input
format). Throws on failure. C: `SDL_PutAudioStreamData`. -/
@[extern "lean_sdl_put_audio_stream_data"]
opaque putData (self : @& AudioStream) (data : @& ByteArray) : IO Unit

/-- Queue `samples` into the stream as 32-bit float (`f32le`) data: each Lean
64-bit `Float` is narrowed to a `Float32`. The stream's input format must be
`f32le`. Throws on failure. C: `SDL_PutAudioStreamData` (after a float32
conversion). -/
@[extern "lean_sdl_put_audio_stream_data_f32"]
opaque putDataF32 (self : @& AudioStream) (samples : @& FloatArray) : IO Unit

/-- Queue planar (per-channel) audio: `channels` holds one buffer per channel in
interleave order, a `none` entry meaning a silent channel. `numSamples` is the
number of samples *per channel* (sample frames). Throws on failure.
C: `SDL_PutAudioStreamPlanarData`. -/
@[extern "lean_sdl_put_audio_stream_planar_data"]
opaque putPlanarData (self : @& AudioStream) (channels : @& Array (Option ByteArray))
  (numSamples : Int32) : IO Unit

/-- Read up to `maxBytes` bytes of converted/resampled output (fewer if less is
available). Throws if `maxBytes < 0` or on an SDL error.
C: `SDL_GetAudioStreamData`. -/
@[extern "lean_sdl_get_audio_stream_data"]
opaque getData (self : @& AudioStream) (maxBytes : Int32) : IO ByteArray

/-- The number of converted output bytes available right now (may be less than
queued while the stream buffers for resampling). Throws on failure (`-1`
sentinel). C: `SDL_GetAudioStreamAvailable`. -/
@[extern "lean_sdl_get_audio_stream_available"]
opaque available (self : @& AudioStream) : IO Int32

/-- The number of input bytes currently queued (not the retrievable output
count — use `available` for that). Throws on failure (`-1` sentinel).
C: `SDL_GetAudioStreamQueued`. -/
@[extern "lean_sdl_get_audio_stream_queued"]
opaque queued (self : @& AudioStream) : IO Int32

/-- Signal end-of-input so all buffered data is converted and made available.
Throws on failure. C: `SDL_FlushAudioStream`. -/
@[extern "lean_sdl_flush_audio_stream"]
opaque flush (self : @& AudioStream) : IO Unit

/-- Drop all queued data from the stream. Throws on failure.
C: `SDL_ClearAudioStream`. -/
@[extern "lean_sdl_clear_audio_stream"]
opaque clear (self : @& AudioStream) : IO Unit

/-- Pause the audio device the stream is bound to. Throws on failure.
C: `SDL_PauseAudioStreamDevice`. -/
@[extern "lean_sdl_pause_audio_stream_device"]
opaque pauseDevice (self : @& AudioStream) : IO Unit

/-- Resume the audio device the stream is bound to (required after
`openAudioDeviceStream`, which starts paused). Throws on failure.
C: `SDL_ResumeAudioStreamDevice`. -/
@[extern "lean_sdl_resume_audio_stream_device"]
opaque resumeDevice (self : @& AudioStream) : IO Unit

/-- Whether the device the stream is bound to is valid and paused.
C: `SDL_AudioStreamDevicePaused`. -/
@[extern "lean_sdl_audio_stream_device_paused"]
opaque devicePaused (self : @& AudioStream) : IO Bool

/-- Lock the stream's internal mutex for serialized access; pair with `unlock`.
SDL holds this lock during stream callbacks, so locking guards state those
callbacks share. Throws on failure. C: `SDL_LockAudioStream`. -/
@[extern "lean_sdl_lock_audio_stream"]
opaque lock (self : @& AudioStream) : IO Unit

/-- Unlock the stream locked by `lock` (call from the same thread). Throws on
failure. C: `SDL_UnlockAudioStream`. -/
@[extern "lean_sdl_unlock_audio_stream"]
opaque unlock (self : @& AudioStream) : IO Unit

/-- Unbind the stream from its device (a legal no-op if unbound).
C: `SDL_UnbindAudioStream`. -/
@[extern "lean_sdl_unbind_audio_stream"]
opaque unbind (self : @& AudioStream) : IO Unit

@[extern "lean_sdl_get_audio_stream_device"]
private opaque getDeviceRaw (self : @& AudioStream) : IO UInt32

/-- The device the stream is currently bound to, or `none` if unbound/invalid.
C: `SDL_GetAudioStreamDevice`. -/
def getDevice (self : @& AudioStream) : IO (Option AudioDeviceID) := do
  let id ← getDeviceRaw self
  return if id == 0 then none else some ⟨id⟩

/-! ### Stream callbacks

Both callbacks receive `(stream, additional, total)`: the stream, how many
more bytes SDL wants beyond what is queued (get) or how many bytes were just
added (put), and the total bytes in play for this request. The `AudioStream`
handle passed in is a borrowed view that is **invalidated when the callback
returns** — storing it and using it later throws (never dangles). Do not
capture the owning handle inside its own callback: closure → stream → closure
is a reference cycle Lean's reference counting never collects (break it with
`destroy` if you must). Exceptions thrown by a callback are swallowed. -/

/-- Install (`some`), replace, or remove (`none`) the stream's *get* callback,
invoked whenever data is read from the stream — synchronously inside
`getData`, and from the audio-device thread while bound to a playback device.
Feeding exactly `additional` bytes (e.g. via `putDataF32` on the passed-in
handle) keeps latency minimal; feeding less makes SDL play what it has.
C: `SDL_SetAudioStreamGetCallback`. -/
@[extern "lean_sdl_set_audio_stream_get_callback"]
opaque setGetCallback (self : @& AudioStream)
  (cb : Option (AudioStream → Int32 → Int32 → IO Unit)) : IO Unit

/-- Install (`some`), replace, or remove (`none`) the stream's *put* callback,
invoked whenever data is added to the stream — synchronously inside
`putData`/`putDataF32`/`putPlanarData`, and from the device thread while bound
to a recording device (the natural place to `getData` freshly recorded audio).
C: `SDL_SetAudioStreamPutCallback`. -/
@[extern "lean_sdl_set_audio_stream_put_callback"]
opaque setPutCallback (self : @& AudioStream)
  (cb : Option (AudioStream → Int32 → Int32 → IO Unit)) : IO Unit

end AudioStream
end Sdl
