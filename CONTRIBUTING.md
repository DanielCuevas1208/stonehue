# Contributing

Read `README.md` before changing the engine.
Keep public APIs stable unless tests require a correction.

## Checks

Install SBCL and FiveAM.
Run clean compilation.
Run the FiveAM suite.
Run the standalone build.

```text
sbcl --load scripts/check-clean.lisp
sbcl --load scripts/run-tests.lisp
sbcl --load scripts/build.lisp
```

Keep generated files out of commits.
The repository ignores Lisp fasls and build output.

## Changes

Add deterministic tests for core behavior.
Update the README when commands or behavior change.
Update `ROADMAP.md` when roadmap work changes.
Keep examples runnable through GTP.

Use active voice in public documentation.
Keep instructions short.
Describe limitations without performance claims.