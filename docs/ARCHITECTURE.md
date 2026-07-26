# HIT architecture

This is the initial technical direction for the Composition Mapper. Detailed specifications should evolve it only when a concrete victory requires that change.

## Platform

- REAPER
- Lua ReaScript
- ReaImGui
- ReaPack distribution
- no C++ initially

C++ may later be justified for native audio analysis or performance-sensitive services. It is not required to prove the composition workflow.

## System shape

```text
ReaImGui Composition View
        ↓
Application services
        ↓
Composition domain model
        ↓
Suggestion / compiler / analysis engines
        ↓
REAPER adapter
        ↓
Tracks, items, takes and project metadata
```

## Core boundary

The composition model, suggestion logic and compiler planning must not directly call REAPER APIs.

They should operate on plain Lua data so they can be tested deterministically outside REAPER.

REAPER-specific code translates between the domain model and the project.

## Project structure in REAPER

```text
01 COMPOSITION MAP
02 IDEA SOURCES
03 GENERATED DEMO
```

### Composition Map

Stores the visible map and canonical project metadata.

### Idea Sources

Contains the musician's real source audio and MIDI. Compiler operations must not modify these items.

### Generated Demo

Contains disposable output generated from a Composition Build.

## UI surface

The Composition Mapper is a dedicated ReaImGui editor surface inside REAPER, analogous in role to the MIDI editor or routing matrix.

It is not an Ableton-style Session View and not a live clip launcher.

The primary UI represents:

- Ideas;
- structural suggestions;
- intention;
- energy and sonic-space journeys;
- evolution;
- overlaps;
- unrealised Layer Intentions;
- analysis and explanation.

The ordinary REAPER arrange view remains the recording, editing, playback and mixing environment.

## Suggested module boundaries

```text
src/
├── HIT.lua
└── hit/
    ├── app/
    ├── model/
    ├── suggestions/
    ├── compiler/
    ├── analysis/
    ├── integrations/
    ├── reaper/
    └── ui/imgui/
```

### model

Pure domain types and invariants: Idea, Phrase Component, Occurrence, Evolution, Intention, Layer Intention, Composition and Build.

### suggestions

Produces and explains structural proposals or revisions from available material, user direction and constraints.

### compiler

Plans phrase sequences, overlaps, existing layers, placeholders and generated demo items.

### analysis

Internal composition heuristics and external adapters such as Airwindows Meter.

### integrations

Werk MIDI and future sister-project boundaries.

### reaper

All direct REAPER API access: project recognition, track and item operations, metadata and generated-build lifecycle.

### ui/imgui

The editor surface. ReaImGui should remain a presentation dependency rather than leaking into the domain model.

## Item awareness

The system must preserve and understand:

- source item position and length;
- take source offsets;
- tempo-aware duration;
- loopability;
- pickups and tails;
- fixed openings and endings;
- alternatives and turnarounds;
- overlapping phrase boundaries;
- multi-track item bundles.

It must not reduce source material to uniform four-bar clips.

## Metadata

Human-readable item names are useful but must not be canonical identifiers.

Stable project, Idea, component, occurrence, source and Build identities should be persisted using REAPER project/item extension metadata or another explicit project-local store chosen during implementation.

The detailed storage design belongs in the victory specification produced before implementation.

### Deployed project records

Victory 1 remains stored unchanged in `P_EXT:HIT_STATE_V1` on the project master track.

Victory 2 adds `P_EXT:HIT_STATE_V2` beside V1. Opening a V1-only Idea projects it in memory as Main A without writing. The first explicit Grammar mutation writes complete V2 state while preserving V1. Once valid V2 exists, it is authoritative for Grammar. Invalid or newer V2 state is read-only.

V2 persists Idea, Component and Source Reference identities, fixed Phrase Families, Variant labels, names, optional Intensity, defaults, family grammar, complete Variant overrides and dismissed recovery fingerprints. Track, item and take names, source kind, position, duration and availability remain live provenance.

## Victory 2 classification flow

```text
ReaImGui Phrases view
        ↓ musician command
Classification application service
        ↓ pure state transition
Phrase Grammar model
        ↓ validated V2 state
REAPER project port
        ↓ one native undo transaction
Master-track metadata and, for HIT Split only, source topology
```

The application service and Phrase Grammar model use plain Lua. Direct REAPER calls remain in the project port.

HIT Split is the only Victory 2 classification command that changes Source Item Topology. It splits the selected Variant source at REAPER's edit cursor, keeps the original Component and item GUID on the left, reacquires both items by GUID, writes V2 metadata in the same native undo block and restores the prior item chunk plus metadata if the transaction fails.

Ordinary REAPER splits remain musician-owned. The adapter compares project revisions and item topology, requiring adjacency, matching active-take source, compatible source offsets and the shortened known boundary before exposing a candidate. Recovery never attaches automatically.

## Non-destructive generation

Every generated item must carry a Build identity.

A rebuild must:

- remove only output owned by the relevant generated Build;
- leave Idea Sources untouched;
- leave unrelated user material untouched;
- be reversible as a coherent REAPER undo operation;
- fail visibly rather than silently corrupting the project.

## Determinism

The same Composition, source state, compiler version and seed should produce the same Build.

Randomness may explore alternatives, but it must be reproducible and explainable.

## Meter integration

Airwindows Meter is an analysis adapter, not the core model.

The likely early flow is:

```text
Composition
    ↓
Generated demo
    ↓
Render or analyse
    ↓
Meter results
    ↓
Composition-level interpretation
```

The exact integration mechanism must be investigated as part of its victory specification. HIT should not claim direct plugin data access until that path is proven.

## Suite boundary

The current repository owns Composition Mapper concerns through a Locked Composition.

Production Mapper and Afterimage remain later sister projects consuming exported composition intention and structure. Their future needs should inform stable concepts, but must not inflate the first implementation.
