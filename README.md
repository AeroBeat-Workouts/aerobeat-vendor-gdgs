# AeroBeat Vendor - gdgs

`aerobeat-vendor-gdgs` pins and redistributes the upstream MIT-licensed
[`ReconWorldLab/godot-gaussian-splatting`](https://github.com/ReconWorldLab/godot-gaussian-splatting)
plugin (`gdgs`) for AeroBeat.

## Boundary

This repo is the **vendor lane** only.

- It stores the pinned upstream plugin payload under `addons/gdgs/`.
- It is **not** the AeroBeat-facing runtime API surface.
- Product/testbed repos should consume the stable AeroBeat wrapper from
  `aerobeat-tool-gaussian-splat`.
- When a GodotEnv manifest needs the raw plugin path for runtime/editor support,
  it should point to this repo's `addons/gdgs` subfolder rather than fetching
  third-party upstream directly.

## Pin

- Upstream: `ReconWorldLab/godot-gaussian-splatting`
- Upstream version: `2.2.0`
- Pinned upstream commit: `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`
- License: MIT

## Layout

- `addons/gdgs/` - vendored upstream plugin payload used by Godot projects.
- `samples/assets/` - upstream sample splat assets copied locally for validation.
- `docs/upstream-pin.md` - pinning notes for future updates.

## Consuming via GodotEnv

Use the repo URL with the `addons/gdgs` subfolder so the installed addon lands at
`res://addons/gdgs` and the upstream hardcoded paths continue to work.

```jsonc
{
  "addons": {
    "gdgs": {
      "url": "git@github.com:AeroBeat-Workouts/aerobeat-vendor-gdgs.git",
      "checkout": "main",
      "subfolder": "/addons/gdgs"
    }
  }
}
```

## Clean restore guidance for consuming repos

`aerobeat-vendor-gdgs` intentionally stays a raw vendor pin, so the delete-first
restore helpers live in the consuming repos that own the GodotEnv workbenches.
For the current AeroBeat consumers, use:

- `aerobeat-tool-gaussian-splat/scripts/restore-testbed-addons.sh`
- `aerobeat-environment-community/scripts/restore-testbed-addons.sh`

Those helpers clear the generated install targets first (`.testbed/addons/*`
except `.editorconfig`, plus `.testbed/.addons/`) and then rerun
`godotenv addons install`. That is the canonical fix when Godot-generated import
artifacts make a gdgs reinstall non-idempotent.
