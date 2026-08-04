# Roadmap

Each release keeps the engine usable without its next feature.
Status labels describe repository work, not playing strength.

## Status

- 0.2.0 Records: complete
- 0.3.0 Search depth: in progress
- 0.4.0 Pattern playouts: planned
- 0.5.0 Richer records: planned

## 0.2.0 Records: complete

Goal: make games easy to save and study.

- Import and export SGF main lines.
- Add `loadsgf` and `printsgf`.
- Record engine moves.
- Replay records.
- Record handicap setup stones.

## 0.3.0 Search depth: in progress

Goal: use each search budget more effectively.

Complete in this slice:

- Add a state-safe transposition table.
- Share visit statistics for equivalent states.
- Report table hits and entries through GTP.
- Add deterministic tests for table state sharing.

Remaining work:

- Reuse the search tree after a move.
- Add pondering during the opponent turn.
- Add `gogui-interrupt` for move cancellation.

## 0.4.0 Pattern playouts: planned

Goal: improve random playout choices.

- Add local pattern heuristics.
- Add capture-and-extend sequences.
- Scale playout length with board size.
- Tune strength levels with self-play.

## 0.5.0 Richer records: planned

Goal: cover more SGF study data.

- Parse SGF variations and side lines.
- Keep player names and comments.
- Round-trip setup additions and stone-removal moves.