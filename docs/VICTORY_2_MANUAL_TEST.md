# Victory 2 manual acceptance

Use a disposable REAPER 7 project with ReaImGui 0.10. Add one longer audio or MIDI item plus several separate items. Save before starting.

## Phrases workflow

1. Select the longer item, create an Idea, open its Phrases view, and confirm Main A is the sole Default Variant.
2. Select several supported items and choose **Add selected items as Main Variants**. Confirm each becomes an independent Variant in track and timeline order.
3. Undo and redo. Confirm source media never moves or changes and Component IDs return unchanged.
4. Select Variants and use **Move** to populate Pickup, Main, Turnaround and Ending. Confirm every non-empty family has one gold Default star.
5. Use **Alternate Uses** to classify one Source Reference in another family. Confirm both rows show Shared and no media is copied.
6. Enter a Variant name, set and unset Intensity, choose another Default, edit family Phrase Rules, create one complete Variant override, then restore inheritance.
7. Undo and redo each mutation. Confirm one clear `HIT:` undo record per action.

## HIT Split

1. Select a Variant in Phrases and place REAPER's edit cursor strictly inside its source item.
2. Choose **HIT Split**.
3. Confirm the original Component remains linked to the left item and a new Component and Source Reference appear for the right item in the same family.
4. Undo and confirm exact prior item topology and phrase state.
5. Redo and confirm exact left and right Component and Source Reference identities.
6. Try a cursor outside the item. Confirm an inline error and no change.

## Ordinary split recovery

1. Keep Phrases open, then split a classified source with REAPER's ordinary split action.
2. Confirm a quiet Recovery candidate appears at the bottom and explains the inferred boundary.
3. Attach it. Confirm it becomes a Variant in the originating family.
4. Create another ordinary split and dismiss it. Refresh and confirm it does not recur.
5. Confirm ambiguous topology produces no automatic attachment or reassignment.

## Durability and layout

1. Resize the HIT window narrow and wide. Confirm normal panels fit content and only a long Variant list scrolls.
2. Switch project tabs. Confirm the bound window disables mutation.
3. Save, close and reopen the project.
4. Confirm exact Idea, Component and Source Reference identities, names, Intensity, defaults, rules, recovery attachment and dismissal return.

## Automated evidence

```sh
for test in tests/*_test.lua; do lua "$test"; done
tests/run_reaper_idea_probe.sh
```

The live probe uses a disposable `/tmp` project. It proves native HIT Split, handle reacquisition, undo, redo, ordinary split recovery and reopen against real REAPER.
