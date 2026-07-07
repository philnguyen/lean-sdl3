import Common

/-!
# audio/05-planar-data

Draws two clickable buttons. Each causes a sound to play, fed to either the
left or right audio channel through separate ("planar") arrays.

Port of the official example `examples/audio/05-planar-data/planar-data.c`
(https://examples.libsdl.org/SDL3/audio/05-planar-data/).

## Deviations
- **Embedded PCM** (C: `static const Uint8 left[1870]` / `right[1777]`): the
  raw byte arrays are embedded as hex-string constants (`leftHex` / `rightHex`)
  and decoded once at `init` with `hexToBytes`. `init` sanity-checks that the
  decoded sizes are 1870 and 1777, failing otherwise.
- **`SDL_ConvertEventToRenderCoordinates`** (unbound; decoded Lean events are
  immutable copies): the mouse handler maps the event's window coordinates
  through `Renderer.coordinatesFromWindow` instead.
- **Debug-text sizing**: `SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE` becomes the
  top-level constant `Sdl.debugTextFontCharacterSize`.
- No `Sdl.quit`; the C's `SDL_AppQuit` destroys the stream. Here the audio
  stream/device are released by Lean finalizers / process exit.
-/

open Sdl

-- location of buttons on the screen.
def rectLeftButton : FRect := ⟨100, 170, 100, 100⟩
def rectRightButton : FRect := ⟨440, 170, 100, 100⟩

/-- Value of a single hex digit (`0` for non-hex input). -/
def hexDigit (c : Char) : Nat :=
  if '0' ≤ c && c ≤ '9' then c.toNat - '0'.toNat
  else if 'a' ≤ c && c ≤ 'f' then c.toNat - 'a'.toNat + 10
  else if 'A' ≤ c && c ≤ 'F' then c.toNat - 'A'.toNat + 10
  else 0

/-- Decode a hex string (two chars per byte) into a `ByteArray`. -/
def hexToBytes (s : String) : ByteArray := Id.run do
  let cs := s.toList.toArray
  let mut out := ByteArray.emptyWithCapacity (cs.size / 2)
  for i in [0:cs.size / 2] do
    let hi := hexDigit (cs[2*i]!)
    let lo := hexDigit (cs[2*i+1]!)
    out := out.push (16 * hi + lo).toUInt8
  return out

/-- Raw audio data (Uint8, 1 channel, 4000Hz), left channel: 1870 bytes. -/
def leftHex : String :=
  "7f7f7f7f7f7f7f7f7f8080818081828283838383838282818080807f7e7e7e7d" ++
  "7b7b7b7b7c7d7d7e80818283848585848483817f7d7c7a7a7a77777776767677" ++
  "787d82898e929595918b847d777372727475757576747373747981898f969b9c" ++
  "9891887e77747374777b7c7a77736d69686a737f878e99a19e9790867c76777b" ++
  "80899193918e877c716b65605d5f60616b7b848da0aeaea8a19481736f70747e" ++
  "8d95979892837269615a56595d5f6575828795aab4b0aaa08d776c6c6d728191" ++
  "989a9a8f7a6a61584f50575b6174858a96abb4aea59c887167696c7385969da1" ++
  "a3967f6e63564c4d5253586b808692aab8b4aca59075696a6c7386989ca2a799" ++
  "7f6e61544c4b4d4f54667c8590a9bcbab4ac95786967677186999da4ab9b7f6e" ++
  "5f504b4e4e4e546077868ea4bbbfb9b39e7d6865636b849a9da3b09f83715f4d" ++
  "4c515151565a647d9099adc3c2b5aa927162656a7892a2a1a7a8917866554a50" ++
  "545050585a658b9b9bb7c9b3a6a27d5a666f7094a2909ba58f82775c58605046" ++
  "56493a5497bea9b0ad91a7b3836f6c5b71919cac98788aa6ad9e724d4e4f4e4a" ++
  "4846424e99d5aeb0b18ab3bd826b53568b97a7af746b92afc18f55474e605e45" ++
  "4a4f3a449fdfaca89379bfc39267365a909bb6a16b688dc3ca834f3d53726346" ++
  "44554f4c78cbbb939979add09f70374f909eaf94737189c0c08f5b4562796f5b" ++
  "465654535990d8958c8c88d6b8834c2f80a2aa9c697480b0c699785469807c69" ++
  "4b4e574e4c5faec3828683acd9a36a3150a0ada66d597f9ec8af8174708b8376" ++
  "585056595849627cce99719c8dd4b16c4f3795ab9b7f4b82a2bab57b7d7d8d8b" ++
  "7162545b4e5d4c5e579cd4679483a2d883702e59b59da1515597adcb86777895" ++
  "a1766d58675b4f6655674e67d98889866fcd9b894e399fa0a97a478899beac6b" ++
  "8887af9a6771637462555c5e655c54b1b0798d6facb78e73447ba199905a7097" ++
  "a0b489838e96a37e6f6c6a6b5b5a615e5d6366a0a67c8d83a4ad887b58759591" ++
  "927075939cab92848d919681706b6c6862595e695a5a685fa2b06d877ea0ba89" ++
  "785373a69b956c658e9aab977b858e9a91716b68656e585d705d6d675e807894" ++
  "987c9690a1a5827f707e9487878088928e968c898473726f716d5e616a70776f" ++
  "6d79767f77757e90a88c85989ba7937978799194878685868b89827c746d6c75" ++
  "756f6469747e837675858a898878818883857e8088898c8d8a8b888889858181" ++
  "7e7c7c777d766f7d7f7873768384807f828680818381817e7d7b838b857a7683" ++
  "87827d767b8083817a797d8281828283868080817e807d7a7e817e7e807f8182" ++
  "8081827f7f7d7c7f7b7b7d7a7a7e7e7c7c7f807f80828181807e807f817b7c7f" ++
  "7f817f7f80807f807f7f837e7f8581838480848181838183808480808580817f" ++
  "8282818180818087817c807f807d7c7d808080827d81827e8281818180808082" ++
  "7f807f7f817f807e81807e807e7f8080827f838380807f7f7f7e7e7f80808080" ++
  "8081807f7f7f7e7f7e7d7e7d7c7d7c7c7d7c7d7e7f7e7e7f7d7f7f807f7e7f80" ++
  "7e807e7e807e807e7f7e7d7f7d7d7d7d7d7d7e7f7f7d7e7f7e807f7f807f8080" ++
  "807f807f7f7f7f818080807f7f7f807f7f80807f80807f7f8081818181818180" ++
  "81808283818281828282818183828282818382818180807e7e7e7f7f7e807d80" ++
  "817e7f7f807f7f8080808181808181807f7f7f807f7f7f7e7f81807f81818281" ++
  "80828280818180807e7d7f7e81817e7f827f7d7f7d817f7f807f807f807f7f80" ++
  "7f7e7f7f7e7c7d7e7d7d7e7d7e7c7e7e7c7e7d7e7e7e7d7d7c7b7c7b7b7b7b7b" ++
  "7b7c7c7d7c7d7d7d7d7d7c7d7d7d7d7d7d7d7d7d7e7d7e7e7e7e7e7e7e7f7f7f" ++
  "7f7f808081818181818181818181818181818080808080808080808081818181" ++
  "8181818182828282818181808080808181818080818181818181818282828282" ++
  "81828282828282828181808080808080808080808080808080808080807f7f7f" ++
  "7f7f7f7f7f7f8080808080808080808080807f7f7e7e7e7e7e7e7e7e7e7e7e7e" ++
  "7e7e7e7e7e7e7f7f7f7f7f7e7e7e7e7f7f7f7f7e7e7e7e7e7e7f7f807f807f7f" ++
  "7f7f7f7f7f7f807f81808380808084847b7e80807e807e7f8181807f807f7e7e" ++
  "7f80807f81828080818180817f80808181818184837f7f80807f817e7e7f817f" ++
  "7f807f8080808080807f818282807f807f7f7e7e7e7e7f7e7f7f7f7d7e7e7f80" ++
  "80808081808080808081818080817f8080808080807f807f7e7e7f7f7e7e7e7f" ++
  "7e7d7d7e7e7e7e7e7e7e7f7e807e7f7f7e7f7e807f807f7f7f7f807f7f7e7f7f" ++
  "7f7f7f7f7f7f807f7f7f81807f80808281808080807f7f7f7f8181808180827f" ++
  "7f7e7e807e807f7f7f7f807f807f818081808081808380807f7f807f807e807f" ++
  "7f807f8280817f7e807f807f7f7f7f807f7f7f807f7f807f8180808080808080" ++
  "808080807f7f808180808081817f7f7f7f7e7e7f7f8080807f80817f807e7f7f" ++
  "7e807e7f7f7f7f7e7e7d7f7e7f7f7f807f80807f807f8081818180807f7f807f" ++
  "7f7f81817f807f807f7f7f7f80807f7f7f80807f80808180807f7e7f7e7e7e7e" ++
  "7f7f7f7f7f807f80807f807e7f7e"

/-- Raw audio data (Uint8, 1 channel, 4000Hz), right channel: 1777 bytes. -/
def rightHex : String :=
  "7f7e7e7f8080807f8081828382838383828181807f7e7c7b7a7a7979797a7a7b" ++
  "7c7e808284868889898988878482807e7c7b7a7a7978777576777878787b8187" ++
  "8c8e9092918d87817d7b7a79797a79787574757575767676767b83888b8f9598" ++
  "958d8683807e7c7c7e7e7c79787675727374726f6d727e878b90989f9b91857f" ++
  "7b78797f878b8a8989868179757473736f6d6e6e6e6f7277828f95999c9e998c" ++
  "7f747170747e8a92918f8f8d857c76757675716d6b686464666e838f939ba3a4" ++
  "9786766f6d6e78879498969491897e746f7074726e6b6762606069849195a1ae" ++
  "b09b84746a6567788b989f9e9a90867c716a6c73746d69655e5c606f8b959bac" ++
  "b3a5897a6b5c5f708897a5aca1958e86766a6b72726c675e555256789c919cbc" ++
  "b898837f5e4c6c838a9ab7ae8a8f93796976766970705b5051575277b29095c8" ++
  "b18d898a554e877f82b3b98f8c9d7971806a617b705163623e50619aad7ebab5" ++
  "949f93754b7b796cabaf9f938e7a7f896a6e71665e635c5353505ab8bd6dc3b2" ++
  "8aa7a1704c88637db1a1a68e6a7c958b84725c5c6764615665524480da8a88c9" ++
  "8996b1924a6f6d78a5a7a098666ea69d957052577369725a5552503db8db5da9" ++
  "ab82adc3654c6c6d98ac9f97745aa0b19e7e525474716a6a5a534b465ee5aa62" ++
  "ab8f97cba54b4f6788a6a498846180b7b498644e6477727255544e523c96f069" ++
  "7fa280c1c875464d74a49e958a6a73a6b7b481605e717c746b5454484f44c3cb" ++
  "5b9b8699d4a3713e4b91999d95707285b0bda57e676778776e63535b395048b5" ++
  "c26aa577a8bd98893a608385a987877477aca9b98a716b6d816d6651603c504a" ++
  "91bf83ae7aa4a197924b7368868e8c95798386a2aba68d796a756874565c4e4c" ++
  "495db188b98da490948b667269837c91828979878aa19fa5958d7a6f6f616258" ++
  "5f52524f8090a1a6a39c9086746d6c7a838a8c887f80828f999ea39a93847368" ++
  "5d5e5d5f5e5d526a7d8d9fa6aca0957d6e646a76818e98948e8484848691989d" ++
  "9a8c7b675c58585e5e646067757f8e99a2a5a29987746a676e7b87969797948e" ++
  "8c8a8b8a8a88847b72665e58575a60646c78818c969d9fa1998f8076706c7076" ++
  "818a93979894918c8a87817c74716b686562606163676c77828a969ca4a5a095" ++
  "867b716e6e7379828b949998958e88817b77736f6c6a68676669696e70778188" ++
  "91979fa1a29b9282776c6a6b7179838d939796958f8b847d76716a6867686b6d" ++
  "717376797e838a8f949797958f877f797676787a7e81868a8c8e8d8a86807c78" ++
  "74717070727476787a7c7e80828281807e7f8184888b8d8d8b87837d7a77787a" ++
  "7e818384848482807f7d7b7a7878777878797c7e8183838483828180807f7f80" ++
  "80818283848484838381807f7f8080807f7e7d7c7c7c7d7d7f808081807f7e7d" ++
  "7d7d7e8080818282818181818080818081807f7f8080808180807e7d7d7e7e7f" ++
  "808080808080808080808180808081818181818180808080807f7f7e7e7f7f7f" ++
  "7f7f7f7e7e7e7e7f80818282828281807f7f7e7e7e7e7f7f7f7f7f7e7f7f7f7f" ++
  "80808181808080807f7f7e7f7e7f7f7f80808181818181818181818182828282" ++
  "8181807f7e7e7e7e7e7f7f80808080808081808180808080807f7f7f7f7e7e7e" ++
  "7e7d7e7e7f80818282828181807f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f808080" ++
  "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f80808080808080807f8080807f7f7f7f7f" ++
  "7f7f7f807f8080807f807f807f7f7f80808181818181817f87837d81807e817b" ++
  "7d847f8183827f807c7b7d8080808080807e7f7e7f8080818282828280807f7f" ++
  "7e7e7e7f7f7f7f8082807f808180817f83857f8084837d7c7d807d7d7e7e7d83" ++
  "817d7d817f7c7c7c7d7c83808484827d7f7d7c7e7e7f818482817e7f7f7f7e80" ++
  "81807f807f7e7e7e7e7e8080808081817f7f7f7f8180828183818280807f7f80" ++
  "7d807e817f817f807f7f7e7d8180827f817f7f7e7e7f7e807f817f8181818181" ++
  "82818180817f807f7f7e7e7f7e7f7f7e7f7e7f7e7e7e7e7f7e807f8280818180" ++
  "8180818081808180807e7f7e7d7e7e7f7f7f7e7d807e7f7f807f7f817e818183" ++
  "80818080817f808080817f807f807d807e7d8080837f837e837f807f7e817f7f" ++
  "8080817e7f7f808180837f827f827f80807e7f7d7e7d7e7e7f7e7f7f7f807f81" ++
  "8280828082807f7e7f7e7f807e8080817f7f7e807d7e7e7f807f807e817e817f" ++
  "807f80817f807e817e807d8080808180827e837d807c7d7e7c7e7d7e7f7e7e80" ++
  "7e817e817f81808080808081838081808080807f807e7f7f817f80807f7e8080" ++
  "818281828181818280807e82808481807f81807f807d807d817f818081818080" ++
  "7e807f817f8181817f808080808080808180807e817f7f7e7e7f7f807f7f7e81" ++
  "7e7f80807f7f7f7f817f807f80807f8080807f7f7f807f7e7d7e7e7f7f7f7f7f" ++
  "7f7e7f7f807f807f807f7f808080808180"

structure State where
  window : Window
  renderer : Renderer
  stream : AudioStream
  left : ByteArray
  right : ByteArray
  -- -1 if currently playing left, 1 if playing right, 0 if not playing.
  playingSound : IO.Ref Int32

/-- Draw one button: green while its sound plays, blue otherwise, with a
centered label. C: `render_button`. -/
def renderButton (r : Renderer) (playingSound : Int32) (rect : FRect)
    (str : String) (buttonValue : Int32) : IO Unit := do
  if playingSound == buttonValue then
    r.setDrawColor 0 255 0 255  -- green while playing
  else
    r.setDrawColor 0 0 255 255  -- blue while not playing
  r.fillRect (some rect)
  r.setDrawColor 255 255 255 255
  let charSize := debugTextFontCharacterSize.toFloat32
  let x := rect.x + ((rect.w - (charSize * str.length.toFloat32)) / 2.0)
  let y := rect.y + ((rect.h - charSize) / 2.0)
  r.debugText x y str

def app : App State where
  init := fun _args => do
    setAppMetadata "Example Audio Planar Data" "1.0" "com.example.audio-planar-data"
    Sdl.init (.video ||| .audio)
    let (window, renderer) ←
      createWindowAndRenderer "examples/audio/planar-data" 640 480 .resizable
    renderer.setLogicalPresentation 640 480 .letterbox
    let left := hexToBytes leftHex
    let right := hexToBytes rightHex
    if left.size != 1870 || right.size != 1777 then
      IO.eprintln s!"planar PCM decode failed: sizes {left.size}/{right.size} (want 1870/1777)"
      return (.failure, none)
    -- Uint8 data, stereo, 4000Hz.
    let stream ← openAudioDeviceStream .defaultPlayback (some ⟨.u8, 2, 4000⟩)
    -- SDL_OpenAudioDeviceStream starts the device paused. Resume it!
    stream.resumeDevice
    let playingSound ← IO.mkRef (0 : Int32)
    return (.continue, some { window, renderer, stream, left, right, playingSound })
  event := fun s e => do
    -- C calls SDL_ConvertEventToRenderCoordinates on every event; here we map
    -- the mouse coordinates through the renderer only where we use them.
    match e with
    | .quit _ => return .success
    | .mouseButtonDown me =>
      if (← s.playingSound.get) == 0 then  -- nothing currently playing?
        let (px, py) ← s.renderer.coordinatesFromWindow me.x me.y
        let p : FPoint := ⟨px, py⟩
        if p.inRect rectLeftButton then  -- clicked left button?
          -- `none` says "this specific channel is silent".
          s.stream.putPlanarData #[some s.left, none] 1870
          s.stream.flush  -- that's all we're playing until it completes.
          s.playingSound.set (-1)  -- left is playing
        else if p.inRect rectRightButton then  -- clicked right button?
          s.stream.putPlanarData #[none, some s.right] 1777
          s.stream.flush
          s.playingSound.set 1  -- right is playing
    | _ => pure ()
    return .continue
  iterate := fun s => do
    if (← s.playingSound.get) != 0 then
      if (← s.stream.queued) == 0 then  -- sound is done? play a new sound now.
        s.playingSound.set 0
    s.renderer.setDrawColor 0 0 0 255
    s.renderer.clear
    let ps ← s.playingSound.get
    renderButton s.renderer ps rectLeftButton "LEFT" (-1)
    renderButton s.renderer ps rectRightButton "RIGHT" 1
    s.renderer.present
    return .continue

def main : IO UInt32 := Examples.runApp app
