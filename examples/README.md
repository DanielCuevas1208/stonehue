# Examples and fixtures

This folder contains sample data for Stonehue.

## Sample session

`sample-session.txt` is a real GTP transcript. It shows every reply
from a short game on a 9 by 9 board. Read it to learn the protocol.

## SGF session

`sample-sgf-session.txt` shows the save and load commands. The engine
prints a game record and loads it back. Read it to learn `printsgf`
and `loadsgf`.

## Sample game

`sample-game.txt` is a full self-play game record. Two Stonehue
instances played the game. The record lists the moves, the final
board, and the result.

`sample-game.sgf` is the same kind of game in the Smart Game Format.
A fixed random seed created it. Run this command to make a new record:

```
sbcl --load scripts/save-game.lisp examples/sample-game.sgf
```

## Fixtures

The fixtures folder holds GTP command files. The test suite replays
each file and checks the replies. A fixture is also a small demo.

- `basic-session.gtp` replays a short game with every core command.
- `ko-game.gtp` shows the simple ko rule. Its last command must fail.
- `opening-13x13.gtp` uses opening hints and time controls.

Run any fixture against the engine:

```
sbcl --load bin/stonehue.lisp < examples/fixtures/basic-session.gtp
```

The `#` lines are comments. The engine ignores them.
