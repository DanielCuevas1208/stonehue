# Changelog

All notable changes to Stonehue appear in this file.
The format follows the Keep a Changelog convention.
This project uses semantic versioning.

## Unreleased

No changes yet.

## 0.2.0 - 2026-08-03

Records release.

Added:

- SGF import and export in the Smart Game Format (FF[4])
- GTP `loadsgf` and `printsgf` commands
- Engine move history with undo support
- Handicap setup recorded in SGF output
- Sample SGF game record and SGF session in the examples folder
- `scripts/save-game.lisp` to write a self-play record

Fixed:

- `set_free_handicap` now leaves the turn with Black
- GTP error replies no longer fail on errors with no message text

## 0.1.0 - 2026-08-03

First coherent release.

Added:

- Boards from 3 by 3 to 19 by 19 over GTP
- Capture rules with the simple ko rule
- Simple Chinese area scoring with komi
- Monte Carlo tree search with UCT
- Five strength levels from 1 to 5
- Time controls with main time and byo-yomi
- Opening pattern hints for the first moves
- Handicap points and handicap commands
- GTP server with standard commands and GoGui support
- Deterministic search with a fixed random seed
- FiveAM test suite with fixture replay
- Sample session and sample game in the examples folder
