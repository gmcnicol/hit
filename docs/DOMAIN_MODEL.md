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

A recorded item or item bundle that performs a role within an Idea.

Initial roles:

- Pickup;
- Main;
- Alternative;
- Turnaround;
- Ending;
- Transition;
- Sustain;
- Texture;
- Counterline.

A component may describe:

- loopability;
- whether it can start or end a passage;
- whether it can overlap the next phrase;
- preferred predecessors or successors;
- minimum repeats before use;
- maximum uses;
- intrinsic energy;
- sonic characteristics.

Not every Idea needs multiple components. A complete 16-bar through-composed section is valid as one component.

## Item bundle

One musical component represented by related REAPER items across several source tracks.

The compiler must preserve timing, offsets and relationships across the bundle.

## Occurrence

One appearance of an Idea in a Composition.

Occurrences share the Idea's identity but may differ in duration, phrase sequence, context, overlap, target intention and variation level.

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

## Build

A reproducible materialisation of a Composition into the REAPER timeline.

A Build has an identity and should be traceable to:

- Composition version;
- source items;
- compiler version;
- deterministic seed;
- generated items;
- analysis results.

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