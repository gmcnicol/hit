# Codex guidance

Before planning or implementing work in this repository, read:

1. `README.md`
2. `docs/PHILOSOPHY.md`
3. `docs/DOMAIN_MODEL.md`
4. `docs/ARCHITECTURE.md`
5. `docs/CAMPAIGN.md`
6. `docs/CURRENT_VICTORY.md`

## Working rule

Work towards the Current Victory, not the whole campaign.

Use the installed specification and planning skills to turn the Current Victory into a detailed, testable plan before implementation.

Do not create a speculative backlog for later victories unless explicitly asked.

## Product constraints

- The musician supplies the musical source material.
- An Idea may be one recorded item.
- Missing layers are suggestions, not fictional media.
- The tool must be item-aware and must not assume uniform four-bar loops.
- The default interaction is high-level direction rather than manual block arrangement.
- Source recordings are non-destructive and immutable to compilers.
- Generated demos are disposable outputs.
- The domain model must remain independent of direct REAPER API calls.
- Use Lua and ReaImGui initially.
- Airwindows Meter is an analysis adapter, not the artistic authority.
- Production Mapper and Afterimage are later sister projects.

## Definition of useful progress

Prefer thin vertical slices that create a musical or creative outcome.

Infrastructure is only complete when it enables the stated Victory Condition and its Evidence of Victory.

## ReaImGui

Keep every window's ImGui identity stable. When its visible title changes between views, append a constant `###window_id`; otherwise ReaImGui treats each title as a separate window and restores unrelated positions.

Let immediate-mode content determine panel and window height. Use auto-resizing child panels for visual grouping; do not guess fixed child heights or create nested scrollbars for non-scrolling content.

In ReaImGui, `Begin` and `BeginChild` automatically close themselves when they return false. Call `End` or `EndChild` only when the matching call returned true, or the window stack will be corrupted.

## Writing

Use the installed `caveman` skill at full intensity by default. Keep it active until the user says `stop caveman` or `normal mode`.

Use plain English unless the user requests another language. Do not insert stray non-English words, playful filler or decorative text.

## Agent skills

### Issue tracker

Issues and specs use GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Default triage vocabulary is used. See `docs/agents/triage-labels.md`.

### Domain docs

This repository uses a single-context domain layout. See `docs/agents/domain.md`.
