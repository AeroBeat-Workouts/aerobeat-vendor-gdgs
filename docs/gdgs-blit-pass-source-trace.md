# GDGS BLIT_PASS source trace and culprit shortlist

**Date:** 2026-05-16  
**Investigation branch:** `research/oc-0o7-gdgs-ownership-map`

## Bottom line

The failure path is narrower than the earlier compositor/presentation suspicion.

The current evidence says GDGS successfully:

1. enters `GaussianCompositorEffect._render_callback()`
2. finds the singleton render manager
3. runs `GaussianRenderManager.render_for_compositor()`
4. runs `GaussianRenderer._rasterize_state()`
5. returns valid color/depth compositor texture RIDs

Then Godot later loses the Vulkan device with last breadcrumb `BLIT_PASS`.

The strongest narrowing from the final matrix is that **the crash still happens in `No Present` mode**, where `gaussian_compositor_effect.gd` explicitly skips all script-side composite/writeback/presentation work after the renderer returns valid textures. That means the final compositor shader path is no longer the best primary suspect.

## Confirmed source path

### 1. Compositor callback entry

The scene uses `addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd` as the `CompositorEffect` script.

Relevant code:

- `_init()` sets `effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT` and `access_resolved_depth = true` (`gaussian_compositor_effect.gd:57-60`)
- `_render_callback()` starts at `gaussian_compositor_effect.gd:101`

Observed logs from the repro runs:

- `[gdgs] compositor render callback entered`
- `[gdgs] compositor manager lookup result=found`

These lines map directly to `gaussian_compositor_effect.gd:114` and `:126`.

### 2. Callback delegates into the vendored renderer

Inside `_render_callback()`, the effect calls:

- `manager.render_for_compositor(...)` at `gaussian_compositor_effect.gd:148-154`

That enters:

- `GaussianRenderManager.render_for_compositor()` in `addons/gdgs/runtime/render/gaussian_render_manager.gd:34-46`
- which directly forwards to `GaussianRenderer.render_for_compositor()` in `addons/gdgs/runtime/render/gaussian_renderer.gd:11-66`

### 3. GPU state creation and owned resources

`GaussianRenderer.render_for_compositor()` asks the cache for a render state and rebuilds GPU state when needed (`gaussian_renderer.gd:27-39`).

That rebuild happens in:

- `addons/gdgs/runtime/render/gaussian_gpu_state_cache.gd:80-169`

Important owned resources created there:

- storage/indirect buffers: `grid_dimensions`, `histogram`, `sort_keys`, `sort_values`, `tile_bounds`, etc. (`gaussian_gpu_state_cache.gd:104-114`)
- color target image: `render_texture` with `DATA_FORMAT_R32G32B32A32_SFLOAT` (`gaussian_gpu_state_cache.gd:115`)
- depth target image: `depth_texture` with `DATA_FORMAT_R32_SFLOAT` (`gaussian_gpu_state_cache.gd:116`)
- indirect-dispatch-capable buffer: `grid_dimensions` with `STORAGE_BUFFER_USAGE_DISPATCH_INDIRECT` (`gaussian_gpu_state_cache.gd:106`)

All of this is created against the engine rendering device via:

- `RenderingDeviceContext.create(RenderingServer.get_rendering_device())` (`gaussian_gpu_state_cache.gd:85`)
- `GdgsRenderingDeviceContext.create_texture(... usage: int = 0x18B ...)` (`gaussian_rendering_device_context.gd:76-88`)

### 4. Actual compute path that runs before the crash

After uploads, the renderer always calls:

- `_rasterize_state(state, point_count)` at `gaussian_renderer.gd:49`

That function submits four compute phases:

1. projection pass (`gaussian_renderer.gd:86-88`) using `gsplat_projection.glsl`
2. radix sort passes (`gaussian_renderer.gd:90-100`) using `radix_sort_upsweep.glsl`, `radix_sort_spine.glsl`, `radix_sort_downsweep.glsl`
3. tile-boundary pass (`gaussian_renderer.gd:102-104`) using `gsplat_boundaries.glsl`
4. final raster pass (`gaussian_renderer.gd:106-112`) using `gsplat_render.glsl`

Those pipelines are built in `gaussian_gpu_state_cache.gd:160-165`.

`GdgsRenderingDeviceContext.create_pipeline()` adds a compute barrier after every dispatch (`gaussian_rendering_device_context.gd:101-125`). The radix and boundary phases also use `compute_list_dispatch_indirect()` from the `grid_dimensions` buffer (`gaussian_rendering_device_context.gd:121-125`, called from `gaussian_renderer.gd:97-103`).

### 5. Valid compositor textures are returned before failure

After `_rasterize_state()`, the renderer returns the two output image RIDs from:

- `gaussian_renderer.gd:50-65`

That maps to the repeated log line:

- `[gdgs] renderer prepared compositor textures color_valid=true depth_valid=true ...`

and then:

- `[gdgs] render_for_compositor() textures color_valid=true depth_valid=true`

which is emitted in `gaussian_compositor_effect.gd:161-167`.

### 6. Why the compositor shader is no longer the lead suspect

In normal `Compositor` mode, the effect then binds:

- scene color image from `scene_buffers.get_color_layer(view)` (`gaussian_compositor_effect.gd:180`)
- gsplat color/depth images (`:211-219`)
- scene depth sampler/texture (`:221-225`)
- and dispatches `gaussian_composite.glsl` (`:242-251`)

But in `No Present` mode, the effect exits earlier:

- `if is_no_present_mode: ... break` at `gaussian_compositor_effect.gd:176-178`

That branch logs:

- `[gdgs] no-present mode captured valid compositor textures and skipped all writeback/presentation work`

The `no_present.log` shows that exact line appears **before** the later Vulkan device loss.

So the final compositor compute shader path in `addons/gdgs/runtime/compositor/shaders/gaussian_composite.glsl` is specifically **not required** to trigger the crash.

## What the logs prove

The stable facts from the logs plus source are:

- the effect callback is active
- the renderer manager is found
- the vendored compute renderer runs far enough to allocate/fill compositor target images
- the renderer returns valid texture RIDs
- the crash survives all of these toggles:
  - `Compositor`
  - `Direct Texture (World Overlay)`
  - `Direct Texture (Canvas Overlay)`
  - all debug views
  - `ignore_scene_depth_in_composite`
  - `No Present`
- the last engine breadcrumb stays `BLIT_PASS`

That leaves the remaining failure surface centered on the **vendor compute pipeline and/or the engine/backend handling of that pipeline's resource usage**, not on the final composite shader logic.

## Culprit shortlist

### 1. `GaussianRenderer._rasterize_state()` compute chain, especially indirect dispatch / barrier sequencing

**Owner:** vendored GDGS plugin code  
**Patch surface:**
- `addons/gdgs/runtime/render/gaussian_renderer.gd`
- `addons/gdgs/runtime/render/gaussian_gpu_state_cache.gd`
- `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`

**Why this is the strongest vendor suspect**

- `No Present` mode proves the crash still happens after `_rasterize_state()` but before any script-side composite/writeback path is needed.
- The entire render chain is custom GDGS compute work owned by the plugin.
- The chain mixes several dispatch styles and heavy GPU state transitions in one callback:
  - direct dispatch
  - indirect dispatch from `grid_dimensions`
  - per-pass barriers via `compute_list_add_barrier()`
  - storage-buffer writes feeding later passes
  - storage-image writes in the final render pass
- The upstream comments already hint at backend sensitivity around the `grid_dimensions` / indirect-dispatch path (`gaussian_gpu_state_cache.gd:99-102`).

**What strengthens it**

- This is the last definitely-vendor-owned path that still runs in every crashing case.
- The failure is backend-like, but the trigger is still this plugin-owned dispatch graph.

**What weakens it**

- We do not yet have pass-by-pass isolation proving whether projection, radix sort, boundaries, or final raster is the exact trigger.
- If all usage here is technically valid, the actual bug could still be in Godot/Vulkan/driver handling.

**Smallest plausible next patch/test**

- Add an extremely narrow A/B path that removes indirect dispatch for the radix/boundary stages and uses explicit CPU-known dispatch counts, or otherwise short-circuits to isolate which compute phase causes the device loss.
- Keep this as a vendor-branch experiment first; it is the cheapest high-signal next move.

### 2. Vendor-created RD image formats / usage flags for the offscreen gsplat targets

**Owner:** vendored GDGS plugin code  
**Patch surface:**
- `addons/gdgs/runtime/render/gaussian_gpu_state_cache.gd`
- `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`
- secondarily `addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`

**Why it is plausible**

- GDGS allocates custom RD images for color/depth output:
  - `R32G32B32A32_SFLOAT`
  - `R32_SFLOAT`
- texture creation goes through a shared default usage bitmask `0x18B` (`gaussian_rendering_device_context.gd:79`, `gaussian_compositor_effect.gd:11`, `:365`).
- The output textures are later surfaced across engine-managed render flow, and the device loss is only observed once the frame reaches the engine's later `BLIT_PASS` boundary.

**What strengthens it**

- The crash is consistent with a resource/state/layout problem that is only reported later when the engine presents.
- Intel/Vulkan paths can be especially sensitive to image format / usage / barrier combinations.

**What weakens it**

- `No Present` mode means the final composite shader does not bind these images back into the scene color path before the crash.
- That makes pure “composite readback” misuse less likely; this suspect only survives if the problem is in image creation/write usage itself or in later engine handling of those written images.

**Smallest plausible next patch/test**

- Try a narrow vendor change that simplifies formats/usage bits to the minimum valid set Godot expects for compute-written textures on this path, or test a less exotic color format if acceptable for isolation.

### 3. Godot/Vulkan backend handling of `CompositorEffect` + RD compute work on Intel Iris Xe

**Owner:** Godot / engine/backend below the vendor repo  
**Patch surface:** outside this repo

**Why it is plausible**

- Every enabled path converges to the same engine breadcrumb: `BLIT_PASS`.
- `No Present` removes the plugin's final compositor dispatch as a necessary condition.
- The plugin proves it can return valid offscreen texture RIDs before the device is lost.
- There is no deeper runtime library between GDGS and Godot in this repo; the next ownership layer is the engine/backend itself.

**What strengthens it**

- The best-exonerated area is now the GDScript compositor/presentation branch.
- The remaining behavior smells like either:
  - a backend bug in how Godot handles this compute/resource pattern, or
  - an Intel-driver-sensitive engine path surfaced during the frame's later blit/present stage.

**What weakens it**

- We have not yet proven that GDGS' compute/resource usage is fully valid and minimal.
- Escalating now without one more vendor-side isolation pass would be a bit early.

**Best next step if vendor isolation does not clear it**

- Escalate to a Godot/backend issue or fork lane with this source trace attached.
- At that point the owner is probably below GDGS, not another third-party dependency.

## Explicit non-lead suspects

### `gaussian_composite.glsl`

Not the current lead. It only runs in `Compositor` mode, but the crash also reproduces in `No Present`, where that dispatch is skipped entirely.

### Scene-depth logic in the compositor effect

Not the current lead. `ignore_scene_depth_in_composite` did not change the failure class, and `No Present` bypasses that path altogether.

### Overlay presentation (`Direct Texture` world/canvas)

Not the current lead. Both overlay modes still crash identically, so the overlay presentation branches are not the unique trigger.

## Recommendation

**Best next step:** one more very narrow vendor-side isolation pass around the renderer compute chain, then escalate to Godot/backend quickly if that does not reveal a clear plugin misuse.

So:

- **Patch lane right now:** vendored GDGS plugin
- **Most likely escalation lane if that patch lane stays clean:** Godot/engine/backend
- **Need a brand-new non-GDGS third-party fork right now?** No
- **Need to be prepared for a Godot-side fork/issue next?** Yes
