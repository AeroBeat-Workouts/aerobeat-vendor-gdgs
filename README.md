# AeroBeat Vendor - gdgs

`aerobeat-vendor-gdgs` pins and redistributes the upstream MIT-licensed
[`ReconWorldLab/godot-gaussian-splatting`](https://github.com/ReconWorldLab/godot-gaussian-splatting)
plugin (`gdgs`) for AeroBeat.

## Boundary

This repo is the **vendor lane** only.

- It stores the pinned upstream plugin payload under `src/`.
- It is **not** the AeroBeat-facing runtime API surface.
- Product/testbed repos should consume the stable AeroBeat wrapper from
  `aerobeat-tool-gaussian-splat-loader`.
- When a GodotEnv manifest needs the raw plugin path for runtime/editor support,
  it should point to this repo's `src` subfolder so the installed addon lands at
  `res://addons/gdgs`, rather than fetching third-party upstream directly.

## Pin

- Upstream: `ReconWorldLab/godot-gaussian-splatting`
- Upstream version: `2.2.0`
- Pinned upstream commit: `be61f8fd28cc9cb4a618a0a2e88591ea81bb17be`
- License: MIT

## Layout

- `src/` - vendored upstream plugin payload used by Godot projects.
- `samples/assets/` - upstream sample splat assets copied locally for validation.
- `docs/upstream-pin.md` - pinning notes for future updates.

## Consuming via GodotEnv

Use the repo URL with the `src` subfolder so the installed addon lands at
`res://addons/gdgs` and the upstream hardcoded paths continue to work.

```jsonc
{
  "addons": {
    "gdgs": {
      "url": "git@github.com:AeroBeat-Workouts/aerobeat-vendor-gdgs.git",
      "checkout": "main",
      "subfolder": "/src"
    }
  }
}
```

## Clean restore guidance for consuming repos

`aerobeat-vendor-gdgs` intentionally stays a raw vendor pin, so consumer repos
should use the repo-local GodotEnv restore flow from their own workbenches.
The current canonical pattern is:

```bash
find .testbed/addons -mindepth 1 -maxdepth 1 ! -name .editorconfig -exec rm -rf {} +
rm -rf .testbed/.addons
cd .testbed
godotenv addons install
```

That sequence clears the generated install targets first (`.testbed/addons/*`
except `.editorconfig`, plus `.testbed/.addons/`) and then reruns
`godotenv addons install`. That is the canonical fix when Godot-generated import
artifacts make a gdgs reinstall non-idempotent.
