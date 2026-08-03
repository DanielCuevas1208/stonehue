# Stonehue

Stonehue is a Go engine for small boards. It applies the capture rules
and simple area scoring. It chooses moves with Monte Carlo tree search.
It answers the Go Text Protocol (GTP).

Standard Go tools can play against Stonehue. This includes Sabaki and
GoGui. The engine runs on a board from 3 by 3 to 19 by 19.

Stonehue is written in Common Lisp. It runs on SBCL with ASDF.

## Features

- Capture rules with the simple ko rule
- Simple Chinese area scoring with komi
- Monte Carlo tree search with UCT
- Five strength levels from 1 to 5
- Time controls for real games
- Opening pattern hints for the first moves
- Handicap points and handicap commands
- Deterministic search with a fixed random seed
- A GTP server for standard Go tools

## Quick start

Install SBCL. Then run this command from the project root:

```
sbcl --load bin/stonehue.lisp
```

The engine starts a GTP session. Send a GTP command on each line.
Send `quit` to stop the session.

The test suite uses FiveAM. Install FiveAM in one of two ways:

- Install Quicklisp. Quicklisp installs FiveAM automatically.
- On Debian or Ubuntu, run `apt-get install cl-fiveam`.

Then run this command:

```
sbcl --load scripts/run-tests.lisp
```

## Play a game

Send this session to the engine:

```
boardsize 9
clear_board
komi 6.5
play b D4
play w F4
play b D6
genmove w
```

The engine replies `= E4` or a similar vertex. It applies the move
to the board. Use `showboard` to see the position.

See `examples/sample-session.txt` for a full transcript.

## Engine controls

The strength level sets the search budget.

| Command | Effect |
| --- | --- |
| `stonehue_strength N` | Sets the strength level from 1 to 5 |
| `stonehue_seed N` | Sets the random seed |
| `stonehue_opening` | Lists the opening hints |
| `stonehue_analyze` | Lists the search results for the last move |
| `time_settings M B S` | Sets main time, byo-yomi, and stones |
| `kgs-time_settings M B S P` | KGS form with the periods value ignored |

The engine commands start with `stonehue_`. They extend the standard
protocol. The strength levels map to playout counts:

| Level | Playouts |
| --- | --- |
| 1 | 120 |
| 2 | 400 |
| 3 | 1000 |
| 4 | 3000 |
| 5 | 9000 |

With `time_settings`, the engine uses a wall-clock budget per move.
The budget replaces the playout count.

## How it works

The engine has ten modules.

| Module | Purpose |
| --- | --- |
| `board` | Board data and GTP coordinates |
| `rules` | Position state, captures, ko, legal moves |
| `scoring` | Area scoring and final score strings |
| `mcts` | Monte Carlo tree search |
| `opening` | Opening pattern hints and handicap points |
| `engine` | Engine state, strength, time controls |
| `gtp` | The GTP server |
| `random` | A deterministic random generator |
| `render` | ASCII board display |
| `packages` | Package and version |

The `rules` module owns the game state. Each position holds the board
and a small history. The history covers captures and the ko rule.

The `mcts` module searches the game tree. Each playout plays a short
random game. A short game keeps the result close to the material
balance. Captures then show clearly in the search.

The `opening` module biases the first moves. It rates the standard
corner points. It also rates the center and the edges.

The `engine` module ties the parts together. It tracks the position,
the komi, and the search budget.

The `gtp` module reads commands and writes replies. Each command is a
function in a dispatch table. An unknown command gets an error reply.

## Build a standalone engine

Run this command:

```
sbcl --load scripts/build.lisp
```

The command writes `build/stonehue.exe`. The file is a standalone
engine. It needs no Lisp image at runtime.

## Run the tests

Run this command:

```
sbcl --load scripts/run-tests.lisp
```

The suite covers the rules, the scoring, the search, and the protocol.
It also replays the GTP fixtures in `examples/fixtures`.

Check for clean compilation with this command:

```
sbcl --load scripts/check-clean.lisp
```

## Sample data

The examples folder holds sample data.

- `examples/sample-session.txt` is a real GTP transcript.
- `examples/sample-game.txt` is a full self-play game record.
- `examples/fixtures` holds GTP command files for the tests.

The self-play record is sample data. It is not a claim about strength.

## Compatibility

Stonehue follows the GTP version 2 specification. It implements the
standard commands. It adds the handicap commands and the KGS time
settings command. It adds `gogui-analyze_commands` for GoGui.

Tested with these versions:

- SBCL 2.2.9 and 2.6.7
- FiveAM 1.4 (Quicklisp dist 2024-10-12)
- ASDF 3.3 (bundled with SBCL)

## Limitations

The engine is a first release. Play strength is low. The search uses
random playouts with a small budget.

- The search values material only. Komi does not change the search.
- Scoring does not remove dead stones.
- There is no opening book beyond the pattern hints.
- There is no SGF support.
- There is no pondering or parallel search.

The GTP interface accepts boards from 3 by 3 to 19 by 19. The engine
core supports boards up to 25 by 25.

## Roadmap

- Release 0.2 adds SGF import and export.
- Release 0.3 adds a transposition table and pondering.
- Release 0.4 adds pattern playouts for stronger play.

See `ROADMAP.md` for the full plan.

## License

Stonehue is released under the MIT license. See `LICENSE`.
