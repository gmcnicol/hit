# HIT

**Human Intention Toolkit**

HIT is a structural composition environment for REAPER.

It helps a musician turn their own recorded riffs, sections, textures and motifs into compelling, evolving compositions without manually arranging every block on the timeline.

Record ideas once. Describe the journey. Explore arrangements. Build the demo. Refine by intention.

HIT is not an AI songwriter, clip launcher, random loop arranger, mastering assistant or DAW replacement. The musician creates the musical vocabulary. HIT helps shape that vocabulary into form.

## North star

> Four ideas become a piece worth finishing.

The broader campaign continues from composition into production planning and then into Afterimage, where the same creative intention drives the visual arrangement for a finished YouTube release.

## Current victory

**Victory 3: One Idea becomes an evolving passage**

Turn one Classified Idea into several deterministic, playable passages without manually duplicating every source item. Keep each generated Build editable, visible and explainable inside normal REAPER.

## Read first

- [Campaign](docs/CAMPAIGN.md)
- [Philosophy](docs/PHILOSOPHY.md)
- [Domain model](docs/DOMAIN_MODEL.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Current victory](docs/CURRENT_VICTORY.md)

## Platform direction

- REAPER
- Lua ReaScript
- ReaImGui
- ReaPack distribution
- non-destructive generated demos
- no C++ initially

## Suite destination

```text
Recorded ideas
    ↓
Composition Mapper
    ↓
Locked composition
    ↓
Production Mapper
    ↓
Finished audio
    ↓
Afterimage arrangement
    ↓
Finished YouTube video
```

The current repository is focused on the **Composition Mapper**. Production Mapper and Afterimage integration come later.

## Development checks

HIT targets REAPER's embedded Lua 5.4 runtime. The bootstrap composes UI and
concrete REAPER adapters. Adapters call application services and pure models;
direct host calls stay at the adapter edge. Modules return plain tables rather
than classes. Expected failures return `nil, "error_code"`; assertions are
reserved for programmer errors and invalid internal state. Only modules under
`src/hit/reaper/` and the bootstrap may access the host `reaper` global.

Run syntax validation, formatting verification, lint, pure Lua tests and
in-memory REAPER adapter tests:

```sh
scripts/check
```

Run the disposable two-phase live REAPER proof separately:

```sh
tests/run_reaper_idea_probe.sh
tests/run_reaper_generation_probe.sh
```

The live proofs create only `/tmp/hit-reaper-idea-probe.rpp`, `/tmp/hit-reaper-generation-probe.rpp`
and related `/tmp` evidence files. Never run their Lua scripts directly in a working project.

See [Victory 2 manual acceptance](docs/VICTORY_2_MANUAL_TEST.md) for the production Phrases workflow check.
See [Victory 3 manual acceptance](docs/VICTORY_3_MANUAL_TEST.md) for the production Generate workflow check.
