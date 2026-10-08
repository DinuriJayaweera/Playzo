# Arrow Escape (Playzo)

A colourful, endless arrow puzzle game for Android and iOS, built with Flutter and SQLite.

Tap an arrow to slide it off the dotted board. Arrows only move up, down, left or right, and only when nothing is in their way. Clear every arrow to finish the level.

## Features

- **Unlimited levels.** Every level is generated from its number, so the road never ends and a level is the same each time you replay it.
- **Gets harder as you go.** Boards grow, arrows get longer and twist more, and arrows block each other in more tangled ways.
- **Shaped boards.** Arrows are packed tightly into rectangles, hearts, circles, triangles, diamonds, stars, hexagons, crosses, rings and houses.
- **Always solvable.** Levels are built backwards from a valid solution, so a level can never reach a dead end.
- **3 hearts.** Tapping a blocked arrow bumps it, flashes it red and costs a heart. Lose all three and you retry the level.
- **Hints.** A hint makes a free arrow glow. You start with 5 and earn 1 for each new level you clear.
- **Level road.** A winding road shows cleared levels in gold with their stars, your current level pulsing, and locked levels ahead. Replay any cleared level; the next one unlocks only after you clear the current one.
- **Level strip.** During play, a mini road shows which level you're on.
- **Stars and score.** No mistakes earns 3 stars. Score grows with the level, your stars and how fast you clear it.
- **Leaderboard.** A podium and ranking of every player on the device, by total best score.
- **Music and sound effects.** An original looping chiptune and effects for taps, escapes, mistakes, wins and hints. Each can be turned on or off.
- **Help.** A how-to-play sheet, shown automatically on first launch and available from the game screen.
- **Arrowy, the mascot.** A cheerful yellow arrow character, drawn in code, who waves hello on the home screen, stands at your current level on the road, points at hints, cheers when you win, gets sad on mistakes, explains the rules and asks your name on first launch. Arrowy is also the app icon.
- **Dark mode.** Choose Light, Dark or Auto (follows the phone) in Settings, or flip it with the sun/moon button on the home screen. The choice is saved.
- **Multiple players.** Create players and switch between them; each has their own progress.
- **Pinch to zoom** on big boards.

## Running

```bash
flutter pub get
flutter run            # with a phone or emulator connected
flutter test           # generator, database and gameplay tests
```

## Project layout

```
lib/
  main.dart                     app start-up, lifecycle (pauses music in background)
  app_state.dart                active player, progress, settings (ChangeNotifier)
  game/
    models.dart                 Dir, Cell, Arrow, Level
    shapes.dart                 board outlines (heart, star, ring, ...)
    level_generator.dart        endless, deterministic, always-solvable levels
    game_state.dart             rules: taps, hearts, hints, stars, score
  data/game_repository.dart     SQLite (sqflite) persistence
  services/audio_service.dart   music + sound effects (audioplayers)
  ui/
    theme.dart                  light and dark palettes, theme
    widgets/                    board painter, buttons, hearts, shape icons, mascot
    screens/                    home, level road, game, leaderboard, help, settings
assets/audio/                   generated music and sound effects
tool/generate_audio.py          re-creates assets/audio (needs numpy + ffmpeg)
test/                           unit and widget tests
```

## How levels are generated

1. Choose the board outline and size for the level number. Size, arrow length and how much arrows bend all increase with the level.
2. Walk the cells from the centre outwards, with some randomness, growing a snake-shaped arrow from each free cell.
3. Keep an arrow only if its escape path to the edge is clear of every arrow placed before it.
4. Fill leftover gaps by extending arrow tails, but only where that keeps step 3 true.

Removing the arrows in the reverse of the placement order always works. Removing an arrow can only open paths, never close them, so any order of valid moves also clears the board.

## Database schema (SQLite)

| table           | columns                                                                 |
|-----------------|-------------------------------------------------------------------------|
| `players`       | `id`, `name` (unique), `hints`, `created_at`                             |
| `level_results` | `player_id`, `level`, `stars`, `best_score`, `best_time_ms`, `completed_at` |
| `settings`      | `key`, `value` (current player, music, sound effects, theme, help seen)  |

The leaderboard is a `GROUP BY` over `level_results`. It's local to the device; an online leaderboard would need a backend (for example Supabase/Postgres or Firebase) to sync these tables.
