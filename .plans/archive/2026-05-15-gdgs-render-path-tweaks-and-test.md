# GDGS Render-Path Tweaks and Test Matrix

**Date:** 2026-05-15  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Plan and execute a narrow tweak-and-test slice against the GDGS vendor control path to identify whether specific compositor/render-path changes alter the current crash-or-blank boundary on this machine.

---

## Overview

We now have the answer to the high-level suspicion question: the vendor-literal GDGS happy path reproduces the same runtime boundary as the AeroBeat-integrated path. That means the next move should not be broad wrapper debugging. Instead, we should stay in the vendor lane and make small, evidence-driven tweaks around the compositor/render path to see whether any specific internal path changes the result on this Intel Iris Xe setup.

This slice should remain disciplined. We do not want a random walk through the plugin. We want a short candidate list, tied to the actual files involved in the repro path, and a repeatable test matrix against the existing vendor control scene. The desired outcome is one of three honest states: a narrow workaround/fix, a stronger isolation of the failing sub-path, or a sharper upstream bug report package.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Vendor happy-path control-scene slice that proved the README-literal setup reproduces the same backend boundary | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-15-gdgs-happy-path-control-scene.md` |
| `REF-02` | Vendor control scene commit used as the baseline | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/gdgs_happy_path_control.tscn` |
| `REF-03` | Primary compositor script on the failing path | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd` |
| `REF-04` | Core renderer implementation on the failing path | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_renderer.gd` |
| `REF-05` | Render manager / lifetime layer for the failing path | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_render_manager.gd` |
| `REF-06` | Existing vendor QA artifacts showing Forward+ crash and GL blank behavior | `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/` |
| `REF-07` | Existing AeroBeat repro evidence used for comparison | `/home/derrick/.openclaw/workspace/.temp/aerobeat-qa/results/` |

---

## Tasks

### Task 1: Identify the smallest sane tweak matrix

**Bead ID:** `oc-nln`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Read the control-scene findings and inspect the GDGS compositor/render-path files. Produce a short, evidence-based matrix of the smallest worthwhile tweaks or instrumentation points to test next. Prefer things that isolate sub-paths cleanly: compositor on/off branches, debug view modes, composite/blit-path toggles, depth-composition bypass, or narrow instrumentation that proves where the crash/blank path occurs. Do not propose a sprawling rewrite. Claim the assigned bead on start and close it if the matrix is complete.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/compositor/shaders/gaussian_composite.glsl`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_renderer.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_render_manager.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/gdgs_happy_path_control.tscn`

**Status:** ✅ Complete

**Results:** The tweak matrix came back clean and narrow. Highest-priority cuts are: (1) compositor effect disabled baseline, (2) existing `DIRECT_TEXTURE` mode on Forward+ to bypass the composite writeback path, (3) existing debug-view splits (`GS_COLOR`, `GS_ALPHA`, `GS_DEPTH`, `SCENE_DEPTH`, `DEPTH_REJECT_MASK`, then `COMPOSITE`) to separate depth-independent from depth-dependent failure branches, (4) one new boolean to bypass scene-depth usage during composite, and (5) minimal once-per-run stage logging around manager lookup, `render_for_compositor()`, texture validity, dispatch start, and chosen mode/debug flags. Research conclusion: GL Compatibility is mostly a negative control because the compositor has no `RenderingDevice`; the useful work is in the Forward+ compositor/render path. Recommended minimum coder set: wire the existing toggles into a small harness, add the one depth-bypass flag, and add thin logging—no architecture rewrite. References validated: `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`. 

---

### Task 2: Implement the chosen tweak switches and test harness support

**Bead ID:** `oc-ep0`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Using the approved tweak matrix, implement the smallest practical set of toggleable changes or instrumentation in the vendor control path so QA can run an apples-to-apples matrix on this machine. Keep the control scene and docs truthful. Prefer small switches and observability over speculative permanent fixes. Claim the assigned bead on start, run relevant validation, and commit/push before handoff unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/gdgs_tweak_matrix_harness.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/gdgs_happy_path_control.tscn`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/build_control_scene.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/render-path-tweak-matrix.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/happy-path-control-scene.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/compositor/shaders/gaussian_composite.glsl`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_renderer.gd`

**Status:** ✅ Complete

**Results:** Implemented the approved minimum tweak harness without rewriting the architecture. The control scene now has a small live harness with keyboard controls for compositor effect enable/disable, display-mode cycling (`Compositor` / `Direct Texture`), debug-view cycling, and a new `ignore_scene_depth_in_composite` toggle. The compositor effect now exposes that new boolean and logs once-per-run state around callback entry, manager lookup, empty vs valid compositor render results, and dispatch start; the renderer adds one sparse render-target-prepared log. Docs were added/updated so QA has a repeatable matrix flow. Validation passed for scene regeneration, headless import, and short smoke load. Commit pushed: `5a707c8` (`Add GDGS render-path tweak harness`). Caveat intentionally left for QA: the full desktop/Vulkan matrix still needs to be run on the real renderer path, and once-per-run logs are intentionally sparse so fresh runs are best when comparing first-hit stages. References validated: `REF-02`, `REF-03`, `REF-04`, `REF-05`. 

---

### Task 3: Run the tweak matrix on the real machine/backend

**Bead ID:** `oc-85i`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Run the implemented tweak matrix against the vendor control scene on this actual machine/backend. Capture which tweaks still crash, which stay blank, and whether any narrow path changes behavior. Record logs and artifacts in a durable temp folder. Claim the assigned bead on start and close it only when the matrix is complete.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/run_summary.tsv`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/effect_disabled.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/direct_texture.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/gs_alpha.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/gs_color.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/gs_depth.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/scene_depth.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/depth_reject_mask.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/composite.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/composite_ignore_scene_depth.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/logs/`

**Status:** ✅ Complete

**Results:** QA ran the full tweak matrix on the real Wayland/Vulkan desktop path with fresh processes per branch so the once-per-run logs stayed meaningful. The result is decisive: disabling the compositor effect is the only branch that avoids the crash, but it still yields a blank/black scene with only HUD visible. Every enabled branch—`DIRECT_TEXTURE`, all compositor debug views (`GS_ALPHA`, `GS_COLOR`, `GS_DEPTH`, `SCENE_DEPTH`, `DEPTH_REJECT_MASK`), normal `COMPOSITE`, and `COMPOSITE` with `ignore_scene_depth_in_composite=true`—still produced a black first frame and then aborted with Vulkan device loss. The sparse logs prove the failure is not in manager lookup or texture production: the callback is entered, the manager is found, valid compositor textures are produced, and the compositor dispatch path is reached where applicable. Because even depth-independent branches fail the same way and the scene-depth bypass did not help, the fault boundary is now tighter: on this Intel Iris Xe / Wayland / Vulkan Forward+ path, GDGS can prepare compositor textures, but once the enabled render/composite presentation path is engaged the frame stays black and the device is lost around/after the `BLIT_PASS` stage. References validated: `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`. 

---

### Task 4: Audit the tweak results and decide the next escalation path

**Bead ID:** `oc-dnm`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Independently audit the tweak matrix results. Decide whether we found a real narrow workaround/fix, a sharper fault boundary, or simply stronger evidence for an upstream bug report. Claim the assigned bead on start and close it only if the next move is evidence-backed and unambiguous.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-15-gdgs-render-path-tweaks-and-test.md`

**Status:** ✅ Complete

**Results:** Independent audit passed. Commit `5a707c8` stayed narrow and did exactly what this slice needed: it added toggleable compositor/debug branches, one scene-depth bypass flag, and sparse logging without rewriting the plugin. QA evidence confirmed there is no meaningful workaround in this matrix: `effect_disabled` is the only stable branch and it produces only a blank/flat scene, while every enabled branch (`DIRECT_TEXTURE`, all debug views, normal composite, and composite with scene-depth bypass) still aborts with the same `BLIT_PASS` / `Vulkan device was lost` boundary. The logs prove manager lookup succeeds, compositor textures are valid, and enabled branches reach dispatch/presentation-adjacent work before failure. That means the slice genuinely answered the intended question and sharpened the fault boundary to the enabled render/composite presentation path rather than wrapper setup, manager lookup, or scene-depth logic alone. References validated: `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`. 

---

## Final Results

**Status:** ✅ Complete

**What We Built:** We built and tested a narrow GDGS vendor-side tweak harness around the happy-path control scene so we could cut the failing render/compositor path into small, evidence-bearing branches. The harness proved that no tested narrow tweak produced a visible stable splat on this machine/backend. Disabling the compositor effect avoids the crash but only leaves a stable blank scene; every enabled path still goes black and then dies with the same Vulkan device-loss boundary.

**Reference Check:** `REF-01` remained the baseline proof that the vendor happy-path control scene was already valid before tweaks. `REF-03`, `REF-04`, and `REF-05` were the right core files to instrument, and the resulting evidence now shows the failure is not in broad wrapper setup, manager lookup, or scene-depth logic alone. `REF-06` and `REF-07` stayed consistent with the new matrix results: vendor and AeroBeat both converge on the same `BLIT_PASS`-adjacent device-loss boundary.

**Commits:**
- `5a707c8` - `Add GDGS render-path tweak harness`

**Lessons Learned:** Small branch-cut experiments are the right move when a render path is failing inside a plugin/runtime boundary. In this case, the matrix was valuable not because it found a workaround, but because it proved valid compositor textures exist before failure and eliminated several plausible wrong theories. The next useful move is an upstream-quality minimal repro/report or a very narrow investigation around presentation/writeback mechanics near `BLIT_PASS` on Intel Iris Xe + Wayland + Vulkan Forward+.

---

*Completed on 2026-05-15*
