# AeroBeat Vendor GDGS

**Date:** 2026-05-29  
**Status:** In Progress  
**Last Updated:** 2026-05-29 11:34 EDT  
**Blocked Reason:** None  
**Agent:** `cookie`

---

## Goal

Repair the `aerobeat-vendor-gdgs` testbed so Godot can import and validate the scene/resources again after the repo refactor, and verify AeroBeat template `.gitignore` coverage for generated GodotEnv `.testbed` addon state.

---

## Overview

The current failure appears to be import-time path validation inside the hidden `.testbed` project rather than a runtime-only bug. The screenshot shows Godot failing to preload several GDGS runtime scripts and related shader resources from `res://addons/gdgs/...` and `res://addons/aerobeat-vendor-gdgs/...`, which suggests the refactor left stale paths, stale generated addon state, or a broken owner/consumer boundary in the testbed.

There is already one confirmed repo hygiene mismatch: this repo’s `.gitignore` does not ignore generated GodotEnv workbench state under `.testbed/addons/` and `.testbed/.addons/`, while the current AeroBeat vendor/template pattern does. That means part of the repair likely includes restoring canonical ignore coverage here, and possibly deciding whether broader template propagation belongs in this same slice or a follow-up plan.

The plan is to first reproduce and inventory the broken references, then repair the owning source/testbed configuration in the real repo rather than patching generated addon copies. In parallel with that repo-local hygiene repair, we will audit the `aerobeat-template-*` repos to make sure their `.gitignore` files still carry the canonical GodotEnv workbench ignores. Most templates should ignore `.testbed/addons/*`, keep the `.editorconfig` exception, and ignore `.testbed/.addons/`; `aerobeat-template-assembly` is a deliberate exception where the generated GodotEnv workbench lives at the repo root, so its ignore coverage should target `/addons/` and `/.addons/` at the root instead. After the fix lands, we’ll run the normal coder → QA → auditor loop: implementation and repo-local validation, testbed import verification in Godot, then an independent truth-check before closing the work.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | User-provided import failure screenshot/log snippet | `/home/derrick/.openclaw/workspace/.temp/nerve-uploads/2026/05/29/image-52c92eb4.png` |
| `REF-02` | Hidden testbed Godot project that must import cleanly | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.testbed/project.godot` |
| `REF-03` | Hidden testbed addon dependency wiring | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.testbed/addons.jsonc` |
| `REF-04` | Owning GDGS source tree | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/gdgs/` |
| `REF-05` | AeroBeat template repo `.gitignore` surfaces to audit | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-template-*/.gitignore` |

---

## Tasks

### Task 1: Reproduce and locate stale import paths

**Bead ID:** `aerobeat-vendor-gdgs-4c1`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`  
**Prompt:** Reproduce the `.testbed` Godot importer failure for bead ID TBD, claim the bead on start, inspect the broken references shown in REF-01, and identify the exact stale or invalid source/testbed paths causing import validation to fail. Do not patch generated addon copies directly; trace the fix back to the owning source/configuration and report the minimal durable change set needed.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/gdgs/`

**Files Created/Deleted/Modified:**
- Pending investigation

**Status:** ✅ Complete

**Results:** Reproduced the importer failure with `godot --headless --path .testbed --quit-after 5`. Confirmed the primary break is a testbed addon identity/path mismatch: `.testbed/addons.jsonc` currently installs the repo as `res://addons/aerobeat-vendor-gdgs/gdgs/...`, while the GDGS source hardcodes `res://addons/gdgs/...`. Also confirmed stale scene paths in `.testbed/scenes/gdgs_happy_path_control.tscn` and stale tracked `.import` metadata under `gdgs/` that still embed `res://addons/aerobeat-vendor-gdgs/gdgs/...`. Minimal durable fix: install the payload as addon identity `gdgs` from subfolder `/gdgs`, normalize the testbed scene back to `res://addons/gdgs/...`, refresh tracked import metadata, clear stale generated testbed state, then reinstall/reimport. README drift was also noted: it still documents `/addons/gdgs` while the repo payload now lives at `/gdgs`.

---

### Task 2: Apply durable fix, restore canonical ignore rules, and validate repo-locally

**Bead ID:** `aerobeat-vendor-gdgs-3hs`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`  
**Prompt:** For bead ID TBD, claim the bead on start, implement the durable fix in the owning source/testbed configuration, restore canonical ignore coverage for generated `.testbed` GodotEnv state if the repo drifted from current AeroBeat patterns, refresh generated addon state only through canonical repo workflows as needed, run relevant repo-local validation, then commit and push the fix unless the orchestrator says otherwise.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/gdgs/`

**Files Created/Deleted/Modified:**
- Pending investigation

**Status:** ✅ Complete

**Results:** Durable fix implemented and pushed in commit `cb195ad204c9c1bbc8d3c922b42d80935c5f0e9e` (`Repair GDGS testbed install identity`). Updated `.testbed/addons.jsonc` to install addon identity `gdgs` from `/gdgs`, normalized `.testbed/scenes/gdgs_happy_path_control.tscn` back to canonical `res://addons/gdgs/...` paths, refreshed 9 stale tracked `gdgs/**/*.import` files, restored `.gitignore` coverage for generated `.testbed/addons/*`, `!.testbed/addons/.editorconfig`, and `.testbed/.addons/`, and corrected `README.md` to document the repo’s real `gdgs` payload layout. Validation passed after clearing generated testbed state and reinstalling addons: `godot --import --headless --path .testbed` passed, and `godot --headless --path .testbed --script res://scripts/validate_transform_proving_surface.gd` passed with the proving-surface validation output.

---

### Task 3: Audit AeroBeat template `.gitignore` coverage

**Bead ID:** `aerobeat-vendor-gdgs-9em`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-05`  
**Prompt:** For bead ID TBD, claim the bead on start, inspect every `aerobeat-template-*` repo `.gitignore`, confirm whether it includes the correct canonical GodotEnv workbench ignore rules for that template shape, and fix any drift in the owning template repos. For most templates, validate `.testbed/addons/*`, `!.testbed/addons/.editorconfig`, and `.testbed/.addons/`. For `aerobeat-template-assembly`, validate the root-level equivalents for `/addons/` and `/.addons/` because that template does not use a hidden `.testbed/` project. Report which templates were already correct and which required changes.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-template-*/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-template-*/.gitignore`

**Status:** ✅ Complete

**Results:** Audited all 13 `aerobeat-template-*` repos. No drift found. Standard templates already carry the canonical `.testbed/addons/*`, `!.testbed/addons/.editorconfig`, and `.testbed/.addons/` ignores. `aerobeat-template-assembly` is also already correct for its root-level workbench layout with `addons/*`, `!addons/.editorconfig`, and `.addons/`. `git status --ignored` confirmed the generated workbench directories are ignored. No file edits or commits were needed.

---

### Task 4: Verify testbed import in Godot

**Bead ID:** `aerobeat-vendor-gdgs-i9h`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-03`  
**Prompt:** For bead ID TBD, claim the bead on start, open the hidden `.testbed` project through the normal Godot workflow, verify the project imports cleanly without the REF-01 validation failures, capture any remaining warnings/errors, and report exact validation results.

**Folders Created/Deleted/Modified:**
- None expected

**Files Created/Deleted/Modified:**
- None expected

**Status:** ✅ Complete

**Results:** QA verified the repaired `.testbed` import path is fixed. Since no Godot editor plugin session was available, QA used the strongest repo-local path instead: `godotenv addons install` from `.testbed`, headless import against the hidden project, a fresh import-from-scratch check after moving `.testbed/.godot` aside, and a short real X11 run of the testbed scene. All passed. Fresh import logs showed `[gdgs]: import complete, 271123 gaussians ready for rendering`, and the live run confirmed compositor/render path activity with `point_count=271123`. QA also confirmed there are no remaining repo/testbed references to `res://addons/aerobeat-vendor-gdgs/...`.

---

### Task 5: Independent audit and closure

**Bead ID:** `aerobeat-vendor-gdgs-vur`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`  
**Prompt:** For bead ID TBD, claim the bead on start, independently review the plan, diff, validation evidence, and final repo state; confirm the importer issue is actually fixed and only then close the bead chain. If anything is still off, leave the work open and report the exact gap.

**Folders Created/Deleted/Modified:**
- None expected

**Files Created/Deleted/Modified:**
- None expected

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Plan created; execution not started yet.

**Reference Check:** Not yet validated.

**Commits:**
- None yet.

**Lessons Learned:** Pending execution.

---

*Completed on Pending*
