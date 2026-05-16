# GDGS Radix Push-Constant Contract

Date: 2026-05-16  
Branch: `test/oc-xok-gdgs-radix-push-constant-contract`

## Purpose

Document the exact push-constant contract used by the GDGS radix compute passes and identify the narrowest safe plugin-side fix lane before any runtime behavior change.

## Exact shader-declared contract

All three radix shaders declare a `layout(push_constant) uniform PushConstant` block made only of 32-bit scalars. In this case the reflected push-constant byte count is the declared scalar count × 4 bytes.

### `radix_sort_spine.glsl`

Source:
- `addons/gdgs/runtime/render/shaders/compute/radix_sort_spine.glsl:28-30`

Declared fields:
- `int pass`

Exact payload:
- 1 × 32-bit scalar
- expected byte count: **4 bytes**

### `radix_sort_upsweep.glsl`

Source:
- `addons/gdgs/runtime/render/shaders/compute/radix_sort_upsweep.glsl:28-31`

Declared fields:
- `int pass`
- `uint in_offset`

Exact payload:
- 2 × 32-bit scalars
- expected byte count: **8 bytes**

### `radix_sort_downsweep.glsl`

Source:
- `addons/gdgs/runtime/render/shaders/compute/radix_sort_downsweep.glsl:34-38`

Declared fields:
- `int pass`
- `uint in_offset`
- `uint out_offset`

Exact payload:
- 3 × 32-bit scalars
- expected byte count: **12 bytes**

## Current GDGS send path

### Shared padded blob construction

`gaussian_renderer.gd` currently constructs one radix push-constant blob per shift pass and reuses it for all three radix pipelines:

- `addons/gdgs/runtime/render/gaussian_renderer.gd:93-101`

Current data array:
- `radix_shift_pass`
- `point_count * MAX_SORT_ELEMENTS_PER_SPLAT * (radix_shift_pass % 2)`
- `point_count * MAX_SORT_ELEMENTS_PER_SPLAT * (1 - (radix_shift_pass % 2))`

That is 3 × 32-bit scalars = 12 bytes of logical data.

### Global helper padding

`gaussian_rendering_device_context.gd` currently pads every push-constant payload to the next 16-byte boundary:

- `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd:127-142`

So the shared radix blob becomes:
- logical data: 12 bytes
- transmitted size: **16 bytes**

### Dispatch behavior

The compute pipeline wrapper forwards the exact `PackedByteArray.size()` to Godot's RenderingDevice:

- `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd:117-118`

So today the actual radix dispatch sizes are:
- `radix_sort_upsweep`: **16 bytes sent**, shader expects **8 bytes**
- `radix_sort_spine`: **16 bytes sent**, shader expects **4 bytes**
- `radix_sort_downsweep`: **16 bytes sent**, shader expects **12 bytes**

## Where GDGS is mis-sending bytes

There are two coupled problems in the current radix path:

1. **Shape reuse across distinct pipelines**  
   `gaussian_renderer.gd` reuses one 3-field payload for all radix stages even though `spine`, `upsweep`, and `downsweep` declare different push-constant layouts.

2. **Unconditional 16-byte padding**  
   `RenderingDeviceContext.create_push_constant()` always rounds payloads up to a 16-byte boundary, which turns the shared radix blob into 16 bytes even when the shader contract is 4, 8, or 12 bytes.

The combination explains the Godot 4.7-dev5 validation expectations of 4 / 8 / 12 bytes and the current plugin behavior of always sending 16.

## Narrowest safe fix shape

Do not globally rewrite every push-constant call site first. The smallest safe lane is:

1. keep the existing compute pipeline wrapper behavior of sending `push_constant.size()` bytes;
2. keep the existing padded helper available for call sites that already match their shader contract;
3. change only the radix call site so each pipeline receives its own exact payload:
   - `spine`: `[radix_shift_pass]` -> 4 bytes
   - `upsweep`: `[radix_shift_pass, in_offset]` -> 8 bytes
   - `downsweep`: `[radix_shift_pass, in_offset, out_offset]` -> 12 bytes
4. implement that via either:
   - a new exact-size helper for scalar arrays used only by the radix passes, or
   - a helper option that disables 16-byte padding for explicitly exact contracts.

## Why this is the safest first fix

Other GDGS compute passes currently appear to align with their declared contracts:
- camera matrices for `gsplat_projection` are 32 floats = 128 bytes
- `gsplat_render` uses 4 scalars = 16 bytes
- the uniform staging blob in `gaussian_renderer.gd:72-80` is not a push-constant dispatch payload

So the highest-confidence, lowest-blast-radius change is to narrow the fix to the radix passes instead of changing all push-constant packing behavior at once.

## Practical implementation target

Primary files for the future code fix lane:
- `addons/gdgs/runtime/render/gaussian_renderer.gd`
- `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd` (only if an exact-size helper or helper flag is needed)

## Implementation landed on 2026-05-16

The targeted contract fix now exists on branch `test/oc-xok-gdgs-radix-push-constant-contract`:

- `gaussian_rendering_device_context.gd` keeps the existing padded `create_push_constant()` behavior for legacy call sites, but now routes through a shared packer and exposes `create_exact_push_constant()` for exact-size dispatches.
- `gaussian_renderer.gd` now sends distinct radix payloads per pass instead of one shared 3-field blob:
  - `radix_sort_spine` -> `[radix_shift_pass]` -> 4 bytes
  - `radix_sort_upsweep` -> `[radix_shift_pass, radix_input_offset]` -> 8 bytes
  - `radix_sort_downsweep` -> `[radix_shift_pass, radix_input_offset, radix_output_offset]` -> 12 bytes

Local validation for this implementation pass was a headless Godot import/register run:
- `~/.local/bin/godot --import --headless --path /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`

That validation confirms the touched GDGS scripts still register cleanly; 4.7-dev5 runtime verification remains the next QA lane.

## 4.7-dev5 QA result on 2026-05-16

Real-machine QA was rerun on the same Surface Pro 8 Wayland / Vulkan path using the existing control-scene repro harness and the same Godot 4.7-dev5 binary previously captured in `REF-04`'s artifact bundle.

Artifact folder:
- `/home/derrick/.openclaw/workspace/.temp/gdgs-push-constant-fix-qa-2026-05-16-dev5/`

What changed versus the prior 4.7-dev5 baseline:
- the repeated radix `compute_list_set_push_constant()` validation errors are gone
- the repeated follow-on `compute_list_dispatch()` missing-push-constant errors are gone

What did not change:
- case matrix stayed the same:
  - `compositor` -> exit `134`
  - `effect_disabled` -> exit `0`
  - `direct_texture_world` -> exit `134`
  - `direct_texture_canvas` -> exit `134`
  - `no_present` -> exit `134`
- enabled crashing modes still produce valid compositor textures before failure
- `no_present` still logs that it captured valid compositor textures and skipped all writeback/presentation work
- Godot still ends at `Last known breadcrumb: BLIT_PASS`
- Godot still reports `Vulkan device was lost.`
- visible rendering did not improve
- stability did not improve

QA conclusion:
- this fix removes one confirmed GDGS push-constant contract violation on Godot 4.7-dev5
- the later BLIT-pass / device-loss failure remains
- the bug is therefore materially narrowed, but not resolved, and still points at either a later GDGS render-resource misuse or Godot/backend ownership beyond the removed push-constant mismatch
