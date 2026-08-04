# Stonehue

[![CI](https://github.com/DanielCuevas1208/stonehue/actions/workflows/ci.yml/badge.svg)](https://github.com/DanielCuevas1208/stonehue/actions/workflows/ci.yml)

Stonehue is a small-board Go engine.
It uses Monte Carlo tree search.
It speaks the Go Text Protocol (GTP).

Stonehue runs on SBCL with ASDF.
The test suite uses FiveAM.
The codebase uses Common Lisp.

## Value

Stonehue gives Go tools a compact engine for small boards.
It supports boards from 3 by 3 through 19 by 19 in GTP.

Use it to:

- play a local GTP game;
- inspect legal moves and captures;
- save and load SGF records;
- inspect deterministic search output;
- study a clear Common Lisp engine.

The project makes no claim about competitive playing strength.
Self-play files are sample data.

## Features

- capture rules and simple ko;
- Chinese-style area scoring with komi;
- Monte Carlo tree search with UCT;
- five strength levels;
- fixed-seed deterministic search;
- main time and byo-yomi budgets;
- opening hints and handicap commands;
- SGF main-line import and export;
- GTP version 2 commands;
- state-safe transposition statistics during each root search.

## Setup

Install SBCL.
Install FiveAM through Quicklisp or the operating system package.
Run commands from the repository root.

Start a GTP session:

```text
sbcl --load bin/stonehue.lisp
```

Send one GTP command per line.
Send `quit` to stop the session.

Run the test suite:

```text
sbcl --load scripts/run-tests.lisp
```

Check compilation warnings:

```text
sbcl --load scripts/check-clean.lisp
```

Build a standalone engine:

```text
sbcl --load scripts/build.lisp
```

The build writes `build/stonehue.exe`.
The output directory is ignored by Git.

## GTP session

This short session uses standard commands.

```text
boardsize 9
clear_board
komi 6.5
play b D4
play w F4
genmove b
showboard
quit
```

A small query returns this output:

```text
name
= Stonehue
version
= 0.2.0
quit
=
```

See [examples/sample-session.txt](examples/sample-session.txt) for a complete transcript.

## Search evidence

The search table lives for one root search.
Equivalent states share visit and win counts.
The state key includes these values:

- board contents;
- side to play;
- move number;
- simple-ko predecessor hash;
- consecutive passes;
- capture counts.

Tree edges remain local to their parent nodes.
This design keeps move analysis readable while sharing repeated-state evidence.

The GTP extension `stonehue_search_info` reports the last search table.
The public `mcts-search` function returns the same information as a third value.

Run the deterministic evidence session:

```text
sbcl --load bin/stonehue.lisp < examples/search-info-session.txt
```

The relevant output is:

```text
= pass
= transposition-hits 0
transposition-entries 1
```

The zero-iteration session records only its root state.
It demonstrates the table contract without a performance claim.

## Engine controls

| Command | Purpose |
| --- | --- |
| `stonehue_strength N` | Select strength level 1 through 5 |
| `stonehue_iterations N` | Set the exact MCTS iteration budget |
| `stonehue_seed N` | Reset the deterministic random seed |
| `stonehue_opening` | List opening hints |
| `stonehue_analyze` | List root move statistics |
| `stonehue_search_info` | Report transposition hits and entries |
| `loadsgf FILE [N]` | Load an SGF main line |
| `printsgf [FILE]` | Print or save the current SGF record |
| `time_settings M B S` | Set main time, byo-yomi, and stones |
| `kgs-time_settings M B S P` | Accept KGS time settings |

Strength levels use these default iteration budgets:

| Level | Iterations |
| --- | ---: |
| 1 | 120 |
| 2 | 400 |
| 3 | 1,000 |
| 4 | 3,000 |
| 5 | 9,000 |

`stonehue_iterations` overrides the strength budget.
Time settings use a wall-clock budget for each move.

## Architecture

| Module | Responsibility |
| --- | --- |
| `board` | Board storage and GTP coordinates |
| `rules` | Positions, captures, ko, and legal moves |
| `scoring` | Area scoring and result strings |
| `mcts` | UCT search, playouts, and transposition stats |
| `opening` | Opening hints and handicap points |
| `engine` | Engine state, controls, history, and search evidence |
| `sgf` | SGF parsing, writing, and replay |
| `gtp` | GTP parsing, dispatch, and replies |
| `random` | Seeded random number generation |
| `render` | ASCII board output |
| `packages` | Package names and version data |

The rules module owns mutable game state.
The engine records moves outside the rules module.
The search copies positions before simulations.
The transposition table owns shared search statistics.
The GTP layer converts conditions into protocol error replies.

## SGF records

Print the current game:

```text
printsgf
```

Save the current game:

```text
printsgf game.sgf
```

Load a record:

```text
loadsgf game.sgf
```

Load a partial main line:

```text
loadsgf game.sgf 24
```

See [examples/sample-sgf-session.txt](examples/sample-sgf-session.txt).

## Tests and CI

The FiveAM suite covers these areas:

- board coordinates;
- captures, suicide, and ko;
- area scoring;
- deterministic search;
- engine history and undo;
- transposition table state sharing;
- GTP replies and fixtures;
- SGF parsing, writing, and replay.

The CI workflow runs clean compilation.
It runs the FiveAM suite.
It builds the standalone engine.
It runs GTP and SGF smoke sessions.

Run the full local checks:

```text
sbcl --load scripts/check-clean.lisp
sbcl --load scripts/run-tests.lisp
sbcl --load scripts/build.lisp
```

## Limitations

- The search uses short random playouts.
- The search values material during playouts.
- Komi affects scoring but not playout value.
- Scoring does not remove dead stones.
- The rules implement simple ko, not superko.
- SGF replay follows the main line only.
- SGF variations and rich properties are not preserved.
- The transposition table resets for each root search.
- Search tree reuse is not available yet.
- Pondering and move interruption are not available.
- The GTP interface accepts boards from 3 by 3 through 19 by 19.
- The core accepts boards through 25 by 25.

## Roadmap

| Release | Status | Focus |
| --- | --- | --- |
| 0.2.0 | Complete | SGF records and replay |
| 0.3.0 | In progress | Search depth and reusable search work |
| 0.4.0 | Planned | Pattern-guided playouts |
| 0.5.0 | Planned | Richer SGF records |

The 0.3.0 slice now includes state-safe transposition statistics.
The remaining work includes tree reuse, pondering, and `gogui-interrupt`.

See [ROADMAP.md](ROADMAP.md) for release details.

## Test status

CI checks are defined in `.github/workflows/ci.yml`.
The last merged release passed its configured CI checks.
Run the local commands above before proposing another release.

## License

Stonehue uses the MIT license.
See [LICENSE](LICENSE).