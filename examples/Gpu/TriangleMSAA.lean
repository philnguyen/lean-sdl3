import Common.Gpu

/-!
# gpu/13-triangle-msaa

Port of `TriangleMSAA.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples):
multisample anti-aliasing. For every sample count the device supports for
the swapchain format (`Device.textureSupportsSampleCount`) it creates one
graphics pipeline with that `multisampleState.sampleCount` and a matching
640×480 render-target texture. Each frame the raw triangle is drawn into the
current sample count's texture; multisampled targets end their pass with
`storeOp := .resolve` into a single-sample resolve texture, and the
(resolved) image's top-center 320×240 region (x 160–480, y 0–240) is
blitted up onto the swapchain so the edge quality difference is visible.

Controls: **Left**/**Right** cycle between the supported sample counts.

Shaders: `RawTriangle.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

/-- One supported sample count: its pipeline and render target. The pipeline
must live in the state (pass binds do not retain it). -/
structure SampleMode where
  sampleCount : Gpu.SampleCount
  pipeline : Gpu.GraphicsPipeline
  renderTexture : Gpu.Texture

structure State where
  /-- C: `Pipelines` / `MSAARenderTextures`, compacted to the supported counts. -/
  modes : Array SampleMode
  resolveTexture : Gpu.Texture
  /-- Index into `modes`. C: `CurrentSampleCount`. -/
  current : IO.Ref Nat

/-- The number of samples as a number, for the log lines. C: `1 << i`. -/
def samples (c : Gpu.SampleCount) : Nat := 1 <<< c.val.toNat

#guard samples .x1 == 1 && samples .x2 == 2 && samples .x4 == 4 && samples .x8 == 8

/-- The sample counts to try, in `SDL_GPUSampleCount` order. -/
def allSampleCounts : Array Gpu.SampleCount := #[.x1, .x2, .x4, .x8]

def demo : Example State where
  name := "TriangleMSAA"
  init ctx := do
    -- Create the shaders
    let vertexShader ← loadShader ctx.device "RawTriangle.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"

    -- Create the pipelines
    let rtFormat ← ctx.swapchainFormat
    let info : Gpu.GraphicsPipelineCreateInfo := {
      vertexShader, fragmentShader
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{ format := rtFormat }] }
    }
    let mut modes : Array SampleMode := #[]
    for sampleCount in allSampleCounts do
      unless ← ctx.device.textureSupportsSampleCount rtFormat sampleCount do
        IO.println s!"Sample count {samples sampleCount} not supported"
        continue
      let pipeline ← ctx.device.createGraphicsPipeline
        { info with multisampleState := { sampleCount } }
      -- Create the render target textures. Only the single-sample one is
      -- blitted from directly, so only it needs the sampler usage.
      let renderTexture ← ctx.device.createTexture {
        type := .d2, width := 640, height := 480, layerCountOrDepth := 1, numLevels := 1,
        format := rtFormat, sampleCount,
        usage := if sampleCount == .x1 then .colorTarget ||| .sampler else .colorTarget }
      modes := modes.push { sampleCount, pipeline, renderTexture }

    -- Create resolve texture
    let resolveTexture ← ctx.device.createTexture {
      type := .d2, width := 640, height := 480, layerCountOrDepth := 1, numLevels := 1,
      format := rtFormat, usage := .colorTarget ||| .sampler }

    -- Clean up shader resources
    vertexShader.release
    fragmentShader.release

    -- Print the instructions
    IO.println "Press Left/Right to cycle between sample counts"
    IO.println s!"Current sample count: {samples .x1}"

    return { modes, resolveTexture, current := ← IO.mkRef 0 }
  update ctx s := do
    let n := s.modes.size
    let mut changed := false
    if ← ctx.leftPressed then
      s.current.modify fun c => if c == 0 then n - 1 else c - 1
      changed := true
    if ← ctx.rightPressed then
      s.current.modify fun c => (c + 1) % n
      changed := true
    if changed then
      let c ← s.current.get
      if let some mode := s.modes[c]? then
        IO.println s!"Current sample count: {samples mode.sampleCount}"
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let some mode := s.modes[← s.current.get]? | return
    let singleSample := mode.sampleCount == .x1
    let colorTargetInfo : Gpu.ColorTargetInfo := {
      texture := mode.renderTexture
      clearColor := ⟨1, 1, 1, 1⟩
      loadOp := .clear
      storeOp := if singleSample then .store else .resolve
      resolveTexture := if singleSample then none else some s.resolveTexture }
    let rp ← cmd.beginRenderPass #[colorTargetInfo]
    rp.bindPipeline mode.pipeline
    rp.drawPrimitives 3
    rp.finish

    -- Blit from the resolved image (or the single-sample target itself).
    let blitSourceTexture := colorTargetInfo.resolveTexture.getD colorTargetInfo.texture
    cmd.blitTexture {
      source := { texture := blitSourceTexture, x := 160, w := 320, h := 240 }
      destination := { texture := sc.texture, w := sc.width, h := sc.height }
      loadOp := .dontCare
      filter := .linear }

def main : IO UInt32 := demo.run
