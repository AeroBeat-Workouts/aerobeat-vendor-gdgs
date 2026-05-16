# PR draft: Fix radix push-constant packing for GDGS compute passes

_Last updated: 2026-05-16_

## Title

Fix radix push-constant packing for GDGS compute passes

## Body

Closes/references #12.

## In Plain English

This PR fixes one confirmed bug in the GDGS runtime: several radix compute passes were receiving push-constant blobs that were always padded to 16 bytes even when the shaders declared smaller exact layouts. On Vulkan validation builds, that produced push-constant size mismatches during the radix sorting path.

This change makes the radix passes send push constants that match the shader-declared sizes exactly, while keeping the existing padded helper for passes that still want 16-byte alignment.

## Summary

Issue #12 led to a deeper render-path investigation on Intel Iris Xe / Wayland / Vulkan, and that investigation exposed a concrete push-constant contract mismatch in the radix sort path.

Before this patch, GDGS packed all push constants through a helper that rounded payloads up to 16 bytes. That was fine for some passes, but the radix shaders here declare smaller contracts:

- `radix_sort_upsweep`: 8 bytes (`int radix_shift`, `int input_offset`)
- `radix_sort_spine`: 4 bytes (`int radix_shift`)
- `radix_sort_downsweep`: 12 bytes (`int radix_shift`, `int input_offset`, `int output_offset`)

Sending a shared padded 16-byte blob to all three passes violates those declared layouts and triggered validation errors.

## What changed

- added `create_exact_push_constant()` alongside the existing padded helper in `gaussian_rendering_device_context.gd`
- updated the radix dispatch loop in `gaussian_renderer.gd` so each radix pass receives only the fields and byte size it actually declares
- left the existing padded helper in place for the other code paths that still use 16-byte-aligned payloads

## Scope / non-goals

This PR is intentionally narrow.

It fixes the confirmed radix push-constant contract mismatch discovered during issue #12 investigation. It does **not** claim to resolve the later `BLIT_PASS` / device-loss crash seen in the same broader repro path.

## Validation

Local validation on the investigation branch showed that the previous Vulkan validation push-constant errors for the radix path disappeared once these exact-size payloads were used.

This upstream-prep branch is a clean replay of only the runtime-code fix:

- `addons/gdgs/runtime/render/gaussian_renderer.gd`
- `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`

## Checklist

- [x] scope limited to the confirmed radix push-constant bug
- [x] references upstream issue #12
- [x] avoids claiming the later BLIT/device-loss crash is fixed
