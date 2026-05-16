# AeroBeat Vendor - GDGS Source-Level BLIT-Pass Investigation

**Date:** 2026-05-16  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Investigate the remaining GDGS render/backend failure at the source level, using a branch-based workflow that supports rapid local iteration, and determine whether the fix belongs in `aerobeat-vendor-gdgs` itself or in one of its underlying libraries/dependencies.

---

## Overview

Yesterday’s work narrowed the failure substantially: the GDGS path reaches valid compositor texture production, but every enabled presentation/composite branch still converges on the same black-frame + Vulkan device-loss boundary near `BLIT_PASS`. The wrapper compositor-persistence bug is already fixed, and the async loader/progress work is closed. The unresolved surface is now source-level render/backend behavior.

Your caution is right: `aerobeat-vendor-gdgs` is a vendor clone/fork of the original GDGS repo, not the whole universe of code involved in the failure. That means this slice should treat the vendor repo as the first practical inspection and patch lane, while explicitly mapping any lower-level libraries or engine/plugin boundaries it relies on. If the root cause turns out to live below the vendor repo, we should identify the owning dependency repo, fork/branch there if needed, and prepare the corresponding issue/PR package against that true owner instead of forcing a bad fix into the vendor mirror.

Execution should stay branch-based. We want a clean experimental branch for the source investigation and patch attempts so we can iterate safely, compare diffs cleanly, run real-machine validation repeatedly, and only later decide whether the successful change should become an upstream PR against GDGS, a PR against a deeper dependency, or an issue package if no safe fix is ready.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Vendor repo README / ownership boundary | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/README.md` |
| `REF-02` | Prior upstream issue draft and narrowed evidence | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/upstream-issue-draft.md` |
| `REF-03` | Archived happy-path control scene plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/archive/2026-05-15-gdgs-happy-path-control-scene.md` |
| `REF-04` | Archived tweak-matrix plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/archive/2026-05-15-gdgs-render-path-tweaks-and-test.md` |
| `REF-05` | Archived upstream issue + BLIT-pass narrowing plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/archive/2026-05-15-gdgs-upstream-issue-package-and-blit-pass.md` |
| `REF-06` | Prior real-machine QA artifacts | `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/` |
| `REF-07` | Vendored plugin source tree under investigation | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/` |

---

## Tasks

### Task 1: Establish the investigation lane and dependency map

**Bead ID:** `oc-0o7`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-05`, `REF-07`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`, create or switch to a dedicated investigation branch for this BLIT-pass/source-level debugging slice, inspect the vendored GDGS source layout, and map the likely ownership boundaries involved in the failure. Identify which parts of the failing path are in the vendored repo versus Godot engine APIs or any deeper libraries/dependencies. Claim the assigned bead on start and close it only when the branch strategy and dependency/ownership map are documented clearly enough to guide patch work.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-source-level-blit-pass-investigation.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-blit-pass-ownership-map.md`

**Status:** ✅ Complete

**Results:** Claimed `oc-0o7`, created investigation branch `research/oc-0o7-gdgs-ownership-map`, and mapped the actual ownership/dependency boundaries for the current `BLIT_PASS` / device-loss bug. What actually turned up: `addons/gdgs/` is a pure vendored upstream plugin payload from `ReconWorldLab/godot-gaussian-splatting` (pin `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`), with the likely first fix surface concentrated in `runtime/compositor/` and `runtime/render/` rather than in the importer/editor paths. The plugin owns the GDScript/shader orchestration, texture allocation, descriptor binding, compositor callback logic, and any misuse of Godot rendering APIs; Godot itself owns the underlying `CompositorEffect` / `RenderingDevice` / `RenderSceneBuffersRD` / Vulkan backend behavior and the engine-side `BLIT_PASS` boundary. No deeper bundled runtime dependency was found in this repo: no submodules, no GDExtension/native code, no extra library layer between GDGS and Godot. Supporting notes were added in `docs/gdgs-blit-pass-ownership-map.md`. Current call: investigate/patch inside the vendored GDGS lane first, but if the plugin-side usage looks valid, the next owning lane is likely a Godot/backend fork or upstream issue update rather than another third-party dependency repo. References checked: `REF-01`, `REF-02`, `REF-05`, `REF-07`.

---

### Task 2: Trace the failing source path near BLIT_PASS

**Bead ID:** `oc-io5`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Starting from the narrowed evidence, inspect the vendored GDGS source path that leads to compositor texture production and the later failure boundary near `BLIT_PASS`. Correlate the existing logs and control-scene evidence to specific source files, methods, and backend/API calls. Produce a concise culprit shortlist with the smallest plausible patch targets, and explicitly call out whether each candidate belongs in the vendor repo or below it. Claim the assigned bead on start and close it only when the trace and culprit shortlist are evidence-backed.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-source-level-blit-pass-investigation.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-blit-pass-source-trace.md`

**Status:** ✅ Complete

**Results:** Claimed `oc-io5` on the existing investigation branch `research/oc-0o7-gdgs-ownership-map`, then traced the live crash path from `GaussianCompositorEffect._render_callback()` into `GaussianRenderManager.render_for_compositor()` and `GaussianRenderer._rasterize_state()`. What actually turned up: the plugin reliably reaches the vendored compute renderer, allocates/returns valid offscreen color+depth texture RIDs, and only then later trips the engine-side Vulkan device loss with breadcrumb `BLIT_PASS`. The decisive narrowing is the `No Present` case in `REF-06`: `gaussian_compositor_effect.gd` logs that it captured valid compositor textures and skipped all script-side composite/writeback/presentation work, yet the process still dies with the same `BLIT_PASS` boundary. That demotes `runtime/compositor/shaders/gaussian_composite.glsl` from primary suspect and shifts the lead suspicion to the vendored renderer compute chain in `runtime/render/`—especially `_rasterize_state()`, its indirect-dispatch path, and the RD image/buffer setup in `gaussian_gpu_state_cache.gd` / `gaussian_rendering_device_context.gd`. A durable source-trace and culprit shortlist was added in `docs/gdgs-blit-pass-source-trace.md`, explicitly separating vendor-patch candidates from the likely next escalation lane in Godot/Vulkan backend work if one more narrow vendor isolation pass does not expose a clear misuse. References checked: `REF-02`, `REF-06`, `REF-07`. 

---

### Task 3: Implement the narrowest plausible fix in the owning lane

**Bead ID:** `oc-92a`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Using the culprit shortlist, implement the narrowest plausible fix in the correct ownership lane. If the best target is the vendored GDGS source, patch it on the investigation branch. If the best target is a lower-level dependency, stop and document the owning repo/fork/branch strategy instead of forcing a speculative fix into the vendor repo. Claim the assigned bead on start, run relevant validation, commit the branch work before handoff unless blocked, and report exactly what changed and why.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_gpu_state_cache.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_renderer.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-direct-dispatch-isolation.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-source-level-blit-pass-investigation.md`

**Status:** ✅ Complete

**Results:** Claimed `oc-92a` on `research/oc-0o7-gdgs-ownership-map` and chose the narrowest high-signal vendor-side isolation patch inside `REF-07`'s render lane rather than escalating immediately below GDGS. What actually changed: the radix-sort upsweep/downsweep passes and tile-boundary pass no longer use `compute_list_dispatch_indirect()` from the legacy `grid_dimensions` buffer. Instead, `gaussian_gpu_state_cache.gd` now bakes the same CPU-known worst-case workgroup counts directly into those pipelines (`num_partitions` for radix, `ceil(num_sort_elements_max / 256.0)` for boundaries), and `gaussian_renderer.gd` calls those pipelines with direct dispatch only. The `grid_dimensions` buffer remains allocated/bound for descriptor stability, but its `STORAGE_BUFFER_USAGE_DISPATCH_INDIRECT` flag was removed because it is no longer used as an indirect-dispatch source. This keeps the patch tight, reversible, and explicitly targeted at the strongest remaining vendor suspect from `REF-02`: indirect-dispatch / resource-usage sequencing in the renderer compute chain, not the compositor shader. Added durable notes in `docs/gdgs-direct-dispatch-isolation.md`, including the new QA log marker `[gdgs] renderer using direct dispatch isolation for radix/boundary passes`. Validation run: `~/.local/bin/godot --import --headless --path /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`, which completed successfully and re-registered the touched GDGS classes without script parse errors. This is best treated as a high-signal isolation pass, not yet a confirmed end-user fix; QA still needs to rerun the real-machine control-scene workflow from `REF-06` to determine whether the `BLIT_PASS` device-loss changes class or survives unchanged. References checked: `REF-02`, `REF-06`, `REF-07`.

---

### Task 4: QA the fix or branch conclusion on the real machine

**Bead ID:** `oc-c0q`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Validate the current branch state on the real Surface Pro 8 Wayland/Vulkan machine using the existing control-scene and artifact workflow. Confirm whether the failure class changed, whether a visible splat renders, whether stability improved, or whether the current branch only clarified ownership without a working fix. Claim the assigned bead on start and close it only when the result is captured clearly enough for audit.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/.temp/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/.temp/gdgs-direct-dispatch-qa-2026-05-16/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-source-level-blit-pass-investigation.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-direct-dispatch-isolation.md`

**Status:** ✅ Complete

**Results:** QA reran the exact prior `REF-06` control-scene BLIT-pass case flow on the real Surface Pro 8 Wayland/Vulkan machine, but on branch `research/oc-0o7-gdgs-ownership-map` at commit `5797bd8bdb59a191915421a8728ce14f3ebed5ba`, with fresh artifacts captured under `/home/derrick/.openclaw/workspace/.temp/gdgs-direct-dispatch-qa-2026-05-16/`. The new direct-dispatch breadcrumb appeared in every enabled branch (`[gdgs] renderer using direct dispatch isolation for radix/boundary passes`), proving the isolation patch was truly active on the tested runtime path. Despite that, the failure class did not materially change: `compositor`, `direct_texture_world`, `direct_texture_canvas`, and `no_present` all still aborted with exit code `134`, still logged valid compositor textures, and still converged on `Last known breadcrumb: BLIT_PASS` followed by `Vulkan device was lost.` `effect_disabled` remained the only stable branch and still produced the same blank/background-only output as the prior baseline; its JSON metrics matched `REF-06` exactly. Visible rendering did not improve, stability did not improve, and the decisive `no_present` boundary survived unchanged even with the new direct-dispatch isolation active. This weakens the case that GDGS indirect-dispatch setup was the owner of the crash and shifts suspicion further toward either another GDGS render-resource misuse or Godot/Vulkan/backend ownership on this Intel Iris Xe / Wayland path. References checked: `REF-05`, `REF-06`, `REF-07`.

---

### Task 5: Audit the ownership decision and upstream/fork next move

**Bead ID:** `oc-ldx`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Independently audit the branch work, source trace, patch target, and QA result. Decide whether the current evidence supports: (a) an upstream PR against GDGS, (b) a fork/issue/PR against a deeper dependency, (c) an upstream issue update only, or (d) another narrowly-scoped investigation pass. Claim the assigned bead on start and close it only when the ownership decision and next move are unambiguous.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-source-level-blit-pass-investigation.md`
- supporting docs/notes as needed

**Status:** ✅ Complete

**Results:** Independent audit of the branch work, source trace, direct-dispatch isolation patch, and fresh `REF-06`-style QA artifacts found that the new isolation pass was real but not materially curative. The branch commit `5797bd8bdb59a191915421a8728ce14f3ebed5ba` cleanly removes GDGS indirect dispatch from the radix/boundary passes, and QA proved that path was active via the new breadcrumb (`[gdgs] renderer using direct dispatch isolation for radix/boundary passes`) in every crashing enabled mode. Despite that, `compositor`, `direct_texture_world`, `direct_texture_canvas`, and `no_present` still reproduced the same exit `134` / `Last known breadcrumb: BLIT_PASS` / `Vulkan device was lost.` boundary, while `effect_disabled` remained the only stable-but-blank baseline. The decisive audit call is that the direct-dispatch isolation pass did **not** materially change the failure class, so GDGS indirect-dispatch setup is no longer a strong owner candidate. That weakens the case for another hand-wavy vendor pass or an upstream GDGS PR based on the current patch. Best-supported next owner lane is now **Godot/backend escalation** with the existing GDGS upstream issue updated to include the negative isolation result and source-trace narrowing. A further vendor-side pass would only be justified if it is extremely narrow and specifically targets another concrete GDGS render-resource misuse hypothesis (for example, texture usage/format or resource-lifetime hazards), but the present evidence no longer makes that the default next move. References checked: `REF-01`, `REF-02`, `REF-05`, `REF-06`, `REF-07`.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** We completed a source-level ownership investigation on branch `research/oc-0o7-gdgs-ownership-map`, documented the vendor-vs-engine boundary, traced the live crash path into GDGS' compute renderer, landed one narrow vendor-side isolation patch that removes indirect dispatch from the radix/boundary passes, and reran the real-machine QA harness against that branch. The key outcome is not a user-facing fix but an ownership decision: the direct-dispatch isolation was active and still left the exact same `BLIT_PASS` / Vulkan device-loss failure class in place, including the decisive `no_present` branch that skips GDGS script-side presentation work.

**Reference Check:** `REF-01` confirmed this repo is only the vendor lane. `REF-02`, `REF-05`, and `REF-07` supported the source-level ownership and trace work inside GDGS. `REF-06` and the new `/home/derrick/.openclaw/workspace/.temp/gdgs-direct-dispatch-qa-2026-05-16/` artifact set showed that the isolation patch did not materially change runtime behavior. Taken together, the evidence no longer strongly supports a GDGS PR from the current patch. It best supports a Godot/backend escalation lane, while updating the existing GDGS upstream issue with the new negative-isolation evidence.

**Commits:**
- `3b94cc7` - `docs: map gdgs blit-pass ownership boundary`
- `2cd6d27` - `docs: trace gdgs blit-pass failure path`
- `5797bd8` - `Isolate GDGS render path from indirect dispatch`

**Lessons Learned:**
- A narrow vendor-side isolation patch can still be valuable even when it fails, because a clean null result materially sharpens ownership.
- The decisive question was whether removing GDGS indirect dispatch changed the failure class; it did not.
- Unless a new, concrete GDGS misuse hypothesis appears, the next serious investigation should move below the vendor repo into Godot/backend territory rather than spending more cycles on broad plugin-side poking.

---

*Completed on 2026-05-16*
