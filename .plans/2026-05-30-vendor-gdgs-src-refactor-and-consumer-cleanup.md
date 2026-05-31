# AeroBeat Vendor GDGS `/src/` Refactor and Consumer Cleanup

**Date:** 2026-05-30  
**Status:** In Progress  
**Last Updated:** 2026-05-30 22:14 EDT  
**Blocked Reason:** None  
**Agent:** `chip`

---

## Goal

Refactor `aerobeat-vendor-gdgs` so its published runtime surface moves from repo-root `/gdgs/` to repo-root `/src/`, then update the affected AeroBeat consumers so stale embedded GDGS copies and stale dependency names no longer create runtime class-name collisions.

---

## Overview

The polyrepo audit showed that the strongest real GDGS collision is not that every consumer is shipping a second owner, but that `aerobeat-assembly-community` still has an old repo-root `addons/gdgs/` copy from before the vendor/tool split was finalized. Meanwhile `aerobeat-environment-community` still has a hidden testbed dependency on the stale pre-rename `aerobeat-tool-gaussian-splat` name. `aerobeat-tool-gaussian-splat-loader` appears to be the intended side-by-side Aero wrapper and should remain so, but its testbed and dependency expectations must continue to align with the vendor owner.

Derrick has now made the owner-repo decision explicit: `aerobeat-vendor-gdgs` should be refactored from `/gdgs/` to `/src/` at the repo root. That means this slice is no longer just audit cleanup; it is an owner-surface refactor with consumer fallout. The plan should therefore treat `aerobeat-vendor-gdgs` as the lead repo, with child cleanup in `aerobeat-assembly-community` and `aerobeat-environment-community`, and a validation pass against `aerobeat-tool-gaussian-splat-loader` to ensure the intended wrapper relationship still holds after the vendor path move.

This plan should produce a clean post-refactor state where the vendor repo owns the canonical GDGS classes under `/src/`, the assembly repo no longer carries the stale embedded `addons/gdgs/` runtime copy, stale tool naming is repaired in the environment-community hidden testbed, and the targeted collision cluster can be re-scanned to verify the runtime-owner boundary is now correct. Derrick has also explicitly called out that the hidden `/.testbed/` projects for `aerobeat-vendor-gdgs`, `aerobeat-tool-gaussian-splat-loader`, and any other affected consumers will need to be updated as part of the `/gdgs/` -> `/src/` fallout, so those testbed dependency/manifests/path assumptions are first-class implementation scope for this plan.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Consolidated remediation matrix calling out the P1 GDGS / Gaussian blocker cluster | `/home/derrick/.openclaw/workspace/.temp/aerobeat-remediation-matrix-2026-05-30T19-27-00-0400.md` |
| `REF-02` | Raw class-name collision artifact with exact duplicate paths | `/home/derrick/.openclaw/workspace/.temp/scan-godot-class-names-aerobeat-20260530T192213-0400.json` |
| `REF-03` | Derrick's explicit decision that `aerobeat-vendor-gdgs` should move from `/gdgs/` to `/src/` and that `assembly-community/addons/gdgs/` is stale | This conversation, 2026-05-30 19:48-20:05 EDT |
| `REF-04` | Current vendor repo to refactor | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/` |
| `REF-05` | Intended wrapper repo that should remain side-by-side with the vendor owner | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-gaussian-splat-loader/` |

---

## Tasks

### Task 1: Audit exact vendor-GDGS consumer fallout before edits

**Bead ID:** `oc-4z4`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Audit the exact places that depend on `aerobeat-vendor-gdgs` runtime paths or still carry stale embedded GDGS copies. Confirm the stale `addons/gdgs/` surface inside `aerobeat-assembly-community`, confirm the stale `aerobeat-tool-gaussian-splat` naming in `aerobeat-environment-community`, and identify every path/dependency/import/testbed manifest that will need to change when the vendor repo moves from `/gdgs/` to `/src/`, including the hidden `/.testbed/` projects for `aerobeat-vendor-gdgs`, `aerobeat-tool-gaussian-splat-loader`, and any other affected consumers. Claim the bead on start. Do not edit files.

**Folders Created/Deleted/Modified:**
- None

**Files Created/Deleted/Modified:**
- None

**Status:** ✅ Complete

**Results:** Completed via bead `oc-4z4`. Audit artifact saved to `/home/derrick/.openclaw/workspace/.temp/oc-4z4-gdgs-src-path-audit-2026-05-30.md`. Confirmed the stale embedded GDGS copy in `aerobeat-assembly-community/addons/gdgs/` as a real nested repo/copy, not generated output. Confirmed stale pre-rename gaussian tool naming in `aerobeat-environment-community/.testbed/repros/oc-c3u/splat_repro_capture.gd`, which still preloads `res://addons/aerobeat-tool-gaussian-splat/src/AeroGaussianSplatManager.gd`. Confirmed the key source-of-truth manifests/docs that must change for the `/gdgs/` -> `/src/` move: `aerobeat-vendor-gdgs/.testbed/addons.jsonc`, `aerobeat-vendor-gdgs/README.md`, `aerobeat-assembly-community/addons.jsonc`, `aerobeat-tool-gaussian-splat-loader/.testbed/addons.jsonc`, and `aerobeat-environment-community/.testbed/addons.jsonc`. Important nuance: most `res://addons/gdgs/...` runtime imports do not need logical rewrites if the addon still mounts as `gdgs`; the main fallout is manifest `subfolder` targets and owner repo filesystem layout.

---

### Task 2: Refactor `aerobeat-vendor-gdgs` from `/gdgs/` to `/src/`

**Bead ID:** `oc-xdp`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`  
**Prompt:** In `aerobeat-vendor-gdgs`, refactor the published runtime surface from repo-root `/gdgs/` to repo-root `/src/` without changing intended ownership semantics. Update manifests, plugin references, testbed references, docs, and any repo-local validation needed so the vendor repo still works from its hidden `/.testbed/` and remains the canonical owner. Treat `/.testbed/` fallout as in-scope, not optional. Claim the bead on start, validate thoroughly, then commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/gdgs/`

**Files Created/Deleted/Modified:**
- vendor runtime/editor files currently under `/gdgs/`
- manifests, plugin config, docs, and testbed dependency references that assume `/gdgs/`

**Status:** ✅ Complete

**Results:** Completed via bead `oc-xdp`. Refactored `aerobeat-vendor-gdgs` so the vendored owner payload now lives at repo-root `src/` instead of `gdgs/`. Updated `.testbed/addons.jsonc` to install GDGS from `subfolder: "/src"` and updated `README.md` to document `/src` as the published repo subfolder while preserving the mounted addon identity at `res://addons/gdgs`. Validation found a real stale-cache issue on the first pass from the pre-move layout; after rebuilding hidden testbed Godot import/class caches with `godot --headless --path .testbed --import`, all three repo-local headless validations passed: `scripts/validate_runtime_loader.gd`, `scripts/validate_transform_proving_surface.gd`, and `scripts/validate_interaction_controls.gd`. Commit `f33358c` (`Move vendored gdgs payload to src`) was pushed to `origin/main`.

---

### Task 3: Clean stale consumer copies and stale dependency names

**Bead ID:** `oc-z5s`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Update the affected consumers after the vendor `/src/` refactor: remove the stale `addons/gdgs/` runtime copy from `aerobeat-assembly-community`, repair stale pre-rename `aerobeat-tool-gaussian-splat` dependency naming in `aerobeat-environment-community` hidden testbed surfaces, and update any path assumptions in `aerobeat-tool-gaussian-splat-loader` or other affected repos so the intended vendor+wrapper relationship still holds. This explicitly includes `/.testbed/` project manifests, addon mounts, and dependency references in the affected consumer repos. Claim the bead on start, validate the affected repos, then commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-assembly-community/addons/gdgs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/.testbed/`
- any directly affected consumer dependency/manifests in wrapper repos

**Files Created/Deleted/Modified:**
- stale embedded GDGS addon payloads in `aerobeat-assembly-community`
- stale dependency references in `aerobeat-environment-community`
- any consumer manifests/docs/path references impacted by the vendor `/src/` move

**Status:** ✅ Complete

**Results:** Completed via bead `oc-z5s`. Updated `aerobeat-assembly-community/addons.jsonc` so `gdgs` now mounts from the vendor repo `/src`, removed the stale local `addons/gdgs` runtime copy from the working tree, and pushed commit `ceeea40` (`Update gdgs vendor mount for src layout`). Updated `aerobeat-environment-community/.testbed/addons.jsonc` so `gdgs` mounts from `/src`, fixed stale pre-rename `aerobeat-tool-gaussian-splat` references in hidden testbed surfaces (`.testbed/scripts/splat_test_scene.gd`, `.testbed/tests/test_testbed_structure.gd`, `.testbed/repros/oc-c3u/splat_repro_capture.gd`), added the `oc-c3u` repro scene/script to source control, and pushed commit `bd87b6b` (`Fix gaussian-splat testbed consumer paths`). Updated `aerobeat-tool-gaussian-splat-loader/.testbed/addons.jsonc` so `gdgs` mounts from `/src` and pushed commit `b08b3e6` (`Mount gdgs testbed from src`). Validation passed across the affected repos: loader GUT passed and smoke logging confirmed successful splat load/place/transform; environment-community passed GUT 12/12 and `res://scenes/splat_test.tscn` exited `0`; assembly-community restored addons, imported headlessly, and GUT exited `0` with one pre-existing risky/pending item (`test_cleanup_on_exit did not assert`) that was not introduced by this change.

---

### Task 4: QA runtime-owner boundary and re-scan targeted collisions

**Bead ID:** `oc-zhn`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-04`, `REF-05`  
**Prompt:** Verify the vendor repo still works after the `/src/` move, the wrapper repo still functions as the intended side-by-side Aero surface, the assembly repo no longer exposes a stale GDGS runtime owner, and the stale environment-community dependency name is repaired. Run a targeted class-name verification for the affected GDGS/Gaussian classes and report exact evidence. Claim the bead on start.

**Folders Created/Deleted/Modified:**
- None

**Files Created/Deleted/Modified:**
- None

**Status:** ✅ Complete

**Results:** Completed via bead `oc-zhn`. QA verified the working repo states at commits `f33358c` (`aerobeat-vendor-gdgs`), `b08b3e6` (`aerobeat-tool-gaussian-splat-loader`), `ceeea40` (`aerobeat-assembly-community`), and `bd87b6b` (`aerobeat-environment-community`). It confirmed the vendor `/src` move is live, the old vendor class paths under `aerobeat-vendor-gdgs/gdgs/...` are gone, and canonical GDGS class declarations now live under `src/...`. Vendor `.testbed` passed all targeted runtime checks; wrapper `.testbed` passed GUT 12/12 and smoke validation with successful load/place/transform; environment-community no longer contains stale `aerobeat-tool-gaussian-splat` references and passed both GUT 12/12 and scene launch validation. Assembly no longer has a stale tracked/source-owned GDGS runtime owner: `addons.jsonc` points to vendor `subfolder "/src"`, `git ls-files addons/gdgs` returns nothing, and any remaining duplicate-looking paths are generated install mirrors that hash-match vendor `src` for all 9 checked GDGS/Gaussian collision classes. Remaining unrelated risk: the pre-existing assembly GUT risky item `test_cleanup_on_exit` and an environment-community README/script mismatch that did not block QA.

---

### Task 5: Audit final state and close the GDGS blocker slice

**Bead ID:** `oc-7rk`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Independently truth-check that `aerobeat-vendor-gdgs` now owns its published runtime surface under `/src/`, that stale consumer copies/names were actually removed or repaired, and that the targeted GDGS/Gaussian blocker cluster is materially reduced or resolved. Claim the bead on start and close it only if the work is actually done.

**Folders Created/Deleted/Modified:**
- None

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-30-vendor-gdgs-src-refactor-and-consumer-cleanup.md`

**Status:** ✅ Complete

**Results:** Final closure completed via the narrow retry beads `oc-gm9`, `oc-3cl`, and `oc-a8j`. The stale live working-tree `aerobeat-assembly-community/addons/gdgs/` copy was removed, the canonical restore flow rebuilt only generated mirror state from vendor `/src`, and re-QA confirmed the project still imported/tested at the prior expected level. Final audit confirmed the blocker slice is actually done: `aerobeat-assembly-community/addons.jsonc` points `gdgs` at `aerobeat-vendor-gdgs` with `subfolder: /src`, `git ls-files` shows no tracked `addons/gdgs` or `.addons/gdgs` paths, `diff -rq ../aerobeat-vendor-gdgs/src addons/gdgs` is clean except for expected generated `.git` metadata, and `diff -rq ../aerobeat-vendor-gdgs/src .addons/gdgs/src` is fully clean. Stale divergent consumer-owned GDGS surfaces are gone; remaining trees are acceptable generated mirrors only.

---

### Task 6: Refactor `aerobeat-vendor-modio` docs/scripts/config layout into hidden testbed structure

**Bead ID:** `oc-xgj4`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-03`  
**Prompt:** After the GDGS blocker slice is fully closed, refactor `aerobeat-vendor-modio` so the repo-root `/docs/` folder moves into `/.testbed/docs/`, loose scripts currently sitting directly under `/.testbed/` move into `/.testbed/scripts/`, and relevant configuration files move into `/.testbed/configs/`. Update any docs, paths, manifests, or testbed references affected by that layout change, validate the repo, then commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/docs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/scripts/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/.testbed/configs/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-modio/docs/`

**Files Created/Deleted/Modified:**
- vendor-modio docs currently under repo-root `/docs/`
- loose vendor-modio files currently under `/.testbed/`
- any related docs/manifests/path references affected by the moves

**Status:** ✅ Complete

**Results:** Completed via bead `oc-xgj4`. In `aerobeat-vendor-modio`, repo-root `docs/` moved into `/.testbed/docs/`, loose hidden-testbed harness files moved into `/.testbed/scripts/`, and relevant config templates moved into `/.testbed/configs/`. Updated fallout included `README.md`, `.gitignore`, testbed scripts/preloads, test files, and moved docs referencing the old harness/config paths. Validation passed with `godot --headless --path .testbed --import`, `res://tests/validate_scaffold.gd`, `res://tests/validate_modio_testbed_scenes.gd`, and GUT (`100/100` passing). Commit `741faaf` (`Rehome modio docs and harness files into testbed`) was pushed to `origin/main`.

---

### Task 7: Remove stale `restore-testbed-addons.sh` references and any live instances

**Bead ID:** `oc-3oi`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-03`  
**Prompt:** Audit and remove stale references to `restore-testbed-addons.sh` and any live instances of that old pre-production script. Current known reference hits are in `aerobeat-environment-community/README.md`, `aerobeat-docs/docs/architecture/repo-structure-reference.md`, and `aerobeat-vendor-gdgs/README.md`. No live script file currently exists in the family scan output, so the task is expected to be reference cleanup unless new instances are found during execution. Update affected docs/scripts accordingly, validate if needed, then commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- Any affected docs/script folders in touched repos

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-environment-community/README.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-docs/docs/architecture/repo-structure-reference.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/README.md`
- any additional stale reference locations discovered during execution

**Status:** ✅ Complete

**Results:** Completed via bead `oc-3oi`. Family-wide search confirmed there were no live `restore-testbed-addons.sh` script files left; the remaining hits were stale doc references only. Updated `aerobeat-environment-community/README.md` to replace the deleted helper script with the current manual delete-first GodotEnv restore flow and pushed commit `4c9be18` (`Remove stale restore helper docs`). Updated `aerobeat-docs/docs/architecture/repo-structure-reference.md` to remove the stale conceptual `scripts/restore-testbed-addons.sh` tree entry and pushed commit `bcc2e09` (`Remove stale restore helper reference`). Updated `aerobeat-vendor-gdgs/README.md` to stop pointing consumers at nonexistent restore helper scripts and instead document the canonical repo-local cleanup + `godotenv addons install` flow. Final validation for this slice was a clean family search: `rg -n "restore-testbed-addons\\.sh" /home/derrick/.openclaw/workspace/projects/aerobeat` returned no matches after the edits.

---

### Task 8: Rename assembly/wrapper consumer mount identity from bare `gdgs` to explicit `aerobeat-vendor-gdgs`

**Bead ID:** `oc-2qz`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Derrick clarified that `aerobeat-assembly-community` should depend on `aerobeat-vendor-gdgs` and `aerobeat-tool-gaussian-splat-loader` as GodotEnv dependencies, and that there should not be a bare installed `addons/gdgs` folder because `aerobeat-vendor-gdgs` replaces it. Refactor the affected consumer/testbed manifests and path assumptions so the installed addon identity is explicit (`aerobeat-vendor-gdgs`) rather than bare `gdgs`, including any `res://addons/gdgs/...` fallout that must change. Validate the affected repos, then commit and push by default unless blocked.

**Folders Created/Deleted/Modified:**
- `aerobeat-assembly-community/addons/`
- `aerobeat-assembly-community/.addons/`
- `aerobeat-tool-gaussian-splat-loader/.testbed/addons/`
- `aerobeat-tool-gaussian-splat-loader/.testbed/.addons/`
- `aerobeat-environment-community/.testbed/addons/`
- `aerobeat-environment-community/.testbed/.addons/`
- any other affected consumer/testbed addon mount locations

**Files Created/Deleted/Modified:**
- affected `addons.jsonc` manifests
- any scenes/scripts/tests/docs that still assume `res://addons/gdgs/...`
- any restore/install helpers or validation scripts impacted by the mount identity rename

**Status:** ⏳ Pending

**Results:** Appended by Derrick as a corrected post-closure target: bare `gdgs` mount identity is no longer acceptable end state.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Completed the first GDGS blocker slice: `aerobeat-vendor-gdgs` now owns its published runtime surface under `/src/`, affected consumer/testbed manifests were updated to the new owner layout, stale `aerobeat-tool-gaussian-splat` naming was repaired in environment-community, and the stale assembly root-owner copy was removed so only generated mirrors remained under the old bare `gdgs` mount identity. Derrick then clarified that the end-state should not use a bare `gdgs` installed addon folder at all; assembly-community and other consumers should depend explicitly on `aerobeat-vendor-gdgs` plus `aerobeat-tool-gaussian-splat-loader`. This plan therefore also now carries appended follow-on work for `aerobeat-vendor-modio` testbed layout cleanup, family-wide stale `restore-testbed-addons.sh` reference cleanup, and the new explicit vendor mount identity refactor.

**Reference Check:**
- `REF-01` and `REF-02` defined the blocker cluster and exact duplicate paths, which were used to drive both the initial fixes and the final closure checks.
- `REF-03` recorded Derrick's explicit owner-repo decision and stale-consumer diagnosis, plus the later appended follow-on cleanup scope.
- `REF-04` and `REF-05` identified the owner repo and intended wrapper repo, both of which were validated after the `/src/` move.

**Commits:**
- `f33358c` - `Move vendored gdgs payload to src`
- `ceeea40` - `Update gdgs vendor mount for src layout`
- `bd87b6b` - `Fix gaussian-splat testbed consumer paths`
- `b08b3e6` - `Mount gdgs testbed from src`
- `741faaf` - `Rehome modio docs and harness files into testbed`
- `4c9be18` - `Remove stale restore helper docs`
- `bcc2e09` - `Remove stale restore helper reference`

**Lessons Learned:**
- The main duplicate-runtime problem was not the intended vendor+wrapper pairing; it was stale embedded consumer ownership and stale dependency naming.
- Once the owner repo path changes from `/gdgs/` to `/src/`, consumer fallout must include hidden `/.testbed/` manifests and restore/install semantics, not just visible repo-root paths.
- Root-project `addons/...` trees must be distinguished carefully between stale divergent owners and acceptable generated mirrors rebuilt from the canonical vendor source.

---

*Completed on 2026-05-30*
