# Contributing

HIT targets REAPER's embedded Lua 5.4 runtime. Keep modules as plain tables,
expected failures as `nil, "error_code"`, and direct `reaper` access inside the
bootstrap or concrete modules under `src/hit/reaper/`.

Run the fast development gate before committing:

```sh
scripts/check
```

This checks Lua syntax, StyLua formatting, Luacheck diagnostics and all pure or
in-memory tests. Run the disposable real-REAPER proof separately when changing
adapter wiring or native undo behaviour:

```sh
tests/run_reaper_idea_probe.sh
```

The live proof creates only the documented `/tmp` project and evidence files.
