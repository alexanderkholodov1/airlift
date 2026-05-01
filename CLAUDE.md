# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 2D narrative adventure called **airlift**. Renderer: Forward Plus, Windows graphics driver `d3d12`, physics: Jolt. The player (Logan) traverses tutorial → forest → cavern → limbo → boss, with dialogue, climbing, object-grab, and portal-based level transitions.

In-game text, dialogue, comments, and class/variable names mix Spanish and English (Spanish dominates for narrative/UX strings, e.g. `jugar`, `ladrillo`, `parca`, `puede_trepar`). Preserve the existing language when editing — don't translate identifiers.

## Running and editing

- No CLI build/test pipeline. Open the project by launching Godot 4.6 against `project.godot`, or `godot --path . --editor` / `godot --path .` to run the main scene.
- Main scene is referenced by UID in `project.godot` (`run/main_scene="uid://bnckp0gupk2ey"`) — that points at `scenes/Main_Scene.tscn`. UIDs (`*.uid`) and the `.godot/` cache are gitignored, so a fresh clone needs one editor open to regenerate them before scripts that load by `res://` path will resolve.
- Export config lives in `export_presets.cfg`.

## Architecture

### Autoloads (singletons)

The engine-registered autoload list in `project.godot` currently only contains `SceneTransition` (`scripts/scene_transition.gd`). However, code references two other autoload-style singletons that must also be registered in **Project Settings → Autoload** for the game to run:

- `GameFlow` → `scripts/game_flow.gd` — pause menu lifecycle, restart-current-level, go-to-main-menu, quit, and floating pause-button injection. Listens for the `pause_game` input action (also not currently in `project.godot`'s `[input]` map — only `skip` is defined there; this needs to be added in Project Settings → Input Map).
- `EndRunState` → `scripts/end_run_state.gd` — static-only `RefCounted` class storing the player's ending name/mode/statistics across the credits transition. Cleared by `GameFlow.go_to_main_menu()`.

If you add new globally-needed state, follow the same pattern (autoload node, or static-only class accessed via `class_name`).

### Scene transitions (two parallel systems)

There are two scene-change paths and they are **not interchangeable**:

1. **Portal-driven (`SceneTransition.go_to_scene`)** — used in-game. Handles fade-out → `change_scene_to_file` → fade-in, and *re-spawns the player* at the matching arrival portal in the destination scene. The `ARRIVAL_PORTAL_BY_SOURCE` dictionary in `scripts/scene_transition.gd` is the source of truth: every new portal name must be registered there or arrival positioning silently breaks. Player detection in the destination is duck-typed: `_find_first_player_body()` looks for a `CharacterBody2D` with method `_try_interact_with_arches` or `intentar_agarrar_objeto`, falling back to a node literally named `Logan` or `CharacterBody2D`.
2. **Menu/flow-driven (`GameFlow.go_to_scene` / `restart_current_level` / `go_to_main_menu`)** — used by pause menu and credits. Does not fade or re-position; just unpauses, tears down the pause UI, and calls `change_scene_to_file`. After every successful change it calls `_update_pause_button` to add the floating pause button to gameplay scenes and skip it on menu/credit scenes (set in `NON_GAME_SCENES`).

The default-route `SCENE_ROUTES` table in `SceneTransition` is only used by `go_to_next()` (no portal context). Most navigation goes through `go_to_scene(target, source_portal_name)`.

### Player (`scripts/logan.gd`)

`CharacterBody2D` with mouse-only controls — there is no keyboard movement:
- **LMB held**: walk toward mouse position.
- **RMB held while in liana area** (`puede_trepar` flag set by `Liana.gd`): climb; mouse Y relative to player drives `velocity.y`. LMB while climbing detaches.
- **RMB tap (not climbing)**: grab/drop the object inside `$Area2D`, parented at `$Marker2D`.

Logan exposes `health_changed` and `player_died` signals and instantiates `scenes/ui/death_screen.tscn` on death. `speed` and several slope/step-assist params are `@export`-tunable per-scene (the Tutorial scene uses a reduced speed).

### Subsystems

- `scripts/persecution/` — chase-level managers (`persecution_level_manager.gd`, `persecution_enemy_spawner.gd`, `level_populator.gd`).
- `scripts/purification/` — heart-UI / decision-graph driven scoring (`purification_manager.gd`, `purification_resource.gd`, `ui/`). Backed by scenes `scenes/ui/purification_*.tscn`.
- `scripts/dialogue.gd` (used by `scenes/Tutorial.tscn`) — sequential dialogue with optional `action` gates (`move`, `pickup`, `drop`) that block advancement until the player performs the action; also drives an on-screen `ActionPrompt` UI.

### UI scenes (`scenes/ui/`)

`pause_menu`, `pause_button` (floating, injected by `GameFlow`), `settings_menu` (writes `user://display_settings.cfg`), `menu_credits`, `death_screen`, plus purification HUD pieces.

## Conventions and gotchas

- **Don't add `pause_game` or other input actions silently** — they must be configured in `project.godot` under `[input]`. The current map only defines `skip`. If you reference a new action from a script, add it to the input map in the same change.
- **Adding a new scene to the navigation graph** requires touching three places: register portals in `ARRIVAL_PORTAL_BY_SOURCE`, optionally add a default route in `SCENE_ROUTES`, and decide whether the scene path belongs in `GameFlow.NON_GAME_SCENES` (skips pause/floating button).
- **`@onready` paths in scripts assume specific scene tree shapes** (`$CanvasLayer/DialogueBox/Label`, `$Area2D`, `$Marker2D`, etc.). When restructuring a scene, search the matching `.gd` for `$` and `@onready` before moving nodes.
- `PROJECT_CONTEXT.md` at the repo root is a Spanish design/status doc maintained by hand — read it for narrative/design intent, but treat the code as authoritative for behavior.
