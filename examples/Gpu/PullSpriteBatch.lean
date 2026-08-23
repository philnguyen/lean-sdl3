import Common.Gpu

/-!
# gpu/17-pull-sprite-batch

Port of `PullSpriteBatch.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples) — the
sprite batcher from Evan Hemsley's
[SDL GPU sprite batcher tutorial](https://moonside.games/posts/sdl-gpu-sprite-batcher/).

Every frame, 8192 randomly placed and rotated 32×32 ravioli sprites are
written into an upload transfer buffer as `SpriteInstance` records, copied
into a `GRAPHICS_STORAGE_READ` buffer, and drawn with one
`drawPrimitives (8192 * 6)` call. There is no vertex buffer: the vertex
shader *pulls* its sprite from the storage buffer by `SV_VertexID / 6` and
expands the quad corner `SV_VertexID % 6` itself, so the whole batch is one
copy pass + one draw. The camera is an orthographic projection of the
640×480 window pushed as a vertex uniform; alpha blending composites the
sprites over the black clear.

Present mode: immediate if the window supports it, else mailbox, else vsync
(the batch is meant to run unthrottled so the draw cost is visible).

Shaders: `PullSpriteBatch.vert` (1 uniform buffer, 1 storage buffer),
`TexturedQuadColor.frag` (1 sampler).
-/

open Sdl Examples.Gpu

/-- Sprites per frame. C: `SPRITE_COUNT`. -/
def spriteCount : Nat := 8192

/-- `sizeof(SpriteInstance)`: `x y z rotation | w h pad pad | u v w h | r g b a`,
sixteen floats. -/
def spriteInstanceSize : Nat := 64

/-- Texture-atlas column of each ravioli variant. C: `uCoords`. -/
def uCoords : Array Float32 := #[0.0, 0.5, 0.0, 0.5]
/-- Texture-atlas row of each ravioli variant. C: `vCoords`. -/
def vCoords : Array Float32 := #[0.0, 0.0, 0.5, 0.5]

/-- Append one `SpriteInstance` (64 bytes) to `b`. -/
def emitSprite (b : ByteArray) (x y rotation : Float32) (ravioli : Nat) : ByteArray :=
  [x, y, 0, rotation,                          -- x, y, z, rotation
   32, 32, 0, 0,                               -- w, h, padding_a, padding_b
   uCoords[ravioli]!, vCoords[ravioli]!, 0.5, 0.5, -- tex_u, tex_v, tex_w, tex_h
   1, 1, 1, 1].foldl pushF32 b                 -- r, g, b, a

#guard (emitSprite .empty 0 0 0 0).size == spriteInstanceSize

/-- Fill a `spriteCount × SpriteInstance` batch with random sprites,
advancing the xorshift state. C: the `SDL_MapGPUTransferBuffer` loop in
`Draw` (with `SDL_rand`/`SDL_randf` replaced by the xorshift stream). -/
def buildSpriteBatch (rng : UInt64) : ByteArray × UInt64 := Id.run do
  let mut b := ByteArray.emptyWithCapacity (spriteCount * spriteInstanceSize)
  let mut s := rng
  for _ in [0:spriteCount] do
    s := xorshift64 s
    let ravioli := (s >>> 8).toNat % 4                      -- SDL_rand(4)
    s := xorshift64 s
    let x := ((s >>> 8).toNat % 640).toFloat32              -- SDL_rand(640)
    s := xorshift64 s
    let y := ((s >>> 8).toNat % 480).toFloat32              -- SDL_rand(480)
    s := xorshift64 s
    let rotation := randFloat s * Examples.pi.toFloat32 * 2 -- SDL_randf() * 2π
    b := emitSprite b x y rotation ravioli
  return (b, s)

#guard (buildSpriteBatch 1).1.size == spriteCount * spriteInstanceSize
#guard (buildSpriteBatch 1).2 != 1

structure State where
  renderPipeline : Gpu.GraphicsPipeline
  sampler : Gpu.Sampler
  texture : Gpu.Texture
  spriteDataTransferBuffer : Gpu.TransferBuffer
  spriteDataBuffer : Gpu.Buffer
  rng : IO.Ref UInt64

def demo : Example State where
  name := "PullSpriteBatch"
  init ctx := do
    let presentMode : Gpu.PresentMode ←
      if ← ctx.device.windowSupportsPresentMode ctx.window .immediate then pure .immediate
      else if ← ctx.device.windowSupportsPresentMode ctx.window .mailbox then pure .mailbox
      else pure .vsync
    ctx.device.setSwapchainParameters ctx.window .sdr presentMode

    -- Create the shaders
    let vertShader ← loadShader ctx.device "PullSpriteBatch.vert"
      (numUniformBuffers := 1) (numStorageBuffers := 1)
    let fragShader ← loadShader ctx.device "TexturedQuadColor.frag" (numSamplers := 1)

    -- Create the sprite render pipeline
    let renderPipeline ← ctx.device.createGraphicsPipeline {
      vertexShader := vertShader
      fragmentShader := fragShader
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{
        format := ← ctx.swapchainFormat
        blendState := {
          enableBlend := true
          colorBlendOp := .add
          alphaBlendOp := .add
          srcColorBlendfactor := .srcAlpha
          dstColorBlendfactor := .oneMinusSrcAlpha
          srcAlphaBlendfactor := .srcAlpha
          dstAlphaBlendfactor := .oneMinusSrcAlpha } }] }
    }
    vertShader.release
    fragShader.release

    -- Load the image data
    let image ← loadImage "ravioli_atlas.bmp"
    let textureTransferBuffer ← ctx.device.createTransferBuffer .upload
      (image.width * image.height * 4)
    textureTransferBuffer.write image.pixels

    -- Create the GPU resources
    let texture ← ctx.device.createTexture {
      type := .d2, format := .r8g8b8a8Unorm, usage := .sampler
      width := image.width, height := image.height }
    let sampler ← ctx.device.createSampler {
      minFilter := .nearest, magFilter := .nearest, mipmapMode := .nearest
      addressModeU := .clampToEdge, addressModeV := .clampToEdge, addressModeW := .clampToEdge }
    let batchSize := (spriteCount * spriteInstanceSize).toUInt32
    let spriteDataTransferBuffer ← ctx.device.createTransferBuffer .upload batchSize
    let spriteDataBuffer ← ctx.device.createBuffer .graphicsStorageRead batchSize

    -- Transfer the up-front data
    let uploadCmdBuf ← ctx.device.acquireCommandBuffer
    let copyPass ← uploadCmdBuf.beginCopyPass
    copyPass.uploadToTexture { buffer := textureTransferBuffer }
      { texture, w := image.width, h := image.height }
    copyPass.finish
    uploadCmdBuf.submit
    textureTransferBuffer.release

    return { renderPipeline, sampler, texture, spriteDataTransferBuffer, spriteDataBuffer,
             rng := ← IO.mkRef 0x9E3779B97F4A7C15 }
  draw ctx s := do
    let cameraMatrix := Matrix4x4.orthographicOffCenter 0 640 480 0 0 (-1)
    withSwapchainFrame ctx fun cmd sc => do
      -- Build sprite instance transfer
      let (batch, rng) := buildSpriteBatch (← s.rng.get)
      s.rng.set rng
      s.spriteDataTransferBuffer.write batch (cycle := true)

      -- Upload instance data
      let copyPass ← cmd.beginCopyPass
      copyPass.uploadToBuffer { buffer := s.spriteDataTransferBuffer }
        { buffer := s.spriteDataBuffer, size := batch.size.toUInt32 } (cycle := true)
      copyPass.finish

      -- Render sprites
      let renderPass ← cmd.beginRenderPass #[{
        texture := sc.texture, loadOp := .clear, storeOp := .store, clearColor := ⟨0, 0, 0, 1⟩ }]
      renderPass.bindPipeline s.renderPipeline
      renderPass.bindVertexStorageBuffers 0 #[s.spriteDataBuffer]
      renderPass.bindFragmentSamplers 0 #[{ texture := s.texture, sampler := s.sampler }]
      cmd.pushVertexUniformData 0 cameraMatrix.toBytes
      renderPass.drawPrimitives (spriteCount * 6).toUInt32
      renderPass.finish

def main : IO UInt32 := demo.run
