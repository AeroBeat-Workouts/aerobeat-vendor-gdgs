# GDGS Happy-Path Control Scene

**Date:** 2026-05-15  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Create a vendor-lane control scene that follows the upstream GDGS README happy path as literally as practical, verify whether that path works on this machine, and use it as the comparison baseline against the AeroBeat-integrated path.

---

## Overview

The previous renderer-path slice successfully truth-locked AeroBeat product behavior, but it did not resolve the underlying visible-render problem. Derrick’s correction is the right next move: before more guessing, we should build a clean control surface that does exactly what the upstream GDGS README says to do and test the plugin under its own intended setup.

The upstream README for the pinned GDGS version (`2.2.0`, commit `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`) is explicit: the happy path requires Godot 4.4+, the `Forward Plus` renderer, a desktop GPU with compute support, a `GaussianSplatNode`, a `WorldEnvironment`, a `Compositor` on that `WorldEnvironment`, and a `CompositorEffect` using `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`. This slice should build a minimal scene that mirrors those instructions exactly, validate it with the bundled sample assets where possible, and only then compare it against the current AeroBeat wrapper/testbed path to isolate the difference.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Upstream GDGS README happy-path instructions at the pinned vendor commit | `https://raw.githubusercontent.com/ReconWorldLab/godot-gaussian-splatting/be61f8fd28cc9cb4a618a0a2e88591ea81bb17be/README.md` |
| `REF-02` | Vendor lane repo that pins the upstream plugin payload | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/` |
| `REF-03` | Existing AeroBeat environment-community repro harness and captured outputs | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/repros/oc-c3u/` |
| `REF-04` | Existing AeroBeat renderer-path slice plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/.plans/2026-05-15-splat-renderer-path-debug.md` |

---

## Tasks

### Task 1: Build a literal GDGS happy-path control scene

**Bead ID:** `oc-rwh`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`  
**Prompt:** Create a minimal control scene inside `aerobeat-vendor-gdgs` that follows the upstream README quick-start path as literally as practical: sample asset import, `GaussianSplatNode`, `WorldEnvironment`, `Compositor`, and `CompositorEffect` using the documented GDGS script path. Keep this as a vendor-lane control, not an AeroBeat wrapper scene. Claim the assigned bead on start, run relevant validation, and commit/push before handoff unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/project.godot`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/gdgs_happy_path_control.tscn`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/build_control_scene.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/happy-path-control-scene.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/samples/assets/*.import`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/**/*.uid`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/**/**/*.import`

**Status:** ✅ Complete

**Results:** Built a vendor-lane control project and scene that closely mirrors the upstream README happy path. It uses the vendored plugin at `res://addons/gdgs`, the bundled sample asset `res://samples/assets/demo.compressed.ply`, a `GaussianSplatNode`, `WorldEnvironment`, `Compositor`, and a `CompositorEffect` scripted exactly from `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`. Only minimal usability extras were added: `Camera3D`, `DirectionalLight3D`, and a small HUD label. Validation passed for headless import, scene generation, and smoke run. Commit pushed: `366c3cb` (`Add GDGS vendor happy-path control scene`). Caveat intentionally left for QA: this coder pass proves happy-path setup/build shape, not visible desktop rendering. References validated: `REF-01`, `REF-02`. 

---

### Task 2: Verify the happy path on the actual machine/backend

**Bead ID:** `oc-94o`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`  
**Prompt:** Verify the new vendor control scene in the highest-fidelity way available on this machine. Record exactly whether the upstream-documented Forward+ happy path visibly works, crashes, or partially works. Use the same machine/backend assumptions as the AeroBeat repro so the comparison is meaningful. Claim the assigned bead on start and close it only if verification is complete.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/forward_plus/godot.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/forward_plus/stdout.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/gl_compatibility/godot.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/gl_compatibility/stdout.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/gl_compatibility/frame00000010.png`

**Status:** ✅ Complete

**Results:** QA confirmed the vendor control scene really does match the upstream README happy-path shape, but the happy path still fails on this actual machine/backend. On Forward+ desktop/Vulkan, the vendored control scene crashes with the same `BLIT_PASS` / `Vulkan device was lost` boundary already seen in the AeroBeat repro; no visible frame output was produced there. On GL Compatibility, the scene runs and records frames, but the captured output is blank/background-only for the splat, matching the already-known non-visible path. This is not a meaningful behavioral divergence from the AeroBeat repro: the vendor-literal scene and the AeroBeat path converge on the same runtime truth, which strongly narrows the fault boundary to the GDGS compositor/render path on this machine/backend rather than AeroBeat wrapper wiring. References validated: `REF-01`, `REF-02`, `REF-03`. 

---

### Task 3: Compare happy path vs AeroBeat path and isolate the delta

**Bead ID:** `oc-seh`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`  
**Prompt:** Independently compare the vendor happy-path control scene against the AeroBeat repro path and isolate the narrowest real delta: scene setup, plugin wiring, renderer assumptions, wrapper behavior, asset pathing, or confirmed upstream/plugin instability. Claim the assigned bead on start. Close the bead only if the comparison is evidence-backed and the next engineering move is unambiguous.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-15-gdgs-happy-path-control-scene.md`

**Status:** ✅ Complete

**Results:** Independent audit passed. The vendor control scene built in commit `366c3cb` is structurally consistent with the upstream GDGS README happy path: vendored plugin at `res://addons/gdgs`, sample asset in-project, `GaussianSplatNode`, `WorldEnvironment`, `Compositor`, and a `CompositorEffect` scripted from `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`. QA evidence confirmed that this vendor-literal path still reproduces the same effective runtime boundary as the AeroBeat repro on this machine/backend: Forward+ / Vulkan crashes with `BLIT_PASS` / `Vulkan device was lost`, while GL Compatibility runs but yields blank/background-only splat output. No meaningful delta remains that points to broad AeroBeat wrapper suspicion; both paths converge on the same GDGS/runtime/backend fault boundary. The next engineering move is therefore to debug the narrower upstream render/compositor/backend path rather than re-questioning the wrapper at a high level. References validated: `REF-01`, `REF-02`, `REF-03`, `REF-04`. 

---

## Final Results

**Status:** ✅ Complete

**What We Built:** We built a vendor-lane GDGS control project and happy-path scene that follows the upstream README setup as literally as practical, then verified it on this actual machine/backend. That control scene proved the key question: even the README-literal vendor path reproduces the same failure boundary already seen in AeroBeat, so the broad wrapper-suspicion branch is no longer the leading theory.

**Reference Check:** `REF-01` was satisfied by the control scene structure and usage flow. `REF-02` now contains a durable vendor control surface for future repro/debug work. `REF-03` and `REF-04` were successfully used as comparison baselines, and the vendor path converged on the same effective boundary rather than exposing a meaningful integration-specific delta.

**Commits:**
- `366c3cb` - `Add GDGS vendor happy-path control scene`

**Lessons Learned:** When plugin integration is under suspicion, the fastest way to collapse uncertainty is to build the plugin author’s literal happy path and compare outcomes on the same hardware/backend. Here, that control removed broad wrapper suspicion and sharpened the next move toward narrower GDGS/Godot render-path debugging on this Intel Iris Xe setup.

---

*Completed on 2026-05-15*
