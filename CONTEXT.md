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
The structural rules governing whether a Phrase Family or Variant may begin, repeat, end, lead to another family or overlap its successor.
_Avoid_: Arrangement, energy profile

**Variant**:
One classified use of a Source Reference belonging to one Phrase Family. It has a stable Component identity, a generated label stable within its family, an optional musician-given name and either inherited or fully overridden grammar; labels imply no order or preference.
_Avoid_: Alternative, alternate role

**Default Variant**:
The preferred Variant used when no other choice is requested. Every non-empty Phrase Family has exactly one, independently of its label.
_Avoid_: Primary component, canonical recording

**Classified Idea**:
An Idea with at least one available Main Variant and no corrupt classification. Pickup, Turnaround and Ending families are optional, so their absence does not make an Idea incomplete.
_Avoid_: Complete Idea, arranged Idea

**Split Recovery**:
A non-blocking suggestion that a source item may belong to an Idea after the musician split it outside HIT. Recovery requires explicit confirmation.
_Avoid_: Automatic reassignment, split popup
