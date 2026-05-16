# GDGS upstream PR prep notes

_Last reviewed: 2026-05-16_

## Upstream repo surface

- Upstream repo: `https://github.com/ReconWorldLab/godot-gaussian-splatting`
- Default branch: `main`
- Current upstream `main` commit: `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`
- Local vendor pin matches upstream `main` exactly as of this review.

## Contribution guidance found

Guidance is sparse.

Observed repo surfaces:

- no root `CONTRIBUTING.md`
- no `.github/CONTRIBUTING.md`
- no visible PR template
- no visible issue template

Observed maintainer behavior from accepted community PRs:

- PR `#6` (`Icons, Visibility and Instancing`) targeted `main` and was merged after conversational review.
- PR `#9` (`Fix for VR rendering support`) targeted `main` from a dedicated topic branch and was merged after a brief maintainer comment.

Practical takeaway: upstream appears open to small, directly scoped PRs against `main`, with plain-language context and local validation in the PR body rather than a formal checklist.

## Existing issue context

- Existing upstream issue: `#12`
- URL: `https://github.com/ReconWorldLab/godot-gaussian-splatting/issues/12`

Issue `#12` is useful background because it records the broader Intel Iris Xe / Wayland / Vulkan repro and the investigation path that led to the confirmed push-constant bug.

However, it is broader than the fix now ready for upstreaming. If we open a PR for the radix push-constant change, the PR should:

1. explicitly reference issue `#12`
2. explain that the issue investigation exposed a confirmed radix push-constant contract mismatch
3. state that this PR fixes that confirmed mismatch only
4. avoid claiming that it resolves the later `BLIT_PASS` / device-loss failure

## Recommended branch strategy

Do **not** upstream from the current local test branch `test/oc-xok-gdgs-radix-push-constant-contract`.

Reasons:

- the branch includes multiple investigation/doc commits that do not belong in the upstream PR
- the fix commit `bc06934` also contains local plan/doc files that are vendor-lane artifacts, not upstream repo content
- the local working tree is currently dirty with unrelated plan/doc edits

Recommended handoff:

1. start from a clean branch based on upstream `main`
2. replay only the minimal runtime-code fix touching:
   - `addons/gdgs/runtime/render/gaussian_renderer.gd`
   - `addons/gdgs/runtime/render/gaussian_rendering_device_context.gd`
3. make the upstream PR a single narrow commit if practical
4. reference issue `#12` in the PR body while clarifying that scope is limited to the confirmed push-constant contract bug

If the local `bc06934` commit is reused, cherry-pick it onto a clean branch and then immediately remove any non-upstream doc/plan files before recommitting or amending.

A cleaner option is to manually reapply the two runtime-file hunks onto the fresh branch and commit only those code changes.
