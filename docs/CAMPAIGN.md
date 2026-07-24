# HIT campaign

## Mission

Build a creative suite that helps transform human musical ideas into compelling compositions, realised productions and intentional visual works.

The campaign begins with Composition Mapper and ends with a finished musical and visual piece published to YouTube.

## Campaign rule

A victory is a creative outcome, not merely completed infrastructure.

A victory is not:

- implemented item tagging;
- created a compiler abstraction;
- added an analysis adapter.

A victory is:

- one recorded idea became a convincing evolving passage;
- four sections became several arrangements worth hearing;
- two arrangements could be compared through listening and Meter evidence;
- the finished composition became an Afterimage video.

Detailed specifications, missions and implementation plans should be derived for the current victory using the project skills. This document defines the direction and victory conditions, not a premature ticket backlog.

---

# Composition campaign

## Victory 0 — Establish the campaign

### Player outcome

The repository clearly explains what HIT is, what it is not, where it is going and what must be achieved next.

### Victory condition

A fresh Codex session can read the repository and accurately explain:

- the product philosophy;
- the domain language;
- the architectural boundaries;
- the current victory;
- the path to the final creative outcome.

---

## Victory 1 — One idea can enter HIT

### Player outcome

A musician records or selects one real REAPER item and recognises it inside HIT as a reusable Idea.

The Idea may be one complete thing. No additional layers or phrase components are required.

### Victory condition

A source item can be identified, named, persisted and reopened without altering the recording.

### Evidence of victory

Close and reopen the project. HIT still recognises the Idea and displays its source accurately.

---

## Victory 2 — One performance reveals its grammar

### Player outcome

A musician can split a longer performance and describe its meaningful parts, such as:

- Pickup;
- Main;
- Alternative A;
- Alternative B;
- Turnaround.

A complete through-composed section remains valid without splitting.

### Victory condition

HIT understands which material can repeat, begin, end or overlap without treating every item as an interchangeable loop.

### Evidence of victory

The UI shows the Idea's phrase grammar and identifies invalid or incomplete combinations without damaging source items.

---

## Victory 3 — One idea becomes an evolving passage

### Player outcome

A musician requests a longer passage from one Idea and hears a convincing result without manually duplicating every item.

### Victory condition

A recorded Idea can become a longer deterministic sequence that respects its pickups, loopable centre, alternatives, turnarounds and tails.

### Evidence of victory

A source such as Pickup + Main + Alternatives + Turnaround becomes a 48-bar generated demo whose phrase sequence is visible and explainable.

---

## Victory 4 — Four ideas become compelling arrangements

### Player outcome

A musician with four recorded sections receives several materially different composition suggestions.

### Victory condition

At least three proposals differ meaningfully in form, pacing, recurrence, contrast, overlap and climax placement—not merely in shuffled order.

The musician considers more than one proposal worth auditioning.

### Evidence of victory

Each proposal includes:

- expected duration;
- structural summary;
- energy journey;
- important returns and absences;
- overlaps;
- an explanation of why it may work.

A selected proposal builds into a playable REAPER demo.

---

## Victory 5 — The musician directs instead of block-editing

### Player outcome

The musician refines a proposed composition using high-level direction such as:

- slower build;
- more of A;
- less of B;
- make the middle breathe;
- delay the climax;
- more hypnotic;
- more overlap;
- stronger ending.

### Victory condition

HIT revises the Composition while retaining unaffected decisions where sensible and explains what changed.

### Evidence of victory

The musician reaches a preferred structure without manually positioning every occurrence.

---

## Victory 6 — Repetition develops with intention

### Player outcome

A long passage remains recognisable and compelling because returns evolve rather than merely duplicate.

### Victory condition

HIT can vary phrase choice, duration, overlap, absence and return across occurrences.

When additional musical material would help but does not exist, HIT creates a clear Layer Intention rather than fictional audio.

### Evidence of victory

A repeated Idea develops across several minutes, while the UI distinguishes:

- material rendered now;
- suggestions not yet recorded;
- optional placeholders;
- realised suggestions.

---

## Victory 7 — Intention shapes sonic space

### Player outcome

The musician can shape listener experience using terms such as:

- energy;
- weight;
- punch;
- air;
- sparkle;
- width;
- intimacy;
- density;
- motion;
- novelty;
- contrast.

### Victory condition

HIT makes structural and layer suggestions that move towards those intentions without assuming that more energy means more simultaneous material.

### Evidence of victory

A request such as "more energy, less density, preserve intimacy, introduce sparkle later" produces an explainable revision and a set of any missing recording suggestions.

---

## Victory 8 — HIT can critique the composition musically

### Player outcome

The musician receives useful observations before production, expressed in compositional language.

### Victory condition

Internal analysis can identify plausible issues such as:

- repetition fatigue;
- weak structural contrast;
- density or width plateaus;
- early spectral saturation;
- an unearned climax;
- a final third with little novelty.

### Evidence of victory

The user can accept or reject suggested remedies and compare the resulting builds by listening.

---

## Victory 9 — Meter closes the evidence loop

### Player outcome

The musician can compare arrangements using Airwindows Meter evidence without needing to obsess over technical engineering details.

### Victory condition

HIT can associate actual Meter results with a generated Build and translate them cautiously into composition-level observations.

Meter remains an external validator, not an artistic authority.

### Evidence of victory

Two arrangements of the same source material can be compared by:

- listening;
- internal analysis;
- Meter dimensions and grades;
- an explanation of which compositional differences may have influenced the result.

---

## Victory 10 — The composition is worth finishing

### Player outcome

The musician chooses one arrangement and can honestly say: "This is the piece."

### Victory condition

The selected Composition is versioned, reproducible, analysed and deliberately locked for production.

### Evidence of victory

The complete demo can be rebuilt from its model and sources. Its unresolved Layer Intentions are explicit rather than hidden in notes or memory.

---

# Production campaign

Production Mapper is a later sister project. These victories describe the destination without expanding the current implementation scope.

## Victory 11 — The locked composition becomes a production map

### Player outcome

The musician knows what must be recorded to realise the chosen composition.

### Victory condition

The locked Composition produces a production plan containing required performances, optional layers, recording spans and completion state.

---

## Victory 12 — Each recording session has a clear purpose

### Player outcome

The musician opens REAPER and immediately knows the next useful performances to capture.

### Victory condition

The Production Map can create and track practical recording work without changing the locked compositional intent accidentally.

---

## Victory 13 — A finished audio master exists

### Player outcome

The piece is fully recorded, edited, mixed and mastered.

### Victory condition

A final stereo master exists and the production map shows that the intended composition has been realised or that deviations were made deliberately.

---

# Afterimage campaign

## Victory 14 — The composition becomes visual intention

### Player outcome

Afterimage can import the structure, energy, contrast, motion and other relevant intentions of the finished piece.

### Victory condition

The visual system understands the composition's major passages and journey without relying only on reactive audio analysis.

---

## Victory 15 — Afterimage creates a deliberate visual arrangement

### Player outcome

Scenes, fields, masks, overlays, motion and transitions develop with the same intentional arc as the music.

### Victory condition

The visual arrangement feels authored and structurally connected to the composition, not like a generic visualiser.

---

# Final victory — Publish the finished work

### Player outcome

The full creative cycle is complete:

```text
Musical ideas
    ↓
Compelling composition
    ↓
Finished production
    ↓
Intentional Afterimage arrangement
    ↓
Finished YouTube video
```

### Victory condition

A complete Theory of Mine work is rendered and published, with the original creative intention recognisable across music, production and image.

---

# Campaign north stars

- Four ideas become a piece worth finishing.
- The musician creates the vocabulary; HIT helps form the language.
- The user directs; the system proposes.
- The map is the source of truth; generated media is disposable.
- Missing layers are suggestions, not imaginary assets.
- Long-form development is first-class.
- Interesting over loud.
- Meter informs listening; it does not replace it.
- The destination is a finished artistic work, not a software demonstration.