# Classic Adventure

A small top-down action-adventure in Godot 4, made for the Galaxy Z Fold, with a DS-style two-screen layout.
There is no art yet: everything is drawn with placeholder shapes.

## What's in it

- **Two console styles, picked automatically:**
  - **Classic** on ordinary phones: a single-screen handheld with the game screen at the top and the D-pad, A/B/X/Y buttons and MENU button on the body below (or either side when held sideways). Hearts and the maps are shown on the game screen.
  - **Dual** on Samsung Galaxy Z Fold phones (folded or open), tablets and squarish windows: a clamshell with two equal halves. The game is on the top screen, which is wider (24 tiles across) to fill its half. The bottom screen shows hearts, the area name, the pause button, the area and world maps and how many enemies are left, with the D-pad and A/B/X/Y buttons on the body either side of it.
  - If the phone's camera punch hole would cover the D-pad or buttons, they move up or down out of its way automatically (Android reports where the hole is).
  - The pause menu's **Console** option switches between Auto, Classic and Dual. Auto spots a Fold by its model number (SM-F9xx).
- 8-way movement with 4-way facing, sword swing, knockback and invincibility frames
- Blob enemies that wander, then chase you
- **Level select** when the game starts: pick a level (the chosen level is previewed on the top screen in Dual) and press START. Levels you've beaten are marked "cleared" and remembered. The pause menu's **Level select** goes back to it.
- **Three levels**, each a set of connected areas. Doors stay locked until every enemy in the area is beaten. Clear every area to finish the level ("LEVEL 1 CLEAR!") and move on; beat the last one for "GAME CLEAR!" (press A to go back to the level select).
  - Level 1 *Green Fields*: Field, Cave, Lake
  - Level 2 *Desert Ruins*: Dunes, Ruins, Oasis, Tomb (enemies take 3 hits and are faster)
  - Level 3 *Frozen Castle*: Snowfield, Ice Cave, Castle Yard, Keep (faster still)
- A cleared area stays empty when you come back, and hearts you've picked up stay gone.
- Maps: a map of the area you're in (walls, water, doors, you, enemies and hearts) plus a small world map of all the areas: on the bottom screen in Dual, top-right of the game screen in Classic.
- Hearts with half-hearts, heart pickups and drops
- Music and sound effects, with on/off switches in the pause menu (remembered between sessions)

## Controls

| Action | Phone (bottom screen) | Laptop |
|--------|----------------------|--------|
| Move   | D-pad: hold anywhere on the left half (8 directions) | WASD / arrow keys, or click the D-pad |
| A: sword | A button (red) | Space / J / Z |
| B, X, Y (spare, not used yet) | B / X / Y buttons | K or X / I or C / U or V |
| Pause  | II button (Dual) or MENU button (Classic) | Esc / P |

The pause menu has Music, Sound effects, Console style, Shell colour and Level select options. On the level select, use the arrow keys and Space/Enter on a keyboard, or tap.

## Getting started

1. Install **Godot 4.7** or newer (standard version, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** to run.

## Project layout

```
project.godot             display settings for the DS layout
scenes/main.tscn          entry scene (runs ds_shell.gd)
sounds/                   sound effects + bgm.wav (replace with your own .wav files)
scripts/ds_shell.gd       the console body: Classic or Dual style, layout, scaling, colours
scripts/bottom_screen.gd  D-pad, A/B/X/Y buttons, pause menu (+ the bottom screen in Dual)
scripts/main.gd           the World: area maps, doors, spawning, game flow
scripts/player.gd         hero movement, attack, health
scripts/enemy.gd          blob enemy AI
scripts/game_audio.gd     music + sound effects, saved settings
scripts/hud.gd            messages on the game screen (+ hearts and mini-map in Classic)
scripts/heart_pickup.gd, heart_shape.gd, layers.gd
```

## Adding areas and levels

Everything is in `LEVELS` at the top of `scripts/main.gd`. Each level has a name, a start area, enemy toughness (`enemy_hp`, `enemy_speed`), and four tables:
1. `areas`: the ASCII maps. Put a door digit (e.g. `3`) on an area's edge, and the same digit on the edge of the area it connects to.
2. `doors`: where each digit leads, both directions.
3. `map_pos`: where each area sits on the world map.
4. `floors`: two floor colours per area.

To add a level, copy a whole `{ ... }` block in `LEVELS` and change it.

## Running on the Fold

Export with **Project → Export → Android**. Tick **arm64-v8a** for the phone, and also **x86_64** for the emulator.
