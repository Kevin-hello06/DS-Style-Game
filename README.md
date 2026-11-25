# Classic Adventure

A small top-down action-adventure in Godot 4, made for the Galaxy Z Fold, with a DS-style two-screen layout.
There is no art yet: everything is drawn with placeholder shapes.

## What's in it

- **Two console styles, picked automatically:**
  - **Classic** on ordinary phones: a single-screen handheld. Upright, the game screen sits in a dark glass lens at the top with big D-pad and A/B/X/Y buttons below and a MENU button at the bottom; sideways, the D-pad and buttons are either side of the screen. Hearts and the maps are shown on the game screen.
  - **Dual** on Samsung Galaxy Z Fold phones (folded or open), tablets and squarish windows: a clamshell with two equal halves. The game is on the top screen, which is wider (24 tiles across) to fill its half. The bottom screen shows hearts, the area name, the pause button, the area and world maps and how many enemies are left, with the D-pad and A/B/X/Y buttons on the body either side of it.
  - **Camera punch holes, notches and Dynamic Island:** a cutout at the top or bottom edge moves the screens and controls clear of it (using the safe area the phone reports), while the console body still runs to the edges. A cutout at a side, like the Fold 7's camera on the buttons' side in Dual, doesn't move the layout: the D-pad or buttons step up or down out of its way instead.
  - **Fold 7 opened sideways (Dual):** the inner camera sits halfway down the right edge of the lower half, so (same layout as the kart game) the D-pad and A/B/X/Y sit a little below halfway down, mirrored (the D-pad is as far from the left edge as A is from the right edge), with A/B/X/Y just far enough in that A keeps about 7 mm clear of the camera, even if Android doesn't report the hole. Tune `FOLD_BELOW_MIDDLE` and `FOLD_HOLE_CLEAR` in `scripts/ds_shell.gd`.
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

The pause menu has Music, Sound effects, Console style, Shell colour, Screen and Level select options. **Screen: Fill** (the default) runs the console edge to edge across the whole display with square corners, stretching the body (and, in Dual, both halves, split by a dark hinge band) to fit; **Screen: Sharp** keeps whole-number scales for the crispest pixels, with dark space around. On the level select, use the arrow keys and Space/Enter on a keyboard, or tap.

## Previewing phone screens on the laptop

Press **F2** while the game is running to cycle through phone shapes inside the window, whatever size it is:
Phone upright, Phone sideways, Fold 7 cover, Fold 7 open, Fold 7 open sideways, and back to Off.
Each shows the console exactly as it would lay out on that screen, with a rough camera punch hole drawn in (black dot) so you can check nothing important sits under it. The Fold 7 previews use the Fold's Dual style, as the real phone would.

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
