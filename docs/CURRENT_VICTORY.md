# Current victory

## Victory 1 — One idea can enter HIT

The campaign foundation is now present. The next detailed specification should focus on the smallest genuine musical capability: recognising one real REAPER item as a persistent HIT Idea.

## Player outcome

A musician records or selects one item in REAPER, names it as an Idea, closes and reopens the project, and HIT still recognises it correctly.

The Idea may be one complete item. The user must not be forced to define phrase components, layers, intention curves or an arrangement before the Idea can exist.

## Victory condition

- HIT can open as a ReaImGui editor in REAPER.
- A project can be initialised safely.
- One selected audio or MIDI item can become an Idea.
- The Idea receives a stable identity and human-readable name.
- Source media is not moved, trimmed or rewritten.
- The Idea survives project save and reload.
- HIT can show the Idea and resolve it back to the correct source item.
- Missing or moved source material produces a visible error rather than silent reassignment.
- The user action participates coherently in REAPER undo where applicable.

## Evidence of victory

A short manual demonstration proves:

1. record or create one source item;
2. open HIT;
3. create `Idea A` from the selected item;
4. save and close the REAPER project;
5. reopen it;
6. open HIT;
7. confirm `Idea A` still refers to the correct source.

## Scope boundary

This victory does not yet require:

- splitting or tagging phrase components;
- a dedicated composition canvas;
- arrangement suggestions;
- demo compilation;
- intention mapping;
- Werk integration;
- Airwindows Meter integration;
- Production Mapper;
- Afterimage integration.

However, the implementation should respect the domain and architecture documents so this simple Idea can later participate in those victories.

## Specification task

Use the installed product/specification skills to drill this victory into:

- user flows;
- requirements;
- technical investigation;
- architecture choices required now;
- acceptance tests;
- an achievable implementation plan.

Do not turn the entire campaign into an implementation backlog. Plan only enough foundational work to achieve this victory cleanly and leave an obvious path to Victory 2.