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
- source files only if instrumentation is needed
- investigation notes/docs as needed

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Implement the narrowest plausible fix in the owning lane

**Bead ID:** `oc-92a`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Using the culprit shortlist, implement the narrowest plausible fix in the correct ownership lane. If the best target is the vendored GDGS source, patch it on the investigation branch. If the best target is a lower-level dependency, stop and document the owning repo/fork/branch strategy instead of forcing a speculative fix into the vendor repo. Claim the assigned bead on start, run relevant validation, commit the branch work before handoff unless blocked, and report exactly what changed and why.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- possibly another owning dependency repo if identified

**Files Created/Deleted/Modified:**
- targeted source files in the actual owning codebase
- docs/notes as needed

**Status:** ⏳ Pending

**Results:** Pending.

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
- new QA artifact folders/logs/images/summaries as needed

**Status:** ⏳ Pending

**Results:** Pending.

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

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Draft

**What We Built:** Pending execution.

**Reference Check:** Pending.

**Commits:**
- Pending.

**Lessons Learned:**
- Keep the vendor repo as the first concrete patch lane, but don’t confuse “where we can test quickly” with “what code actually owns the bug.”
- Branch-based investigation is the safest shape for this slice because success may need to turn into an upstream PR or a dependency-fork handoff.

---

*Completed on Pending*
