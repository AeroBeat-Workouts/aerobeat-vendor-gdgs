# GDGS BLIT_PASS ownership and dependency map

**Date:** 2026-05-16  
**Investigation branch:** `research/oc-0o7-gdgs-ownership-map`

## Summary

For the current `BLIT_PASS` / Vulkan device-loss bug, the most likely **first fix lane** is still inside the vendored GDGS plugin source in `addons/gdgs/`, because the failing behavior is driven by the plugin's own compositor and `RenderingDevice` compute/render orchestration.

That said, the vendor repo does **not** own the entire failure surface. The plugin is pure GDScript + Godot shader code and sits directly on top of Godot engine APIs like `CompositorEffect`, `RenderingDevice`, `RenderingServer`, `RenderSceneBuffersRD`, and Vulkan-backed texture/compute behavior. So the likely ownership split is:

- **Vendor GDGS repo owns:** script logic, resource lifetime, texture allocation flags, shader dispatch order, descriptor wiring, scene-depth/composite usage, and any plugin misuse of Godot's rendering APIs.
- **Godot engine/backend owns:** `BLIT_PASS` internals, Vulkan device-loss behavior, render-graph/pass execution, driver-facing image/layout/barrier semantics, and any engine bug triggered by otherwise-valid plugin use.
- **Deeper third-party dependency:** none found inside this repo for the runtime failure path. No native library, GDExtension, submodule, or external runtime package is bundled here.

## Source layout and ownership boundaries

### 1. Vendor-owned plugin payload (`addons/gdgs/`)

This repo vendors the upstream plugin from `ReconWorldLab/godot-gaussian-splatting` at pinned commit `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`.

Main areas:

- `addons/gdgs/plugin.gd`, `plugin.cfg`
  - Godot editor plugin registration.
- `addons/gdgs/importers/`
  - Asset import/parsing/decoder path for `.ply`, `.splat`, `.sog`.
  - Important for content ingestion, but not the strongest owner for the current `BLIT_PASS` crash.
- `addons/gdgs/runtime/nodes/`
  - Scene-facing node/resource hookup.
- `addons/gdgs/runtime/render/`
  - Core GPU orchestration owned by GDGS.
  - `gaussian_render_manager.gd`
  - `gaussian_renderer.gd`
  - `gaussian_gpu_state_cache.gd`
  - `gaussian_rendering_device_context.gd`
  - `runtime/render/shaders/compute/*.glsl`
- `addons/gdgs/runtime/compositor/`
  - Compositor callback integration and final composite/present logic.
  - `gaussian_compositor_effect.gd`
  - `runtime/compositor/shaders/gaussian_composite.glsl`
- `addons/gdgs/runtime/debug/`
  - Direct-texture overlay shader/debug presentation.

### 2. Godot engine / backend API surface

The runtime failure path directly touches engine-owned APIs and render-backend behavior:

- `CompositorEffect`
- `RenderingDevice`
- `RenderingServer.get_rendering_device()`
- `RenderingServer.call_on_render_thread(...)`
- `RenderSceneBuffersRD`
- `RenderSceneDataRD`
- `Texture2DRD`
- `RDTextureFormat`, `RDTextureView`, `RDUniform`, shader/pipeline creation

These are not vendored here; they are engine/backend surfaces. If GDGS is using them incorrectly, the fix belongs in the vendor lane. If the usage is valid but still triggers `BLIT_PASS` device loss on Intel Iris Xe / Wayland / Vulkan, the owning fix may move into Godot engine or backend work.

### 3. Deeper dependency check

I did **not** find any deeper runtime library packaged in this vendor repo:

- no `.gdextension`
- no `.gdnlib`
- no C/C++/Rust source
- no shared libraries (`.so`, `.dll`, `.dylib`)
- no submodules

So for this bug, there is no obvious "hidden lower repo" between GDGS and Godot. The next ownership layer below GDGS is effectively **Godot itself / the Vulkan backend / possibly the driver interaction**.

## Why the likely first patch lane is still GDGS

The narrowed evidence already shows that GDGS reaches valid compositor texture production. The plugin code still owns several plausible misuse surfaces before we conclude the engine/backend is at fault:

- texture creation flags/usage bits (`DEFAULT_TEXTURE_USAGE_BITS`, custom RD textures)
- compute shader output formats and descriptor bindings
- resource lifetime / freeing / reuse across frames
- compositor callback sequencing and cross-thread render-server usage
- scene color/depth image binding expectations inside `gaussian_compositor_effect.gd`
- assumptions about image read/write hazards or format compatibility in the plugin shaders/scripts

That makes `addons/gdgs/runtime/compositor/` and `addons/gdgs/runtime/render/` the right source-investigation lane before escalating to a Godot fork.

## Current ownership call for the bug

### Most likely first investigation/fix surface
- **Vendored GDGS plugin:** yes, as the first patch lane.

### Possible ultimate owner if vendor logic looks valid
- **Godot engine/backend:** yes, especially anything around the engine's `BLIT_PASS` / Vulkan render path.

### Another dependency/library requiring a separate fork right now
- **No clear evidence yet.** No separate bundled dependency was found in this repo.

## Practical next move

For follow-up tracing or patches, focus on:

1. `addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`
2. `addons/gdgs/runtime/compositor/shaders/gaussian_composite.glsl`
3. `addons/gdgs/runtime/render/gaussian_renderer.gd`
4. `addons/gdgs/runtime/render/gaussian_gpu_state_cache.gd`
5. `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`
6. `addons/gdgs/runtime/render/shaders/compute/*.glsl`

If those look correct and reproducibly still trigger the same boundary, Derrick may need a **Godot-side fork/issue lane** rather than a new non-Godot dependency fork.
