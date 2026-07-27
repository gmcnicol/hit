# Current victory

## Victory 3: One Idea becomes an evolving passage

Victory 2 established a musician-authored Phrase Grammar for one Idea. Victory 3 uses that grammar to publish several playable, deterministic arrangements without making the musician duplicate every source item by hand.

## Player outcome

From one Classified Idea, the musician enters a loose bar target and seed, presses Generate, and immediately hears a longer passage. Pickup, Main, Turnaround and Ending Variants retain their musical roles. The Phrase Sequence is visible, compactly explained and safe to edit as ordinary REAPER material.

Generating another Build keeps earlier work, mutes it and publishes the new Build for audition. The musician may freely alter any generated arrangement. HIT does not repair or overwrite those edits.

## Victory condition

- Generate turns one Classified Idea into one Composition containing one Occurrence.
- Target Duration defaults to 48 bars, accepts any positive whole-bar value and guides rather than constrains the result.
- Target Duration covers the full audible span from Pickup start through Ending tail, accounting for overlaps.
- The first Build starts exactly at the REAPER edit cursor. Later Builds for that Composition share the stored anchor.
- The current Source Palette contains every Variant whose Source Reference resolves to one project item. Offline media remains eligible; a Gone or ambiguous source does not.
- Every member of the Source Palette is eligible, but none is required.
- Phrase Grammar remains musician authority. HIT does not repair strange or restrictive rules.
- Generation prefers populated Pickup, Turnaround and Ending families where rules and Target Duration permit.
- Default Variants anchor the sequence without excluding alternatives. Default choice receives twice the selection weight of another eligible Variant.
- Main returns use the available Default Main after Pickup and Turnaround where grammar permits. A Gone default falls back to another available Variant.
- `may_repeat` permits the same Variant immediately after itself. An allowed transition to the same family permits a different Variant.
- Turnaround placement considers elapsed duration, not phrase count. Long Variants remain intact.
- Variant Intensity does not influence Victory 3 generation.
- Permitted overlaps are optional seeded choices. Each overlap is the smaller of one project bar or one quarter of the shorter phrase.
- Complete source items are placed without trimming, stretching or invented fades. Existing item fades and audible properties are preserved.
- The achieved duration may be shorter or longer than Target Duration. Requested and achieved lengths remain visible.
- Seed defaults to `1`, remains editable and increments for Try Another.
- Identical Idea state, Phrase Grammar, Source Palette, Target Duration, anchor, seed and compiler version produce the same Phrase Sequence.
- Generate has no preview or approval step. It publishes one playable Build immediately.
- Every Build has a stable identity and lives in its own muteable folder under a stable `GENERATED DEMO` root.
- A Build contains exactly two neutral child tracks, Lane A and Lane B. Normal phrase changes alternate lanes and overlaps occupy both.
- Generated items use strong Phrase Family colours and visible Variant labels or musician names. Meaning never depends on colour alone.
- The Build folder snapshots the available Default Main source track's FX chain, volume, pan and width. A fallback Main supplies processing when its recorded default is Gone; if no Main remains, the first generated phrase supplies it. The snapshot excludes recording state, automation, routing, hardware outputs, folder state and media items.
- Generating a Build mutes surviving older Build folders still inside the generated root and leaves the new Build audible. The root folder's manual mute state is not changed.
- Moving a Build outside the generated root detaches it from automatic muting.
- Generated audio items independently reference their media. Generated MIDI is an independent, unpooled copy.
- Generated copies begin unmuted, unlocked, ungrouped and unselected. Musical item and take properties remain intact.
- Each generated item carries stable Build, Component, Phrase Family and Source Reference identity for provenance and later scanning.
- Existing Builds remain unchanged when sources, grammar or processing later change.
- Manual moves, trims, duplications, deletions, renames and mute changes are canonical within that Build. HIT neither warns nor repairs them.
- One Generate action, including old-Build mute changes, metadata and new tracks and items, is one native REAPER undo action.
- Failure removes partial output, restores prior mute states and metadata, and leaves Source Media untouched.
- Save and reopen preserve Composition, Suggestion, Phrase Sequence, seed, Build and generated ownership identities.

## Generator policy

The pure generator receives:

- one Classified Idea and its effective family or Variant grammar;
- the current Source Palette and source durations;
- a project-time anchor and adapter-supplied measure boundaries, preserving the anchor's within-measure beat across the requested number of project measures;
- positive whole-bar Target Duration;
- deterministic seed and compiler version.

It produces one Suggestion containing an explicit Phrase Sequence:

1. choose a legal beginning, preferring an available Pickup and then Main;
2. use the available Default Main as the first Main after Pickup and Turnaround where legal;
3. choose other eligible Variants deterministically, weighting defaults twice;
4. never repeat the same Variant unless its effective rules permit it;
5. consider Turnaround only at legal boundaries, with preference rising when none has appeared and the sequence approaches its target;
6. prefer a legal Ending near the target, otherwise finish on a Variant whose effective rules permit ending;
7. place complete phrases and choose the grammar-valid result closest to Target Duration;
8. use at most two simultaneous phrases, which the capped overlap rule guarantees;
9. stop early when grammar offers no legal continuation and the current Variant may end;
10. return `no_legal_start` only when no present Variant may begin.

Custom grammar may produce short or unusual passages. This is valid musician-authored behaviour, not an error.

## User flow

1. Musician opens an Idea and chooses Generate.
2. Generate view shows Target Bars `48`, Seed `1`, source summary and one Generate action.
3. Musician places REAPER edit cursor and presses Generate.
4. HIT creates Composition, Suggestion and Build together in one undo action.
5. REAPER timeline shows the two-lane Build at the cursor with coloured and labelled phrase items.
6. Generate view shows compact Phrase Sequence, requested and achieved bars, overlaps, structural choices and seed.
7. Musician changes seed or uses Try Another.
8. HIT creates another Build at the same anchor, mutes earlier managed Builds and leaves the new one audible.
9. Musician compares folders using normal REAPER mute and transport, then edits any promising Build directly.

## UI boundary

Generate is a new view opened from one Idea. It is not a composition canvas and does not replace REAPER transport.

The view contains only:

- Idea identity;
- Target Bars;
- editable Seed;
- Generate or Try Another;
- compact generated sequence and explanation;
- surviving Build list.

Window identity remains stable when its visible title changes. Immediate-mode content determines panel and window height. Phrase colour is reinforced by Family text and Variant label.

## Persistence and ownership

Victory 1 and Victory 2 records remain unchanged in `P_EXT:HIT_STATE_V1` and `P_EXT:HIT_STATE_V2`.

Victory 3 adds `P_EXT:HIT_STATE_V3`. It stores Composition, Occurrence, Suggestion, explicit Phrase Sequence, target, anchor, seed, compiler version and Build provenance. Generated root, Build folders, lanes and items also carry role-specific `P_EXT` ownership metadata. Human-readable names are never identity.

Invalid or newer V3 state is read-only. Existing generated media is never deleted merely because V3 state cannot be read.

A future Develop This action will scan the selected Build's current REAPER items and create a new Composition revision. Victory 3 records the provenance needed for that scan but does not add selection, live synchronisation or Develop This behaviour.

## Technical investigation before implementation

Prove these operations in a disposable REAPER project before relying on them:

1. clone an audio item with new item and take identity while preserving audible item and take state;
2. clone MIDI with independent event storage so editing generated notes cannot change source notes;
3. copy only track FX plus volume, pan and width into a Build folder;
4. create and recognise the nested generated-root, Build-folder and two-lane structure using stable metadata;
5. convert a cursor-relative whole-measure target through tempo and time-signature changes without snapping the anchor;
6. roll back created tracks, items, V3 metadata and prior mute changes inside one failed native undo transaction.

The [official ReaScript API](https://www.reaper.fm/sdk/reascript/reascripthelp.html) supplies item and track state access, FX copying, folder depth, persistent `P_EXT` metadata and project time-map conversion. Chunk manipulation must be kept behind the REAPER adapter and covered by a live proof because chunk structure is not the domain contract.

## Automated acceptance

Pure Lua tests prove:

- same inputs and seed produce identical Phrase Sequence;
- another seed can produce another valid Phrase Sequence;
- every transition, repeat, beginning, ending and overlap obeys effective grammar;
- defaults receive the agreed preference without excluding alternatives;
- Source Palette membership depends on item presence, not offline media;
- Gone and ambiguous sources are excluded;
- long and irregular Variants remain intact;
- target selection chooses a close legal duration without requiring equality;
- Target Duration includes Pickup, Ending and overlap placement;
- Turnaround choice is duration-aware rather than phrase-count based;
- Intensity never changes Victory 3 selection;
- no legal beginning returns `no_legal_start`;
- restrictive grammar may return a short valid result.

In-memory REAPER adapter tests prove:

- V1 and V2 metadata remain byte-for-byte unchanged;
- valid V3 round-trips exact identities and explicit sequence data;
- generated ownership uses metadata rather than names;
- two lanes alternate and contain overlaps without a third concurrent item;
- generated copies normalise mute, lock, group and selection state;
- MIDI copies are independent;
- only agreed track processing is copied;
- generating mutes only managed Build folders still inside the generated root;
- manual root mute, moved Builds and unrelated material remain untouched;
- transaction failure restores prior metadata and mute states and removes partial output;
- undo and redo treat generation as one operation.

## Evidence of victory

One real Classified Idea contains mixed phrase lengths, including one long Variant. In a disposable REAPER project:

1. place edit cursor and generate near 48 bars;
2. hear one coherent passage built from intact source material;
3. see obvious Family colours, Variant labels, two-lane switching and at least one permitted overlap;
4. understand the compact structural explanation and achieved duration;
5. generate another seed and confirm the earlier Build remains but mutes;
6. manually alter the earlier Build and confirm another generation does not repair it;
7. save, close and reopen, then confirm Builds and provenance return.

## Implementation plan

### Slice 1: prove the REAPER edge

- Add one disposable live proof for independent audio and MIDI copies, selective track processing, folder ownership and cursor-relative measure conversion.
- Record only APIs and chunk transformations demonstrated by the proof.
- Extend the in-memory REAPER fake only with calls required by that proof.

Outcome: one source phrase becomes one safe generated item on either lane without changing Source Media.

### Slice 2: generate one deterministic Phrase Sequence

- Add a pure passage generator over plain Lua data.
- Resolve effective Variant rules from existing Victory 2 grammar.
- Add deterministic seeded choice, target-span calculation, default anchors, duration-aware Turnarounds, legal endings and capped overlaps.
- Cover generator invariants with focused pure Lua tests.

Outcome: one Classified Idea produces one visible, explainable plan independent of REAPER.

### Slice 3: publish one atomic Build

- Add V3 model and codec beside unchanged V1/V2 records.
- Add a generation application service with a narrow project port.
- Materialise generated root, Build folder, processing snapshot, lanes and tagged items in one undo transaction.
- Restore metadata and REAPER state on every failed path.

Outcome: pressing one application command creates one playable Build at the edit cursor.

### Slice 4: retain and compare Builds

- Discover managed Builds by stable metadata and containment.
- Mute older contained Builds, preserve manual root mute and ignore detached Builds.
- Keep explicit Suggestion and Build provenance across reopen.
- Prove repeated seed and changed seed behaviour.

Outcome: musician can keep several generated passages and compare them using normal REAPER controls.

### Slice 5: expose Generate

- Add Generate navigation from an Idea.
- Add Target Bars, editable Seed, Generate or Try Another, sequence summary and Build list.
- Apply Family colours and Variant labels to generated items.
- Preserve stable ReaImGui window identity and content-driven height.

Outcome: full one-click musical workflow satisfies manual Evidence of Victory.

### Slice 6: prove and document the victory

- Run repository checks and disposable live proof.
- Perform the short musical manual acceptance above.
- Capture only defects needed for Victory 3; do not create backlog for later dynamics, transitions or motifs.

Outcome: one Idea becomes a passage worth editing.

## Scope boundary

Victory 3 does not include:

- several Ideas in one Composition;
- transition building between Ideas;
- an energy or dynamics curve;
- Variant Intensity-based selection;
- layer intentions, influences or motif development;
- persistent selected-Build state;
- Develop This scanning;
- a dedicated composition canvas;
- minute or second targets;
- track per Variant or source track;
- custom transport or audition controls;
- automatic repair, cleanup or import of manual Build edits;
- Item Bundles, Werk, Airwindows Meter, Production Mapper or Afterimage.
