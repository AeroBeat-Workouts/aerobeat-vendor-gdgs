# AeroBeat Vendor - GDGS Push-Constant Contract Fix

**Date:** 2026-05-16  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Fix the suspected GDGS radix push-constant contract mismatch by sending exact per-pass push-constant payload sizes instead of a shared padded blob, then validate whether that removes the 4.7-dev5 validation errors and changes the later BLIT_PASS / device-loss behavior.

---

## Overview

The latest Godot 4.7-dev5 repro did not eliminate the GDGS failure, but it exposed a much sharper clue than we had before: repeated push-constant validation errors in the GDGS compute path before the later `BLIT_PASS` / Vulkan device-loss boundary. Those errors line up with the current GDGS implementation pattern of padding push constants to 16 bytes and reusing one blob across multiple radix passes that appear to have different reflected push-constant sizes.

That is a materially stronger hypothesis than the earlier indirect-dispatch theory. If GDGS is violating the shader contract, then the later crash may simply be downstream fallout from bad compute inputs or corrupted intermediate GPU state rather than a primary BLIT-stage bug. So the first job now is not broad engine surgery — it is to make GDGS honor the exact per-pass push-constant contract and then see what changes.

This slice should stay narrow. We are not rewriting the radix algorithm. We are patching the parameter handoff boundary so each shader gets the exact bytes it declares. Then we run the same real-machine repro on Godot 4.7-dev5 first, because that version already exposes the validation mismatch most clearly. If validation errors disappear and runtime improves, we have a real plugin-side bug. If the validation errors disappear but the later crash remains, that gives us a much cleaner baseline for the next Godot-side investigation.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Active GDGS source-level investigation plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-source-level-blit-pass-investigation.md` |
| `REF-02` | GDGS source trace | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-blit-pass-source-trace.md` |
| `REF-03` | GDGS direct-dispatch isolation notes | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-direct-dispatch-isolation.md` |
| `REF-04` | Godot 4.7-dev5 nightly repro note | `/home/derrick/.openclaw/workspace/projects/openclaw-godot/docs/gdgs-godot-47-dev5-nightly-repro-2026-05-16.md` |
| `REF-05` | Godot source-debug lane memo | `/home/derrick/.openclaw/workspace/projects/openclaw-godot/docs/gdgs-godot-source-debug-lane-2026-05-16.md` |
| `REF-06` | GDGS render/device context source | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/` |

---

## Tasks

### Task 1: Trace the exact push-constant contract per radix pass

**Bead ID:** `oc-xok`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Inspect the GDGS radix-related compute shaders and the corresponding CPU-side push-constant construction/call sites. Document the exact push-constant layout and expected byte count for each pass (`spine`, `upsweep`, `downsweep`, and any closely related pass that shares the path). Confirm where GDGS is currently padding/reusing a shared blob and identify the narrowest safe contract fix.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-push-constant-contract-fix.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-radix-push-constant-contract.md`

**Status:** ✅ Complete

**Results:** Claimed bead `oc-xok`, then created and switched to the dirty-workspace-friendly test branch `test/oc-xok-gdgs-radix-push-constant-contract` before making any durable edits. Traced the radix shader declarations and confirmed the exact reflected push-constant byte counts are `4` for `spine` (`int pass`), `8` for `upsweep` (`int pass`, `uint in_offset`), and `12` for `downsweep` (`int pass`, `uint in_offset`, `uint out_offset`) from `REF-06`. Confirmed the current GDGS send path in `gaussian_renderer.gd:93-101` builds one shared 3-scalar radix blob and reuses it for all three pipelines, while `gaussian_rendering_device_context.gd:127-142` pads every push-constant payload to a 16-byte boundary and `gaussian_rendering_device_context.gd:117-118` forwards that padded size directly to Godot. Net effect: all three radix passes currently send `16` bytes even though the shader contracts are `4`, `8`, and `12`, matching the dev5 validation direction from `REF-04` and `REF-05`. Added durable repo note `docs/gdgs-radix-push-constant-contract.md` capturing the exact contract, current mis-send path, and the narrowest safe fix shape: keep the generic dispatch path, but make the radix call site send per-pipeline exact payloads (`[pass]`, `[pass, in_offset]`, `[pass, in_offset, out_offset]`) instead of one reused padded blob. No runtime code fix was implemented in this Task 1 pass; only durable plan/doc updates were prepared for commit.

---

### Task 2: Implement the exact-size push-constant fix in GDGS

**Bead ID:** `oc-se2`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-02`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Patch GDGS so each radix compute pass sends the exact push-constant payload size and layout it declares, instead of a shared padded blob. Keep the change narrow and reversible. Preserve existing logging or add minimal targeted breadcrumbs if helpful for QA. Run relevant local validation, commit the branch work, and document exactly what changed.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_renderer.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-radix-push-constant-contract.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-push-constant-contract-fix.md`

**Status:** ✅ Complete

**Results:** Claimed bead `oc-se2` and stayed on the dedicated branch `test/oc-xok-gdgs-radix-push-constant-contract` with the pre-existing unrelated dirty plan/doc edits left untouched. Implemented the narrowest reversible contract fix by preserving the existing padded `RenderingDeviceContext.create_push_constant()` path for legacy callers, adding a targeted `RenderingDeviceContext.create_exact_push_constant()` helper, and switching only the radix dispatch site in `gaussian_renderer.gd` to use exact per-pass payloads. Actual payload shapes are now `spine -> [radix_shift_pass]` (`4` bytes), `upsweep -> [radix_shift_pass, radix_input_offset]` (`8` bytes), and `downsweep -> [radix_shift_pass, radix_input_offset, radix_output_offset]` (`12` bytes), matching the shader-declared contracts from `REF-06` instead of reusing one shared 16-byte-padded blob. Updated the durable note `docs/gdgs-radix-push-constant-contract.md` with the landed implementation shape and validation status. Local validation run: `~/.local/bin/godot --import --headless --path /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs`, which completed successfully on the host Godot install and re-registered `GaussianRenderer` plus `GdgsRenderingDeviceContext` without script parse errors. Committed on the task branch with message `fix: honor exact gdgs radix push constants`. References checked: `REF-02`, `REF-06`.

---

### Task 3: QA the fix on Godot 4.7-dev5 using the existing repro harness

**Bead ID:** `oc-ruw`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`, `REF-06`  
**Prompt:** Re-run the established GDGS control-scene repro on Godot 4.7-dev5 with the push-constant fix applied. Capture whether the validation errors disappear, whether the later BLIT_PASS / device-loss behavior changes, and whether any visible rendering or stability improves. Save durable artifacts and compare directly against the prior 4.7-dev5 nightly baseline.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/.temp/`

**Files Created/Deleted/Modified:**
- new QA artifact folders/logs/images/summaries as needed
- plan/doc updates as needed

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 4: Audit whether the fix resolves the real bug or only cleans the contract violation

**Bead ID:** `oc-6wj`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`  
**Prompt:** Independently audit the push-constant contract fix and the 4.7-dev5 QA result. Decide whether the bug is now resolved, materially narrowed, or still requires Godot-side instrumentation. Be explicit about whether the patch removed a real plugin misuse, whether BLIT_PASS still remains only as a downstream symptom, and what the next owning lane should be.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-push-constant-contract-fix.md`
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
- Newer engine validation can turn a vague crash into a concrete contract bug if we listen to it.
- Fixing a real plugin misuse is worth doing even if it only clears the path for deeper engine debugging afterward.

---

*Completed on Pending*
