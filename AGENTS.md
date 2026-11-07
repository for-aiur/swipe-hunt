# Project Contribution Guide

## Project structure

- `project.godot` contains project and display settings.
- `scenes/main.tscn` is the application entry scene.
- `scripts/main.gd` contains input, round state, and rendering orchestration.
- `scripts/dungeon_map.gd` defines the fixed room graph and pathfinding.
- `scripts/pixel_art.gd` contains the small code-drawn character sprites and palettes.

## Development guidance

- Keep the game compatible with Godot 4 and runnable from the editor without external services.
- Show one room at a time. Keep room sizing responsive to the viewport and display safe area.
- Keep exits and blocked walls visually distinct while leaving rooms beyond the current view undisplayed.
- Preserve swipe and tap controls on touchscreens and their keyboard/mouse equivalents on desktop.
- Keep changes focused and update the README when setup, controls, or export steps change.

## Verification

- Open `project.godot` in Godot and run the main scene with **F5**.
- Check movement, attacks, wall recovery, and resizing on desktop; verify touch behavior on a device when the change affects input.
- Include the Godot version, platform, and steps to reproduce when reporting a runtime issue.

## Contributions

Keep pull requests focused. Describe user-visible behavior changes and the verification performed. The project is distributed under the MIT License in `LICENSE`.
