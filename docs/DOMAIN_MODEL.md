# HIT domain model

This document defines the shared language of the Composition Mapper. Detailed specifications may refine the model, but they should preserve these distinctions unless the product understanding genuinely changes.

## Idea

A recognisable musical identity supplied by the musician.

Examples:

- Riff A;
- Section B;
- Drone C;
- Texture D;
- Lead Motif E;
- Werk groove F.

An Idea may be a single recorded item. It may later gain additional phrase components or realised layers, but these are not required at creation time.

## Phrase component

A semantic use of one recorded source item within an Idea. In the current model each Phrase Component is a Variant in a Phrase Family. A later victory may allow an Item Bundle to fulfil one component.

## Phrase family

A structural role within an Idea.

Victory 2 families:

- Pickup;
- Main;
- Turnaround;
- Ending;

Every Idea begins with a Main family. Pickup, Turnaround and Ending are optional. Transition belongs to later multi-Idea composition; Sustain, Texture and Counterline belong to later layering work.

A Phrase Family supplies default Phrase Grammar to its Variants:

- whether it may begin;
- whether it may repeat;
- whether it may end;
- which Phrase Families may follow;
- whether it may overlap its successor.

Absent optional families do not invalidate allowed-next rules or make an Idea incomplete.

## Variant

One recorded Phrase Component belonging to one Phrase Family.

A Variant has:

- stable Component identity;
- one Source Reference;
- a stable generated label such as A or B, with no ordering meaning;
- an optional musician-given name;
- optional Variant Intensity from 1 to 5, where unset remains distinct from 3;
- inherited family grammar or one complete grammar override;
- optional status as the family's Default Variant.

Every non-empty Phrase Family has exactly one Default Variant. One source item may realise Variants in several families of one Idea, but may appear only once within a family.

An unsplit Idea begins as Main A. Main does not imply loopability, so a complete through-composed section remains valid without a special type.

Variant Intensity describes the relative character of one recording. It does not choose phrases or define a passage-level Energy journey in Victory 3.

## Source reference

A stable project-local link from a Variant to one exact REAPER media item.

Source item GUID is identity. Live track, item and take names are descriptive. Source Media remains authoritative; musician-directed editing may change Source Item Topology through native undo, while compilers never modify source items.

## Item bundle

One musical component represented by related REAPER items across several source tracks.

The compiler must preserve timing, offsets and relationships across the bundle.

Item Bundles are not required for Victory 2. Adding several selected items creates several independent Variants rather than one bundle.

## Occurrence

One appearance of an Idea in a Composition.

Occurrences share the Idea's identity but may differ in duration, phrase sequence, context, overlap, target intention and variation level.

Victory 3 uses one Composition containing one Occurrence. Passage is player-facing language for this longer result, not another domain entity.

## Source palette

The Variants whose Source References resolve to exact REAPER items when a Suggestion is generated.

Every member is eligible, but none is required. An item with offline media remains in the Source Palette. A Gone Source, whose item no longer exists, does not.

## Target duration

A loose whole-bar preference for the entire audible Phrase Sequence. It guides exploration without permitting the compiler to trim or stretch Source Media.

## Phrase sequence

An ordered, grammar-valid choice and placement of Variants for one Occurrence.

The sequence records Variant identity, timing and optional overlap. It is explicit Suggestion data rather than an inference from generated media.

## Evolution

How an Idea changes across repeated occurrences.

Evolution may establish the Idea, preserve hypnotic repetition, introduce alternatives, withdraw material, suggest a new layer, reserve a climax treatment or allow the Idea to disappear and return later.

## Existing layer

Recorded source material that can be rendered now.

Examples:

- an existing guitar double;
- a recorded texture;
- a bass part;
- an available Werk MIDI pattern.

## Layer intention

Something the Composition may benefit from but which may not yet exist as source material.

Examples:

- restrained guitar double for width;
- upper-register texture for sparkle;
- counterline after the fourth return;
- bass movement to add momentum;
- transient percussion without extra low-mid density.

A Layer Intention has a status:

- Suggested — no source exists;
- Placeholder — represented visibly but not rendered as real material;
- Available — suitable source exists;
- Realised — the intended source has been recorded and linked.

The demo compiler must never confuse Suggested with Available.

## Intention

The desired listener experience over a span of the Composition.

Core dimensions include:

### Dynamics

- Energy
- Tension
- Release
- Momentum
- Restraint
- Impact

### Spectrum

- Weight
- Warmth
- Presence
- Air
- Sparkle
- Darkness

### Space

- Width
- Depth
- Intimacy
- Focus
- Distance
- Openness

### Texture

- Smooth
- Grainy
- Noisy
- Metallic
- Organic
- Mechanical
- Dense
- Sparse

### Motion

- Static
- Flowing
- Pulsing
- Driving
- Chaotic
- Suspended

### Structure

- Repetition
- Evolution
- Contrast
- Surprise
- Stability
- Novelty

Intentions are directional and perceptual, not mixer parameters.

## Composition

The source-of-truth model containing:

- available Ideas;
- phrase definitions;
- target duration;
- structural preferences;
- occurrences;
- overlaps;
- evolution rules;
- intention maps;
- layer intentions;
- constraints;
- suggestion and build history.

## Suggestion

A proposed Composition or revision generated from the available source material, intention and constraints.

A Suggestion must be explainable. It should state the important structural decisions and why they were proposed.

Victory 3 Suggestions also record their deterministic seed, compiler version, Source Palette and explicit Phrase Sequence. Intensity does not influence their generation.

## Build

A reproducible materialisation of a Composition into the REAPER timeline.

A Build has an identity and should be traceable to:

- Composition version;
- source items;
- compiler version;
- deterministic seed;
- generated items;
- analysis results.

Victory 3 keeps each Build in one muteable folder containing two alternating phrase lanes. A newer Build mutes older managed Builds without deleting them.

Generated media remains ordinary REAPER material. Musician edits are canonical within that Build and are not repaired or synchronised back into the Composition. A later Develop This workflow may scan the edited Build into a new Composition revision.

## Demo compiler

The engine that turns the Composition into disposable REAPER media.

It resolves valid phrase sequences, existing layers, overlaps, pickups, alternatives, turnarounds, Werk material and placeholders for unrealised suggestions.

## Composition analysis

Evidence about how the generated result behaves.

Internal analysis may consider evolution, contrast, pacing, density, spectral journey and novelty. External adapters such as Airwindows Meter provide additional observations.

Analysis informs the composer. It does not overrule them.

## Locked composition

A Composition the musician has declared correct enough to leave exploration and enter production planning.

Locking is a deliberate campaign transition, not merely a technical flag.

## Production map

A later sister-project model derived from a Locked Composition. It describes what needs to be recorded and completed to realise the final work.

## Afterimage arrangement

A later visual interpretation of the composition and production intention, resulting in a rendered or live visual work.
