# GDGS direct-dispatch isolation patch

**Date:** 2026-05-16  
**Branch:** `research/oc-0o7-gdgs-ownership-map`

## Why this patch exists

The source trace narrowed the live crash to the vendor-owned compute chain in `addons/gdgs/runtime/render/`, not the final compositor shader.

The highest-signal remaining vendor-side suspect was the renderer's use of `compute_list_dispatch_indirect()` for the radix-sort and tile-boundary passes:

- the dispatch counts were already CPU-known during GPU-state build
- the backing `grid_dimensions` buffer was being pre-seeded on the CPU anyway
- the same path also carried `STORAGE_BUFFER_USAGE_DISPATCH_INDIRECT`, which widens the resource-usage surface on the backend

That made indirect dispatch the narrowest plausible vendor-owned isolation point.

## What changed

The patch keeps the existing compute pipeline and worst-case work sizing, but removes the runtime indirect-dispatch path for the three suspect passes:

- `radix_sort_upsweep`
- `radix_sort_downsweep`
- `gsplat_boundaries`

Instead of calling `compute_list_dispatch_indirect()`, those passes now use direct dispatch with CPU-known upper bounds:

- radix passes dispatch `num_partitions`
- boundaries dispatch `ceil(num_sort_elements_max / 256.0)`

This is safe for isolation because the shaders already self-guard against oversubscription:

- radix passes early-return when `partition_start >= element_count`
- boundaries early-return when `id >= sort_buffer_size`

The legacy `grid_dimensions` buffer is still allocated and bound so the shader/descriptors remain stable, but it no longer requests `STORAGE_BUFFER_USAGE_DISPATCH_INDIRECT`.

## Why this is a good isolation step

This patch is intentionally narrow and reversible:

- no broad algorithm rewrite
- no compositor-path changes
- no scene/API contract changes for QA
- no format or shader math changes

If the Surface Pro 8 repro improves or stops crashing, the strongest signal is that GDGS' indirect-dispatch/resource-usage path was the trigger.

If the same `BLIT_PASS` device-loss still occurs, the evidence shifts further away from plugin-owned dispatch setup and further toward Godot/Vulkan/backend ownership.

## QA / audit notes

Look for this log line during validation:

```text
[gdgs] renderer using direct dispatch isolation for radix/boundary passes
```

That confirms the isolation path is active in the tested build.

## Surface Pro 8 QA result

Real-machine QA was rerun on 2026-05-16 on the actual Wayland / Vulkan Surface Pro 8 path using the same control-scene harness and case order as the prior `REF-06` baseline.

Artifact folder:

- `/home/derrick/.openclaw/workspace/.temp/gdgs-direct-dispatch-qa-2026-05-16/`

Observed result:

- the new breadcrumb **does appear** in every enabled branch:
  - `[gdgs] renderer using direct dispatch isolation for radix/boundary passes`
- runtime behavior did **not materially improve**
- `compositor`, `direct_texture_world`, `direct_texture_canvas`, and `no_present` still abort with exit code `134`
- `effect_disabled` is still the only stable branch, and it remains visually blank/background-only
- `no_present` still logs valid compositor textures plus explicit skipped writeback/presentation work, yet the process still ends with:
  - `Last known breadcrumb: BLIT_PASS`
  - `Vulkan device was lost.`

Conclusion:

- the direct-dispatch isolation patch successfully proves the new path was active, but it does **not** change the BLIT-pass failure class on this machine/backend
- visible rendering did not improve
- stability did not improve
- ownership suspicion shifts further away from GDGS' indirect-dispatch setup and further toward either another GDGS render-resource misuse or Godot/Vulkan/backend behavior on this Intel Iris Xe Wayland path
