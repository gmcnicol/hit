# Victory 3 manual acceptance

Use a disposable REAPER 7 project with ReaImGui 0.10 and one real Classified Idea. Include mixed phrase lengths, one long Variant and at least one family rule that permits overlap. Save before starting.

## Generate workflow

1. Open the Idea and choose **Generate**.
2. Confirm Target Bars starts at `48`, Seed starts at `1`, and the Source Palette summary includes offline items but excludes Gone and ambiguous sources.
3. Place REAPER's edit cursor away from a measure boundary, then choose **Generate**.
4. Confirm one playable Build begins exactly at the cursor. Confirm the Generate view immediately shows requested bars, achieved bars, seed, Phrase Sequence and structural explanation.
5. Confirm every generated phrase remains complete. Check one long Variant, source fades, take properties and audible timing.
6. Confirm Family colour and visible Family and Variant text agree. Confirm phrase changes alternate Lane A and Lane B, and any overlap occupies both lanes without a third simultaneous phrase.

## Processing and ownership

1. Confirm the Build folder has the available Default Main source track's FX, volume, pan and width.
2. Confirm lanes remain neutral. Confirm routing, hardware outputs, automation and recording state were not copied.
3. Inspect generated audio and MIDI. Confirm audio items have new item and take identities while referencing the same media. Edit one generated MIDI note and confirm the source MIDI does not change.
4. Rename the generated root, Build, lanes and items. Reopen HIT and confirm ownership still works because metadata, not names, identifies them.

## Compare Builds

1. Keep Seed unchanged and choose **Try Another**. Confirm it uses the next seed.
2. Confirm the first Build remains but mutes, the new Build is audible and both remain listed.
3. Manually move, trim, rename, mute and delete material in the first Build.
4. Generate once more. Confirm HIT does not repair or overwrite those edits.
5. Move one whole Build outside the generated root, unmute it, then generate again. Confirm the detached Build keeps its mute state while contained older Builds mute.
6. Manually mute the generated root, then generate again. Confirm root mute remains unchanged.

## Undo and durability

1. Undo one Generate action. Confirm new tracks, items and V3 metadata disappear together and prior Build mute states return.
2. Redo. Confirm the same Build identity, Phrase Sequence, lanes, items and mute states return.
3. Save, close and reopen the project.
4. Confirm Composition, Occurrence, Suggestion, requested and achieved duration, seed, Build list, generated ownership and item provenance return.
5. Audition at least two seeds. Confirm one result is a coherent evolving passage worth editing, not merely repeated manual copies.

## Automated evidence

```sh
scripts/check
tests/run_reaper_generation_probe.sh
```

The live proof uses `/tmp/hit-reaper-generation-probe.rpp`. It proves independent audio and MIDI copies, selective processing, cursor-relative measures across a time-signature change, metadata ownership, two-lane publication, mute lifecycle, manual-edit preservation, atomic rollback, native undo and redo, Generate-view rendering and save/reopen against real REAPER.
