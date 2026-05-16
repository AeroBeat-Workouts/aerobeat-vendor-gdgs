# Draft upstream issue for ReconWorldLab/godot-gaussian-splatting

> Status: draft only — not filed upstream yet

## Proposed title

Forward+ / Vulkan on Intel Iris Xe (Wayland): README-happy-path scene goes black and then loses the device near `BLIT_PASS`; GL Compatibility stays blank

## In Plain English

I built the smallest possible project that follows the GDGS README setup as literally as I could, using the plugin's own sample asset and compositor script. On this machine, that minimal scene still does not render a visible splat correctly.

In the normal supported path (`Forward Plus` / Vulkan), the frame goes black and Godot loses the Vulkan device near `BLIT_PASS`. In `GL Compatibility`, the scene runs, but the splat is still not visible. I also added a very small test harness to switch between the plugin's existing debug/compositor branches, and every enabled render/composite path still fails the same way.

The important part is that this no longer looks like an app-integration mistake on my side. The minimal vendor control scene, the sample asset, and the plugin's own compositor effect all reproduce the same failure boundary.

I then pushed the local reduction one step further with two extra presentation-side experiments:

- `Direct Texture (Canvas Overlay)`
- `No Present`

`No Present` is the strongest signal: it still runs `render_for_compositor()`, proves valid color/depth compositor textures exist, and explicitly skips the GDGS script-side writeback/presentation work — yet the run still dies with the same `BLIT_PASS` device-loss boundary.

## Summary

Using GDGS `2.2.0` (upstream commit `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`) inside a minimal Godot project on an Intel Iris Xe / Wayland Linux machine:

- a README-literal control scene using `GaussianSplatNode` + `WorldEnvironment.compositor` + `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`
- with the bundled sample asset `samples/assets/demo.compressed.ply`

fails in two consistent ways:

1. **Forward+ / Vulkan:** black first frame, then Vulkan device loss with last breadcrumb `BLIT_PASS`
2. **GL Compatibility:** scene runs, but the splat is still blank/background-only

A narrow local tweak matrix ruled out several likely setup mistakes:

- disabling the compositor effect avoids the crash, but only leaves a stable blank scene
- `Direct Texture` still goes black and loses the device
- all built-in debug views (`GS Alpha`, `GS Color`, `GS Depth`, `Scene Depth`, `Depth Reject Mask`) still go black and lose the device
- bypassing scene-depth usage in composite does not change the failure
- added logs show valid compositor textures are produced before the crash path
- even `Direct Texture (Canvas Overlay)` still fails the same way
- even `No Present` still fails the same way after explicitly skipping GDGS script-side writeback/presentation work

## Environment

### Host

- Device: Microsoft Surface Pro 8
- OS: Zorin OS 18 Pro
- Kernel during repro: `Linux derrick-Surface-Pro-8 6.19.8-surface-3 x86_64`
- Session type: `Wayland`
- CPU: 11th Gen Intel Core i7-1185G7
- RAM: 16 GB
- GPU: `Intel(R) Iris(R) Xe Graphics (TGL GT2)`

### Godot / graphics

- Godot version: `4.6.2.stable.official.71f334935`
- Forward+ runtime log reports: `Vulkan 1.4.318 - Forward+ - Using Device #0: Intel - Intel(R) Iris(R) Xe Graphics (TGL GT2)`
- GL Compatibility runtime log reports: `OpenGL API 4.6 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.1 - Compatibility - Using Device: Intel - Mesa Intel(R) Iris(R) Xe Graphics (TGL GT2)`

### GDGS version under test

- Upstream repo: `ReconWorldLab/godot-gaussian-splatting`
- README version used as source of truth: `2.2.0`
- Pinned upstream commit in my vendor mirror: `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`

## Minimal repro project shape

I created a minimal local control project whose main scene is:

- `res://scenes/gdgs_happy_path_control.tscn`

and whose project root is:

- `res://` at `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`

The scene follows the README quick-start path as literally as practical:

1. plugin available at `res://addons/gdgs`
2. sample asset at `res://samples/assets/demo.compressed.ply`
3. `GaussianSplatNode`
4. `WorldEnvironment`
5. `WorldEnvironment.compositor = Compositor`
6. `CompositorEffect` script set to `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`

Only minimal extras were added so the scene is usable:

- one `Camera3D`
- one `DirectionalLight3D`
- one small HUD label

## Exact repro steps

### Repro A: README-literal happy path on Forward+

1. Use the project at:
   - `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`
2. Confirm the main scene is:
   - `res://scenes/gdgs_happy_path_control.tscn`
3. Import once:

```bash
~/.local/bin/godot --import --headless --path /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs
```

4. Run the project normally under desktop Forward+:

```bash
~/.local/bin/godot --path /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs
```

### Actual result

- the scene presents a black first frame
- Godot then aborts with Vulkan device loss
- the log breadcrumb reports `BLIT_PASS`

### Expected result

- the sample Gaussian splat should render visibly in the scene, as the README happy path implies
- at minimum, the scene should not lose the Vulkan device when using the plugin's documented setup

## Narrow repro matrix using the same control scene

To avoid hand-wavy debugging, I added a tiny harness to the same control scene:

- harness script: `res://scripts/gdgs_tweak_matrix_harness.gd`

Live toggles used:

- `C` — effect enabled/disabled
- `M` — `Compositor` / `Direct Texture`
- `D` — built-in debug view cycle
- `I` — local toggle to ignore scene depth during composite

### Cases tested

Using fresh processes per case, all from the same control scene and same sample asset:

#### First matrix

- `effect_disabled`
- `direct_texture`
- `gs_alpha`
- `gs_color`
- `gs_depth`
- `scene_depth`
- `depth_reject_mask`
- `composite`
- `composite_ignore_scene_depth`

#### Final ultra-narrow presentation-side matrix

- `compositor`
- `effect_disabled`
- `direct_texture_world`
- `direct_texture_canvas`
- `no_present`

### Results

From `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/run_summary.tsv`:

- `effect_disabled` → exit code `0`
- every enabled case above → exit code `134`

From `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/run_summary.tsv`:

- `compositor` → exit code `134`
- `effect_disabled` → exit code `0`
- `direct_texture_world` → exit code `134`
- `direct_texture_canvas` → exit code `134`
- `no_present` → exit code `134`

Image metrics from the captured PNGs:

- `effect_disabled` stayed non-crashing but only showed a flat non-splat frame (`mean_luma ~= 0.0457`, `stddev_luma = 0.0`)
- every enabled branch captured black output (`mean_luma = 0.0`, `non_black_ratio = 0.0`) before the device-loss abort

## Strongest evidence / artifacts

### Primary logs

- Happy-path Forward+ crash log:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/forward_plus/godot.log`
- Happy-path Forward+ stdout mirror:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/forward_plus/stdout.log`
- GL Compatibility run log:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/gl_compatibility/godot.log`

### Matrix summary + per-case logs

- Matrix summary:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/run_summary.tsv`
- Representative enabled-case log showing valid textures before failure:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/logs/composite.log`
- Representative `Direct Texture` log:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/logs/direct_texture.log`
- Non-crashing disabled-effect log:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/logs/effect_disabled.log`
- Final ultra-narrow presentation-side summary:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/run_summary.tsv`
- `No Present` log proving valid textures + skipped script-side present/writeback before failure:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/no_present.log`
- `Direct Texture (Canvas Overlay)` log:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/direct_texture_canvas.log`

### Representative images

- GL Compatibility blank frame:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/gl_compatibility/frame00000010.png`
- Forward+ matrix disabled-effect capture:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/effect_disabled.png`
- Forward+ matrix `Direct Texture` capture:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/direct_texture.png`
- Forward+ matrix `Composite` capture:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/composite.png`
- Final presentation-side disabled-effect stable capture:
  - `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/effect_disabled.png`

### Previous comparison evidence

I also compared this against an AeroBeat integration repro. That path converged on the same failure boundary instead of diverging:

- `/home/derrick/.openclaw/workspace/.temp/aerobeat-qa/results/repro_fp_runtime/godot.log`
- `/home/derrick/.openclaw/workspace/.temp/aerobeat-qa/results/repro_fp_runtime/meta_wrapper.json`

## Key log excerpts

### Forward+ happy path

```text
Vulkan 1.4.318 - Forward+ - Using Device #0: Intel - Intel(R) Iris(R) Xe Graphics (TGL GT2)
ERROR: Last known breadcrumb: BLIT_PASS
ERROR: Vulkan device was lost.
```

### Enabled matrix case (`composite`)

```text
[gdgs] compositor manager lookup result=found
[gdgs] renderer prepared compositor textures color_valid=true depth_valid=true texture_size=(2560, 1440) point_count=271123
[gdgs] render_for_compositor() textures color_valid=true depth_valid=true
[gdgs] compositor dispatch pending display_mode=Compositor debug_view=Composite use_scene_depth=true size=(2560, 1440)
ERROR: Last known breadcrumb: BLIT_PASS
ERROR: Vulkan device was lost.
```

### Enabled matrix case (`direct_texture`)

```text
[gdgs] compositor mode=Direct Texture debug_view=Composite ignore_scene_depth_in_composite=false enabled=true
[gdgs] compositor render callback entered
[gdgs] compositor manager lookup result=found
[gdgs] renderer prepared compositor textures color_valid=true depth_valid=true texture_size=(2560, 1440) point_count=271123
[gdgs] render_for_compositor() textures color_valid=true depth_valid=true
ERROR: Last known breadcrumb: BLIT_PASS
ERROR: Vulkan device was lost.
```

### Final ultra-narrow case (`no_present`)

```text
[gdgs] compositor mode=No Present debug_view=Composite ignore_scene_depth_in_composite=false enabled=true
[gdgs] compositor render callback entered
[gdgs] compositor manager lookup result=found
[gdgs] renderer prepared compositor textures color_valid=true depth_valid=true texture_size=(1152, 648) point_count=271123
[gdgs] render_for_compositor() textures color_valid=true depth_valid=true
[gdgs] no-present mode captured valid compositor textures and skipped all writeback/presentation work
ERROR: Last known breadcrumb: BLIT_PASS
ERROR: Vulkan device was lost.
```

## Expected behavior

Given the documented requirements and quick-start path, I expected:

- the sample asset to be visibly rendered in the control scene on the supported Forward+ backend
- the debug views or `Direct Texture` path to at least help isolate output without crashing the device
- the plugin not to black-screen and lose the Vulkan device when the scene is otherwise minimal and README-literal

## Actual behavior

- Forward+ / Vulkan never produced a stable visible splat in the tested control scene
- every enabled render/composite path went black and then lost the device near `BLIT_PASS`
- GL Compatibility did not crash, but also did not show a visible splat
- disabling the compositor effect avoids the crash only because it avoids the enabled GDGS presentation/composite path; it does not produce a rendered splat

## What I ruled out locally

I tried to eliminate broad integration mistakes before writing this up.

### Ruled out with a minimal control project

- not using the plugin's expected folder layout (`res://addons/gdgs`)
- not using the plugin's own sample asset
- not following the README scene structure
- broad app-wrapper wiring mistakes in a larger downstream project

### Ruled out with the tweak matrix

- compositor effect enable/disable as a simple setup toggle
- `Direct Texture` vs `Compositor`
- all built-in debug views
- scene-depth dependency as the sole cause
- missing compositor manager / missing returned textures
- script-side compositor image writeback as the only cause
- world-overlay vs canvas-overlay presentation branch as the only cause

The logs show the compositor callback is reached, the manager is found, and valid color/depth compositor textures are produced before the failure boundary.

## Current best guess about the failure boundary

The narrowest local conclusion I can support is:

- GDGS on this machine/backend can reach compositor texture production successfully
- even when explicit GDGS script-side writeback/presentation work is skipped (`No Present`), the run still dies at the same `BLIT_PASS` boundary
- the remaining fault surface therefore appears to be lower-level than the final presentation branch we can easily toggle in GDScript

That suggests the remaining fault surface is closer to a render/backend stage associated with the same `BLIT_PASS` boundary on this Intel Iris Xe + Wayland + Vulkan Forward+ path than to asset import, scene setup, manager lookup, scene-depth logic, or only the final script-side present/writeback branch.

## Questions for maintainers

1. Does this Intel Iris Xe / Wayland / Vulkan Forward+ behavior match any known driver-sensitive path in GDGS?
2. Is `Direct Texture` expected to bypass enough of the compositor/writeback path that it should not be failing identically here?
3. Is there a known reason the plugin could produce valid compositor textures but still die at `BLIT_PASS` when presenting/compositing them?
4. If you want, I can reduce this further into a stripped public repro project that contains only the minimal control scene and the sample asset.

## Notes

- I did **not** file this yet; this is a draft package prepared from local testing.
- I also did **not** see an upstream `.github/ISSUE_TEMPLATE/` or `CONTRIBUTING.md`, so I used a plain maintainer-friendly bug-report structure.
