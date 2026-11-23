# Fold Adventure

A small top-down action-adventure in Godot 4, made for the Galaxy Z Fold, with a DS-style two-screen layout.
There is no art yet: everything is drawn with placeholder shapes.

## What's in it

- **DS layout:** a handheld console body with two equal halves. The game is on the top screen. The bottom screen has hearts, the area name, a mini-map, a D-pad, an A/B/X/Y diamond and a pause button.
  Screens stack top/bottom on tall or square displays (Fold folded or open) and go side by side on wide ones (landscape, laptop).
- 8-way movement with 4-way facing, sword swing, knockback and invincibility frames
- Blob enemies that wander, then chase you
- Three connected areas (Field, Cave, Lake). Doors stay locked until every enemy in the area is beaten.
- Hearts with half-hearts, heart pickups and drops
- Music and sound effects, with on/off switches in the pause menu (remembered between sessions)

## Controls

| Action | Phone (bottom screen) | Laptop |
|--------|----------------------|--------|
| Move   | D-pad: hold anywhere on the left half (8 directions) | WASD / arrow keys, or click the D-pad |
| A: sword | A button (red) | Space / J / Z |
| B, X, Y (spare, not used yet) | B / X / Y buttons | K or X / I or C / U or V |
| Pause  | II button | Esc / P |

The pause menu has Music, Sound effects and Shell colour options.

## Getting started

1. Install **Godot 4.7** or newer (standard version, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** to run.

## Project layout

```
project.godot             display settings for the DS layout
scenes/main.tscn          entry scene (runs ds_shell.gd)
sounds/                   sound effects + bgm.wav (replace with your own .wav files)
scripts/ds_shell.gd       the console body and the two screens (layout, scaling, colours)
scripts/bottom_screen.gd  hearts, mini-map, D-pad, A/B/X/Y buttons, pause menu
scripts/main.gd           the World: area maps, doors, spawning, game flow
scripts/player.gd         hero movement, attack, health
scripts/enemy.gd          blob enemy AI
scripts/game_audio.gd     music + sound effects, saved settings
scripts/hud.gd            messages on the top screen
scripts/heart_pickup.gd, heart_shape.gd, layers.gd
```

## Adding an area

In `scripts/main.gd`:
1. Add a map to `AREAS`. Put a door digit (e.g. `3`) on its edge, and the same digit on the edge of the area it connects to.
2. Add both directions to `DOORS`.
3. Give it a floor colour in `FLOOR_COLORS` and a mini-map spot in `MAP_POS`.

## Running on the Fold

Export with **Project → Export → Android**. Tick **arm64-v8a** for the phone, and also **x86_64** for the emulator.
