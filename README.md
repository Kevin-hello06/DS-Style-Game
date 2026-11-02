# Fold Adventure

A small top-down action-adventure prototype in Godot 4, set up for the Galaxy Z Fold.
It has no art assets yet: everything is drawn with placeholder shapes, so it runs as soon as you open it.

## What's in it

- 8-way movement with 4-way facing, sword swing, knockback and invincibility frames
- Blob enemies that wander, then chase you when you get close
- Hearts HUD with half-hearts, heart pickups and random heart drops
- An "Area cleared!" message, and a restart when you die
- A world built from an ASCII map in `scripts/main.gd`, which you edit to make new areas
- Touch controls (floating joystick + attack button), shown only on touchscreens
- Screen settings that adapt when the Fold opens/closes: `expand` aspect plus integer pixel scaling

## Controls (desktop)

| Action | Keys |
|--------|------|
| Move   | WASD / arrow keys |
| Attack | Space / J / Z |

## Getting started

1. Install **Godot 4.3 or newer** (standard version, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** to run.

## Git

```bash
git remote add origin <your-repo-url>
git push -u origin main
```

`.godot/` is ignored because it's a cache the editor rebuilds.
When you add lots of art and audio, consider [Git LFS](https://git-lfs.com) for `*.png`, `*.wav` and similar files.

## Running on the Fold 7

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. Install Android Studio (for the SDK) and JDK 17. Set both paths in **Editor Settings → Export → Android**.
3. On the phone: enable **Developer options → USB debugging** and connect it by cable.
4. **Project → Export → Add… → Android**. The defaults are fine for testing.
5. Click the Android **Remote Deploy** button in the editor's top-right toolbar to install and run on the phone.

Test it folded and unfolded, and flip between them while playing.

## Project layout

```
project.godot          display/stretch settings tuned for the Fold
scenes/main.tscn       entry scene (just runs main.gd)
scripts/main.gd        map, spawning, input actions, game flow
scripts/player.gd      hero movement, attack, health
scripts/enemy.gd       blob enemy AI
scripts/heart_pickup.gd
scripts/hud.gd         hearts + messages
scripts/touch_controls.gd
scripts/heart_shape.gd shared heart drawing
scripts/layers.gd      collision layer constants
```

## Next steps

- Replace `_draw()` placeholder art with `AnimatedSprite2D` sprite sheets (Kenney.nl and itch.io have free ones).
- Swap the ASCII map for a `TileMapLayer` once you're designing real areas in the editor.
- Add screen-by-screen room transitions, keys and locked doors, and a boss.
- Add sound effects (sfxr/jsfxr is great for retro sounds).
