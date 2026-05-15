# GDGS render-path tweak matrix

This control project now includes a tiny in-scene harness for exercising the approved render-path matrix on this exact machine.

## Scene

- Main scene: `res://scenes/gdgs_happy_path_control.tscn`
- Harness script: `res://scripts/gdgs_tweak_matrix_harness.gd`
- Compositor effect: `res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd`

## What QA can toggle live

While the scene is running:

- `C` — toggle the compositor effect `enabled` flag
- `M` — cycle `display_mode`
  - `Compositor`
  - `Direct Texture`
- `D` — cycle `debug_view`
  - `Composite`
  - `GS Alpha`
  - `GS Color`
  - `GS Depth`
  - `Scene Depth`
  - `Depth Reject Mask`
- `I` — toggle `ignore_scene_depth_in_composite`

The HUD in the top-left corner shows the current state after each change.

## Intended matrix order

Run the small matrix in this order so logs and behavior stay easy to compare:

1. Baseline: effect enabled, `display_mode=Compositor`, `debug_view=Composite`, `ignore_scene_depth_in_composite=false`
2. Effect disabled baseline
3. `display_mode=Direct Texture`
4. Back to `display_mode=Compositor`, then cycle `debug_view` through:
   - `GS Alpha`
   - `GS Color`
   - `GS Depth`
   - `Scene Depth`
   - `Depth Reject Mask`
   - `Composite`
5. With `debug_view=Composite`, toggle `ignore_scene_depth_in_composite=true`

## Logging added

The compositor path now logs once per run to prove:

- chosen display/debug/depth-bypass settings
- whether the compositor callback was entered
- whether the render manager was found
- whether `render_for_compositor()` returned valid textures
- whether a compositor dispatch was about to run

The renderer also logs once when it prepares compositor render targets.

## Suggested QA launch flow

```bash
~/.local/bin/godot --import --headless --path .
~/.local/bin/godot --path .
```

Use the Godot editor output or terminal logs to capture the once-per-run instrumentation while stepping the matrix.
