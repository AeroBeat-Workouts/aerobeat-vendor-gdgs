# GDGS Upstream Issue Package and BLIT-Pass Narrow Test

**Date:** 2026-05-15  
**Status:** Complete  
**Agent:** Chip 🐱‍💻

---

## Goal

Prepare an upstream-quality issue package for `ReconWorldLab/godot-gaussian-splatting` without filing it yet, while also running one last ultra-narrow local pass focused on presentation/writeback behavior near the `BLIT_PASS` failure boundary.

---

## Overview

The vendor happy-path control scene and the tweak matrix both converged on the same result: GDGS reaches valid compositor-texture production on this machine, but every enabled render/composite path still goes black and ends in Vulkan device loss near `BLIT_PASS`. That means broad wrapper suspicion is no longer the right branch.

Derrick wants both tracks now, which is the right move: we should shape the eventual upstream report against the original repo rather than our AeroBeat vendor mirror, but we should hold actual filing until one last local present/writeback-focused pass is exhausted. This slice therefore has two parallel deliverables: a ready-to-file upstream issue draft that follows whatever upstream guidance exists, and a narrow final local test focused only on the presentation/blit side of the failing path.

Current upstream guidance appears minimal: the upstream repo does not expose a `.github/ISSUE_TEMPLATE/` directory or `CONTRIBUTING.md` at the repo root, so we should default to a clean maintainer-friendly bug report structure based on the repo README and existing issue style, including a clear plain-English summary plus precise repro steps, environment, expected vs actual behavior, and attached artifacts.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Upstream GDGS README | `https://github.com/ReconWorldLab/godot-gaussian-splatting/blob/main/README.md` |
| `REF-02` | Upstream repo metadata / issue surfaces | `https://github.com/ReconWorldLab/godot-gaussian-splatting` |
| `REF-03` | Vendor happy-path control-scene plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-15-gdgs-happy-path-control-scene.md` |
| `REF-04` | Vendor tweak-matrix plan/results | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-15-gdgs-render-path-tweaks-and-test.md` |
| `REF-05` | Vendor control scene and harness repo | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/` |
| `REF-06` | Happy-path QA artifacts | `/home/derrick/.openclaw/workspace/.temp/gdgs-happy-path-qa/` |
| `REF-07` | Tweak-matrix QA artifacts | `/home/derrick/.openclaw/workspace/.temp/gdgs-render-tweaks-qa/` |
| `REF-08` | AeroBeat comparison artifacts | `/home/derrick/.openclaw/workspace/.temp/aerobeat-qa/results/` |

---

## Tasks

### Task 1: Draft the upstream issue package without filing it

**Bead ID:** `oc-vtp`  
**SubAgent:** `primary` (for `research`)  
**Role:** `research`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** Inspect the upstream repo for issue guidelines/templates; if none exist, infer a maintainer-friendly bug report structure from the README and current issue style. Then draft a ready-to-file upstream issue package for the original GDGS repo, but do not file it. Include a plain-English summary, environment, exact repro, expected vs actual behavior, key evidence, and a concise statement of what has already been ruled out locally. Claim the assigned bead on start and close it if the draft package is complete.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/.temp/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/upstream-issue-draft.md`

**Status:** ✅ Complete

**Results:** Drafted the upstream issue package against the original GDGS repo surfaces rather than the AeroBeat vendor mirror. No upstream `CONTRIBUTING.md` or `.github/ISSUE_TEMPLATE/` bug template was found in the checked root paths, so the draft used a plain maintainer-friendly structure with `In Plain English`, environment, exact repro, expected vs actual behavior, ruled-out branches, and artifact pointers. After the final presentation-side pass landed, the draft was refreshed to include the decisive `Direct Texture (Canvas Overlay)` and `No Present` evidence plus the final `gdgs-blit-pass-qa` summaries/logs. Derrick then approved the final text and the issue was filed upstream as `ReconWorldLab/godot-gaussian-splatting#12`. References validated: `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-06`, `REF-07`, `REF-08`. 

---

### Task 2: Attempt one last ultra-narrow BLIT/presentation-side local pass

**Bead ID:** `oc-5fi`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Using the current vendor control scene and harness, attempt one last ultra-narrow local pass focused only on the enabled presentation/writeback side near `BLIT_PASS`. Do not reopen wrapper/setup/depth-logic branches. Prefer the smallest plausible experiments around final writeback/present/blit mechanics, preserving the ability to compare against the existing control scene and artifacts. Claim the assigned bead on start, run relevant validation, commit/push before handoff unless blocked, and report clearly whether anything changed the failure class.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/gdgs_tweak_matrix_harness.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scripts/build_control_scene.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/scenes/gdgs_happy_path_control.tscn`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/render-path-tweak-matrix.md`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/docs/happy-path-control-scene.md`

**Status:** ✅ Complete

**Results:** Landed one last ultra-narrow presentation-side pass with two new display-mode experiments in `gaussian_compositor_effect.gd`: `No Present`, which still runs `render_for_compositor()` but skips all compositor writeback/presentation work, and `Direct Texture (Canvas Overlay)`, which bypasses compositor image writeback and presents the GDGS color texture through a fullscreen `TextureRect` on a `CanvasLayer`. The prior direct-texture branch remains as `Direct Texture (World Overlay)`. The harness/HUD/docs were updated so QA can cycle `Compositor`, `Direct Texture (World Overlay)`, `Direct Texture (Canvas Overlay)`, and `No Present`. Validation passed for scene regeneration, headless import, and short smoke load. Commit pushed: `0978b07` (`Add GDGS presentation-side BLIT test modes`). This did not change runtime truth yet by itself, but it set up the decisive final local probes: if `No Present` is stable, the fault narrows further into presentation/writeback; if it still dies, the boundary moves earlier despite valid compositor textures. References validated: `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`. 

---

### Task 3: QA the ultra-narrow pass on the real machine

**Bead ID:** `oc-120`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-05`, `REF-06`, `REF-07`  
**Prompt:** Verify the ultra-narrow BLIT/presentation-side pass on the actual machine/backend. Capture whether the failure class changes at all, and compare directly against the current happy-path/tweak-matrix baselines. Claim the assigned bead on start and close it only when the comparison is complete.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/run_summary.tsv`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/compositor.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/effect_disabled.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/direct_texture_world.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/direct_texture_canvas.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/logs/no_present.log`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/effect_disabled.png`
- `/home/derrick/.openclaw/workspace/.temp/gdgs-blit-pass-qa/effect_disabled.json`

**Status:** ✅ Complete

**Results:** QA ran the new presentation-side branches on the real desktop Vulkan backend with fresh processes per branch. The result is decisive and harsher than hoped: `No Present` is not stable. `Compositor`, `Direct Texture (World Overlay)`, `Direct Texture (Canvas Overlay)`, and `No Present` all still abort with the same black-frame + Vulkan device-loss class, while only the effect-disabled baseline remains stable—and still blank. The strongest new evidence is from `No Present`: logs prove compositor callback entry, manager discovery, valid color/depth compositor textures, and an explicit message that all writeback/presentation work was skipped, yet the run still dies with `Last known breadcrumb: BLIT_PASS`. That means the fault boundary is even sharper now: it is not just compositor image writeback, not just world-vs-canvas overlay presentation, and not fixed by skipping explicit GDGS script-side present/writeback work. References validated: `REF-05`, `REF-06`, `REF-07`. 

---

### Task 4: Audit whether local testing is truly exhausted

**Bead ID:** `oc-311`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** Independently audit the issue-package draft plus the ultra-narrow BLIT/presentation-side pass. Decide whether local testing is genuinely exhausted and whether the upstream issue package is ready for filing. Claim the assigned bead on start and close it only if the next move is evidence-backed and unambiguous.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-gdgs/.plans/2026-05-15-gdgs-upstream-issue-package-and-blit-pass.md`

**Status:** ✅ Complete

**Results:** Independent audit initially caught that the issue draft lagged one pass behind the final `0978b07` / `gdgs-blit-pass-qa` evidence. After refreshing `docs/upstream-issue-draft.md` with the decisive final `No Present` and `Direct Texture (Canvas Overlay)` results, the audit condition was satisfied: local testing was exhausted enough, no meaningful local workaround remained, and the upstream issue package was truly ready for escalation. The bead was then closed with the evidence-backed conclusion that happy-path, tweak-matrix, and ultra-narrow no-present passes all converge on the same `BLIT_PASS`-adjacent device-loss boundary after valid compositor textures exist. References validated: `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`. 

---

## Final Results

**Status:** ✅ Complete

**What We Built:** We built a complete upstream-escalation package around the GDGS renderer-path failure and exhausted the last meaningful local branch before filing. That included a maintainer-friendly upstream issue draft, a final ultra-narrow presentation-side pass (`No Present`, `Direct Texture (Canvas Overlay)`, and `Direct Texture (World Overlay)`), a real-machine QA comparison of those modes, and the final upstream filing after the draft was refreshed with the decisive `No Present` evidence.

**Reference Check:** `REF-03` and `REF-04` provided the completed happy-path and tweak-matrix baselines that justified this final escalation slice. `REF-05`, `REF-06`, and `REF-07` were the critical control repo and artifact sets used to prove the failure survives even after valid compositor textures exist and script-side present/writeback is skipped. `REF-08` remained consistent with the vendor-side findings rather than exposing an AeroBeat-specific delta. `REF-01` / `REF-02` stayed relevant because the final report was aligned to the original upstream repo surfaces and was ultimately filed there as issue `#12`.

**Commits:**
- `0978b07` - `Add GDGS presentation-side BLIT test modes`

**Lessons Learned:** The last useful local question was not “can we keep trying random plugin branches,” but “can we prove the crash survives even when explicit script-side present/writeback is skipped?” Answering that with `No Present` made the upstream report materially stronger. For the next session, the right move is source-level investigation in the original GDGS repo to look for a likely culprit and assess whether a targeted PR is feasible.

---

*Completed on 2026-05-15*
