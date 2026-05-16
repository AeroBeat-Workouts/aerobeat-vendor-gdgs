# AeroBeat Vendor - GDGS Push-Constant Fix PR Prep

**Date:** 2026-05-16  
**Status:** In Progress  
**Agent:** Chip 🐱‍💻

---

## Goal

Prepare the confirmed GDGS push-constant contract fix for upstream contribution, including repository PR/branching rules, required supporting issue context, and a clean branch strategy for opening a PR against `ReconWorldLab/godot-gaussian-splatting`.

---

## Overview

We now have a real plugin-side bug fixed on a dedicated test branch: GDGS was sending a shared padded 16-byte push-constant blob to radix shaders that actually declared exact 4-byte, 8-byte, and 12-byte contracts. Godot 4.7-dev5 validation confirmed the mismatch, and the test-branch fix removed those errors entirely. That means there is real upstream value in landing this fix even though it does not fully solve the later crash.

Before turning that work into a PR, we need to check the repo’s contribution surfaces and branch expectations. The upstream GDGS repo appears lightweight: root contains `README.md`, `docs/`, `samples/`, and `addons/`, with no obvious `CONTRIBUTING.md` or `.github/ISSUE_TEMPLATE/` found so far. We still need to verify whether maintainers expect PRs from feature branches rather than `main`, whether the existing issue #12 is sufficient context for this narrower fix, and whether the PR should explicitly frame this as “fix one confirmed contract violation while leaving the later BLIT-pass crash investigation open.”

This slice should stay disciplined: first verify repo rules and clean branch strategy, then prepare the branch/commit/PR narrative, then audit whether the package is actually ready to open. We should not force the already-dirty test branch into a public PR shape without checking whether a clean branch split or cherry-pick is the better upstream handoff.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | GDGS issue already filed upstream | `https://github.com/ReconWorldLab/godot-gaussian-splatting/issues/12` |
| `REF-02` | Push-constant contract trace note | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/gdgs-radix-push-constant-contract.md` |
| `REF-03` | Push-constant fix plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-push-constant-contract-fix.md` |
| `REF-04` | Upstream repo root / metadata | `https://github.com/ReconWorldLab/godot-gaussian-splatting` |
| `REF-05` | Current test-branch fix commit | `bc06934` |

---

## Tasks

### Task 1: Verify upstream PR rules and choose the clean branch strategy

**Bead ID:** `oc-eg6`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Inspect the upstream GDGS repo for contribution rules, PR/issue expectations, default branch strategy, and whether the existing issue context is enough for this fix. Then recommend the cleanest upstream handoff path: keep work on the current test branch, create a fresh PR branch from clean state and cherry-pick the fix, or some other safer shape.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-push-constant-pr-prep.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/upstream-pr-prep-notes.md`

**Status:** ✅ Complete

**Results:** Claimed bead `oc-eg6` and inspected the actual upstream repo surfaces plus current local git state. Upstream guidance is sparse but usable: `ReconWorldLab/godot-gaussian-splatting` defaults to `main`; there is no visible `CONTRIBUTING.md`, PR template, or issue template in the repo; and recent community PRs `#6` and `#9` were both small, directly scoped changes targeting `main`, with at least one contributor opening from a dedicated topic branch (`vr-rendering-eye-proj-matrix-fix`) and the maintainer responding conversationally in-thread rather than through a formal checklist. Upstream `main` is still exactly the pinned vendor commit `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`, so there is no rebase gap to resolve before preparing a PR branch. Existing issue `#12` is useful background context because it already documents the broader Intel/Wayland/Vulkan repro and the investigation path that exposed this bug, but it is **not** sufficient by itself to explain this narrower fix; the eventual PR should explicitly reference `#12` while clearly stating that this change only fixes the confirmed radix push-constant contract violation and does **not** claim to resolve the later `BLIT_PASS` / device-loss failure. Local branch review showed the current working branch `test/oc-xok-gdgs-radix-push-constant-contract` is a poor upstream handoff shape: it sits on top of multiple investigation/doc commits (`3b94cc7`, `2cd6d27`, `5797bd8`, `be189b9`), the fix commit `bc06934` itself also carries local plan/doc files, and the working tree is still dirty with unrelated plan/doc edits. Recommended strategy: create a fresh upstream PR branch from clean `main` / upstream `main`, then replay only the minimal runtime-code fix (either by carefully cherry-picking `bc06934` and immediately dropping non-upstream docs/plan paths, or more cleanly by reapplying the two runtime-file hunks as a new single commit). Added a durable repo note capturing those rules/strategy findings in `docs/upstream-pr-prep-notes.md`. No PR was opened in this task.

---

### Task 2: Prepare the upstream-ready branch and PR package for the confirmed fix

**Bead ID:** `oc-n9h`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Using the verified branch strategy, prepare the exact upstream-ready branch for the push-constant fix and draft the PR package. Keep the scope limited to the confirmed contract fix, cite the existing issue where appropriate, and make sure the branch/commit state is clean and reviewable.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs-upstream-pr/addons/gdgs/runtime/render/gaussian_renderer.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs-upstream-pr/addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/upstream-pr-draft-issue-12-radix-push-constant-fix.md`

**Status:** ✅ Complete

**Results:** Claimed bead `oc-n9h` and followed the chosen clean-branch strategy without touching the already-dirty investigation branch. Created a separate git worktree at `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs-upstream-pr` on fresh branch `upstream/issue-12-radix-push-constant-fix` from local `main`, then replayed only the runtime-file hunks from fix commit `bc06934` by checking out just the two upstream-relevant files. The resulting branch diff is surgically limited to `addons/gdgs/runtime/render/gaussian_renderer.gd` and `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`; no local plans/docs are present in the commit. Ran `git diff --check` before commit, then committed the clean branch as `4648f8a0b6860f69ace318c658e8e32467957c4c` (`fix: honor exact gdgs radix push constants`). Prepared the ready-to-open PR package text in-repo at `docs/upstream-pr-draft-issue-12-radix-push-constant-fix.md`, explicitly referencing upstream issue `#12`, describing the confirmed radix push-constant contract mismatch, and stating that the later `BLIT_PASS` / device-loss crash is out of scope. Stopped at ready-to-open; no PR was created.

---

### Task 3: Audit whether the PR package is clean, scoped, and ready to open

**Bead ID:** `oc-7ew`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** Independently audit the branch strategy and PR package. Confirm that the change cleanly fixes the confirmed misuse, that the branch/commit state is appropriate for upstream review, and that the PR text is honest about what this fix does and does not resolve.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-16-gdgs-push-constant-pr-prep.md`
- notes/docs as needed

**Status:** ⏳ Pending

**Results:** Pending.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Task 1 and Task 2 are complete: there is now a clean upstream-review branch containing only the confirmed runtime push-constant fix plus an in-repo PR draft that honestly frames scope against issue `#12`. Final readiness still needs the independent Task 3 audit.

**Reference Check:** `REF-01` is cited in the PR draft; `REF-02` and `REF-03` informed the minimal replay; `REF-05` was reduced to a two-file clean commit suitable for upstream review.

**Commits:**
- `4648f8a0b6860f69ace318c658e8e32467957c4c` - fix: honor exact gdgs radix push constants

**Lessons Learned:**
- A confirmed fix is not automatically upstream-ready; branch hygiene and honest scope framing matter.
- A separate worktree is the safest way to prepare an upstream-clean branch when the investigation branch is intentionally dirty with local notes.

---

*Completed on Pending*
