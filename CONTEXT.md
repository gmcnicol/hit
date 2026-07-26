# Composition Mapper

Language for describing a musician's recorded material and its structural grammar inside HIT.

## Language

**Source Media**:
The musician-supplied audio or MIDI content from which Ideas are formed. HIT treats it as authoritative and compilers never rewrite it.
_Avoid_: Generated media, clip content

**Source Item Topology**:
The musician-controlled REAPER item boundaries and relationships around Source Media. It may change only through explicit editing with native undo, including HIT Split.
_Avoid_: Source Media

**Source Reference**:
A stable project-local link from a Variant to one exact REAPER media item. Variants in different Phrase Families of one Idea may share a Source Reference, but a family contains that source at most once.
_Avoid_: Source name, track name

**Gone Source**:
A Source Reference whose REAPER item is no longer in the project. It remains attached to its Variant so native undo can restore it, but new Suggestions treat it as absent without explanation. An existing item with offline media is not Gone.
_Avoid_: Missing source

**HIT Split**:
A musician-directed division of an Idea's source item that preserves the Idea and creates another Variant in the same Phrase Family.
_Avoid_: ID flattening, automatic segmentation

**Component Candidate**:
A source item known to belong to an Idea but not yet assigned to a Phrase Family.
_Avoid_: Untagged clip, orphan

**Phrase Family**:
A structural role within an Idea, such as Pickup, Main or Turnaround. It contains variants and supplies their default grammar.
_Avoid_: Component role, alternative role

**Main**:
The default Phrase Family for an unsplit Idea. Main does not imply that its variants are loopable.
_Avoid_: Whole, through-composed type

**Pickup**:
A Phrase Family containing musical lead-ins to an Idea's Main family.
_Avoid_: Intro

**Turnaround**:
A Phrase Family containing phrases that close or redirect a cycle of an Idea.
_Avoid_: Alternative

**Ending**:
A Phrase Family containing deliberate concluding phrases for an Idea.
_Avoid_: Outro

**Phrase Grammar**:
The musician-authored structural rules governing whether a Phrase Family or Variant may begin, immediately repeat the same Variant, end, lead to another family or overlap its successor. An allowed transition to the same family permits a different Variant from that family; generation never repairs strange or restrictive grammar.
_Avoid_: Arrangement, energy profile

**Variant**:
One classified use of a Source Reference belonging to one Phrase Family. It has a stable Component identity, a generated label stable within its family, an optional musician-given name, optional Intensity and either inherited or fully overridden grammar; labels imply no order or preference. Intensity does not guide Victory 3 generation.
_Avoid_: Alternative, alternate role

**Default Variant**:
The preferred available Variant used when no other choice is requested. Generation falls back to another available Variant when the recorded default has a Gone Source.
_Avoid_: Primary component, canonical recording

**Classified Idea**:
An Idea with at least one available Main Variant and no corrupt classification. Pickup, Turnaround and Ending families are optional, so their absence does not make an Idea incomplete.
_Avoid_: Complete Idea, arranged Idea

**Split Recovery**:
A non-blocking suggestion that a source item may belong to an Idea after the musician split it outside HIT. Recovery requires explicit confirmation.
_Avoid_: Automatic reassignment, split popup

**Composition**:
The source-of-truth description of a musical arrangement. Victory 3 uses one Composition containing one Occurrence.
_Avoid_: Passage

**Occurrence**:
One appearance of an Idea in a Composition, including its target duration and Phrase Sequence.
_Avoid_: Passage

**Passage**:
Player-facing language for the longer musical result generated from one Idea. It is not a separate domain entity.
_Avoid_: Passage model

**Target Duration**:
A loose whole-bar length preference for the entire audible Phrase Sequence, from Pickup start through Ending tail and accounting for overlaps. Victory 3 defaults to 48 bars, permits larger values and may finish shorter or longer so Source Media remains intact.
_Avoid_: Exact duration, hard limit

**Phrase Sequence**:
An ordered, grammar-valid choice and placement of Variants for one Occurrence. Permitted overlaps are optional and use a deterministic amount capped at one bar or one quarter of the shorter phrase, whichever is less.
_Avoid_: Clip arrangement

**Source Palette**:
The Variants whose Source References resolve to items when generating a Suggestion. Every member may be chosen, including items with offline media; none must appear.
_Avoid_: Required source list

**Suggestion**:
A proposed Phrase Sequence with an explanation and deterministic seed. Trying another Suggestion changes the seed; rebuilding one does not.
_Avoid_: Random build

**Build**:
A generated, playable copy of one Suggestion inside its own muteable REAPER folder with two alternating tracks for phrase changes and overlaps. Builds remain for comparison; generating a new Build mutes older Builds and leaves the new one audible. Musician edits remain canonical within the Build and may later be scanned into a new Composition revision.
_Avoid_: Source Media, live arrangement

**Develop This**:
A later workflow that scans a musician-edited Build and makes its current arrangement the basis of a new Composition revision.
_Avoid_: Rebuild, live synchronisation
