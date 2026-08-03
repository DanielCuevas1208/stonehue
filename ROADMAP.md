# Roadmap

This document plans the releases after 0.1.0.
Each release stands on its own.
A release is independent when the core works without the new features.

## 0.2.0 - Records

Goal: save and load games.

- Import and export the Smart Game Format (SGF)
- Add the GTP `loadsgf` and `printsgf` commands
- Record the move history in the engine
- Replay a game from a record

This release makes Stonehue useful as a study tool.

## 0.3.0 - Search depth

Goal: use the search time better.

- Add a transposition table for repeated positions
- Add pondering during the opponent turn
- Reuse the search tree between moves
- Add `gogui-interrupt` for move cancellation

This release targets stronger play at the same budget.

## 0.4.0 - Pattern playouts

Goal: improve the playout policy.

- Add local pattern heuristics for random moves
- Add capture-and-extend sequences to the playouts
- Scale the playout length with the board size
- Tune the strength levels with self-play

This release completes the first engine family.
