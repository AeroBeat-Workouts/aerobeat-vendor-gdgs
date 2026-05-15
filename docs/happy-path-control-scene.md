# GDGS happy-path control scene

This repo now includes a minimal Godot control project that follows the upstream GDGS README quick start as literally as practical.

## What it is

- Project root: `res://` at this repo root
- Main scene: `res://scenes/gdgs_happy_path_control.tscn`
- Plugin path: `res://addons/gdgs`
- Sample asset: `res://samples/assets/demo.compressed.ply`

## README parity

The control scene contains the exact README-required core pieces:

1. `GaussianSplatNode`
2. `WorldEnvironment`
3. `WorldEnvironment.compositor = Compositor`
4. a `CompositorEffect` whose script is `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`

Extras are intentionally minimal: one `Camera3D`, one `DirectionalLight3D`, and a small HUD label describing what QA is looking at.

## Regenerate the scene

If you want Godot to rebuild the scene file from the vendored plugin + imported sample resource:

```bash
~/.local/bin/godot --headless --path . --script res://scripts/build_control_scene.gd
```

## QA run

Import once, then run the main scene:

```bash
~/.local/bin/godot --import --headless --path .
~/.local/bin/godot --path .
```

Godot should open `res://scenes/gdgs_happy_path_control.tscn` as the project's main scene.

## Expected constraints

The upstream README requirements still apply:

- Godot 4.4+
- Forward Plus
- desktop GPU + compute shader support

Headless import is useful for validation, but visible render verification needs a real desktop renderer path.
