-- Run from repository root: tests/run_reaper_idea_probe.sh
package.path = "src/?.lua;src/?/init.lua;" .. package.path

local ideas = require("hit.reaper.ideas")
local mode = assert(
  os.getenv("HIT_IDEA_PROBE_MODE"),
  "HIT_IDEA_PROBE_MODE must be write or reload; never run this probe in a working project"
)
local run_id = assert(os.getenv("HIT_IDEA_PROBE_RUN_ID"), "HIT_IDEA_PROBE_RUN_ID is required")
local source_audio_path = "/System/Library/Sounds/Glass.aiff"
local audio_path = "/tmp/hit-reaper-idea-probe.aiff"
local offline_audio_path = audio_path .. ".offline"
local output_path = "/tmp/hit-reaper-idea-probe.txt"
local expected_path = "/tmp/hit-reaper-idea-probe.expected"
local midi_expected_path = "/tmp/hit-reaper-idea-probe-midi.expected"
local project_path = "/tmp/hit-reaper-idea-probe.rpp"

local function item_facts(item)
  local chunk_ok, chunk = reaper.GetItemStateChunk(item, "", false)
  local guid_ok, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local take = reaper.GetActiveTake(item)
  assert(chunk_ok and guid_ok and take)
  local take_guid_ok, take_guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
  assert(take_guid_ok)
  return {
    chunk = chunk,
    guid = guid,
    position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    take_guid = take_guid,
    take_name = reaper.GetTakeName(take),
    channels = reaper.GetMediaSourceNumChannels(reaper.GetMediaItemTake_Source(take)),
  }
end

local function find_item(project, expected_guid)
  for index = 0, reaper.CountMediaItems(project) - 1 do
    local current = reaper.GetMediaItem(project, index)
    local ok, guid = reaper.GetSetMediaItemInfo_String(current, "GUID", "", false)
    if ok and guid == expected_guid then
      return current
    end
  end
end

local function assert_item_unchanged(project, expected)
  local item = assert(find_item(project, expected.guid), "source item missing")
  local actual = item_facts(item)
  assert(actual.chunk == expected.chunk)
  assert(actual.guid == expected.guid)
  assert(actual.position == expected.position)
  assert(actual.length == expected.length)
  assert(actual.take_guid == expected.take_guid)
  assert(actual.take_name == expected.take_name)
  assert(actual.channels == expected.channels)
end

local function only_idea(project)
  local view, load_error = ideas.load(project)
  assert(view, load_error)
  assert(#view.ideas == 1)
  return view.ideas[1]
end

local function idea_by_id(view, expected_id)
  for _, current in ipairs(view.ideas) do
    if current.id == expected_id then
      return current
    end
  end
end

local function reload()
  local expected = assert(io.open(expected_path, "r"))
  assert(expected:read("*l") == run_id, "stale probe expectation")
  local expected_id = assert(expected:read("*l"))
  local expected_source = assert(expected:read("*l"))
  local expected_name = assert(expected:read("*l"))
  local expected_source_name = assert(expected:read("*l"))
  local expected_track_name = assert(expected:read("*l"))
  local expected_position = assert(tonumber(expected:read("*l")))
  local expected_chunk = expected:read("*a")
  expected:close()

  local midi_expected = assert(io.open(midi_expected_path, "r"))
  assert(midi_expected:read("*l") == run_id, "stale MIDI probe expectation")
  local expected_midi_id = assert(midi_expected:read("*l"))
  local expected_midi_source = assert(midi_expected:read("*l"))
  local expected_midi_name = assert(midi_expected:read("*l"))
  local expected_midi_source_name = assert(midi_expected:read("*l"))
  local expected_midi_chunk = midi_expected:read("*a")
  midi_expected:close()

  local project = reaper.EnumProjects(-1)
  assert(reaper.CountMediaItems(project) == 2)
  local view, load_error = ideas.load(project)
  assert(view, load_error)
  assert(#view.ideas == 2)
  local current = assert(idea_by_id(view, expected_id))
  local midi_current = assert(idea_by_id(view, expected_midi_id))
  assert(current.id == expected_id)
  assert(current.name == expected_name)
  assert(current.source_item_guid == expected_source)
  assert(current.source_status == "available")
  assert(current.source_name == expected_source_name)
  assert(current.source_kind == "audio")
  assert(current.track_name == expected_track_name)
  assert(current.track_index == 2)
  assert(current.position == expected_position)
  assert(current.track_hidden == true)
  assert(midi_current.id == expected_midi_id)
  assert(midi_current.name == expected_midi_name)
  assert(midi_current.source_item_guid == expected_midi_source)
  assert(midi_current.source_status == "available")
  assert(midi_current.source_name == expected_midi_source_name)
  assert(midi_current.source_kind == "midi")

  local facts = item_facts(assert(find_item(project, expected_source)))
  assert(facts.guid == expected_source)
  assert(facts.chunk == expected_chunk)
  local midi_facts = item_facts(assert(find_item(project, expected_midi_source)))
  assert(midi_facts.guid == expected_midi_source)
  assert(midi_facts.chunk == expected_midi_chunk)

  local output = assert(io.open(output_path, "a"))
  output:write("reloaded_id\t", current.id, "\n")
  output:write("reloaded_source\t", current.source_item_guid, "\n")
  output:write("reloaded_status\t", current.source_status, "\n")
  output:write("reloaded_item_unchanged\ttrue\n")
  output:write("reloaded_name\t", current.name, "\n")
  output:write("reloaded_source_name\t", current.source_name, "\n")
  output:write("reloaded_track\t", current.track_name, "\n")
  output:write("reloaded_position\t", current.position, "\n")
  output:write("reloaded_idea_count\t2\n")
  output:write("reloaded_midi_id\t", midi_current.id, "\n")
  output:write("reloaded_midi_source\t", midi_current.source_item_guid, "\n")
  output:write("reloaded_midi_kind\t", midi_current.source_kind, "\n")
  output:write("reloaded_midi_item_unchanged\ttrue\n")
  output:write("reloaded\t", run_id, "\n")
  output:close()
end

local function write()
  local audio = assert(io.open(source_audio_path, "rb"), "probe audio file unavailable")
  local audio_data = audio:read("*a")
  audio:close()
  local copy = assert(io.open(audio_path, "wb"))
  copy:write(audio_data)
  copy:close()

  local project = reaper.EnumProjects(-1)
  assert(reaper.CountTracks(project) == 0, "write probe requires a disposable empty project")

  reaper.Undo_BeginBlock2(project)
  reaper.InsertTrackAtIndex(0, false)
  local track = reaper.GetTrack(project, 0)
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  local source = assert(reaper.PCM_Source_CreateFromFile(audio_path))
  reaper.SetMediaItemTake_Source(take, source)
  local source_length = reaper.GetMediaSourceLength(source)
  assert(source_length > 0)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", source_length)
  assert(reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "Glass source", true))
  reaper.SetMediaItemSelected(item, true)
  reaper.Undo_EndBlock2(project, "HIT probe setup", -1)
  reaper.Main_SaveProjectEx(project, project_path, 8)
  assert(reaper.IsProjectDirty(project) == 0)

  local before = item_facts(item)
  local selected, selection_error = ideas.selected_item(project)
  assert(selected, selection_error)
  assert(selected.suggested_name ~= "")
  assert(selected.source_item_guid == before.guid)

  local created, create_error = ideas.create(project, selected.source_item_guid, "  Idea A  ")
  assert(created, create_error)
  assert(created.name == "Idea A")
  assert(created.source_item_guid == before.guid)
  assert(reaper.Undo_CanUndo2(project) == "HIT: Create Idea Idea A")
  assert(reaper.IsProjectDirty(project) ~= 0)
  local created_view = only_idea(project)
  assert(created_view.id == created.id)
  assert(created_view.source_item_guid == created.source_item_guid)
  assert(created_view.source_status == "available")
  assert_item_unchanged(project, before)

  local undo_result = reaper.Undo_DoUndo2(project)
  assert(undo_result ~= 0)
  local undone, undo_load_error = ideas.load(project)
  assert(undone, undo_load_error)
  assert(#undone.ideas == 0)
  assert_item_unchanged(project, before)

  local redo_result = reaper.Undo_DoRedo2(project)
  assert(redo_result ~= 0)
  local redone = only_idea(project)
  assert(redone.id == created.id)
  assert(redone.source_item_guid == created.source_item_guid)
  assert(redone.source_status == "available")
  assert(reaper.IsProjectDirty(project) ~= 0)
  assert_item_unchanged(project, before)

  item = assert(find_item(project, created.source_item_guid))
  take = assert(reaper.GetActiveTake(item))
  reaper.Undo_BeginBlock2(project)
  reaper.InsertTrackAtIndex(1, false)
  local moved_track = reaper.GetTrack(project, 1)
  assert(reaper.GetSetMediaTrackInfo_String(moved_track, "P_NAME", "Moved Sources", true))
  assert(reaper.MoveMediaItemToTrack(item, moved_track))
  assert(reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "Renamed Glass source", true))
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", 12.5)
  reaper.SetMediaTrackInfo_Value(moved_track, "B_SHOWINTCP", 0)
  reaper.SetMediaTrackInfo_Value(moved_track, "B_SHOWINMIXER", 0)
  reaper.Undo_EndBlock2(project, "Musician: Move and rename source", -1)

  local live = only_idea(project)
  assert(live.id == created.id)
  assert(live.name == "Idea A")
  assert(live.source_item_guid == created.source_item_guid)
  assert(live.source_status == "available")
  assert(live.source_name == "Renamed Glass source")
  assert(live.source_kind == "audio")
  assert(live.track_name == "Moved Sources")
  assert(live.track_index == 2)
  assert(live.position == 12.5)
  assert(live.duration == before.length)
  assert(live.track_hidden == true)

  local alternate_take = reaper.AddTakeToMediaItem(item)
  local alternate_source = assert(reaper.PCM_Source_CreateFromFile(audio_path))
  reaper.SetMediaItemTake_Source(alternate_take, alternate_source)
  assert(reaper.GetSetMediaItemTakeInfo_String(
    alternate_take,
    "P_NAME",
    "Alternate Glass source",
    true
  ))
  reaper.SetActiveTake(alternate_take)
  local switched_take = only_idea(project)
  assert(switched_take.id == created.id)
  assert(switched_take.name == "Idea A")
  assert(switched_take.source_name == "Alternate Glass source")
  assert(switched_take.source_kind == "audio")
  reaper.SetActiveTake(take)
  assert(only_idea(project).source_name == "Renamed Glass source")

  reaper.SelectAllMediaItems(project, false)
  reaper.SetEditCurPos2(project, 37.25, false, false)
  local cursor_before_select = reaper.GetCursorPositionEx(project)
  local tcp_visibility = reaper.GetMediaTrackInfo_Value(moved_track, "B_SHOWINTCP")
  local mixer_visibility = reaper.GetMediaTrackInfo_Value(moved_track, "B_SHOWINMIXER")
  local selected_source, select_error = ideas.select_source(project, created.source_item_guid)
  assert(selected_source, select_error)
  assert(reaper.CountSelectedMediaItems(project) == 1)
  local selected_item = reaper.GetSelectedMediaItem(project, 0)
  local selected_facts = item_facts(selected_item)
  assert(selected_facts.guid == created.source_item_guid)
  assert(reaper.GetCursorPositionEx(project) == cursor_before_select)
  assert(reaper.GetMediaTrackInfo_Value(moved_track, "B_SHOWINTCP") == tcp_visibility)
  assert(reaper.GetMediaTrackInfo_Value(moved_track, "B_SHOWINMIXER") == mixer_visibility)

  reaper.Undo_BeginBlock2(project)
  assert(reaper.DeleteTrackMediaItem(moved_track, selected_item))
  reaper.Undo_EndBlock2(project, "Musician: Delete source", -1)
  assert(reaper.CountMediaItems(project) == 0)
  local missing = only_idea(project)
  assert(missing.id == created.id)
  assert(missing.name == "Idea A")
  assert(missing.source_item_guid == created.source_item_guid)
  assert(missing.source_status == "missing")
  assert(missing.source_name == nil)

  local restore_result = reaper.Undo_DoUndo2(project)
  assert(restore_result ~= 0)
  local restored_item = assert(find_item(project, created.source_item_guid))
  local recovered = only_idea(project)
  assert(recovered.id == created.id)
  assert(recovered.name == "Idea A")
  assert(recovered.source_item_guid == created.source_item_guid)
  assert(recovered.source_status == "available")
  assert(recovered.source_name == "Renamed Glass source")
  assert(recovered.track_name == "Moved Sources")
  assert(recovered.position == 12.5)

  os.remove(offline_audio_path)
  assert(os.rename(audio_path, offline_audio_path))
  local offline = only_idea(project)
  assert(offline.source_status == "unavailable")
  assert(offline.source_kind == "audio")
  assert(os.rename(offline_audio_path, audio_path))
  local online_again = only_idea(project)
  assert(online_again.source_status == "available")

  local duplicate = reaper.AddMediaItemToTrack(moved_track)
  assert(reaper.GetSetMediaItemInfo_String(
    duplicate,
    "GUID",
    created.source_item_guid,
    true
  ))
  local ambiguous = only_idea(project)
  assert(ambiguous.source_status == "ambiguous")
  local ambiguous_selection, ambiguous_error = ideas.select_source(
    project,
    created.source_item_guid
  )
  assert(ambiguous_selection == nil and ambiguous_error == "source_ambiguous")
  assert(reaper.DeleteTrackMediaItem(moved_track, duplicate))
  assert(only_idea(project).source_status == "available")

  reaper.Undo_BeginBlock2(project)
  reaper.InsertTrackAtIndex(2, false)
  local midi_track = reaper.GetTrack(project, 2)
  assert(reaper.GetSetMediaTrackInfo_String(midi_track, "P_NAME", "MIDI Sources", true))
  local midi_item = assert(reaper.CreateNewMIDIItemInProj(midi_track, 20, 24, false))
  local midi_take = assert(reaper.GetActiveTake(midi_item))
  assert(reaper.TakeIsMIDI(midi_take))
  assert(reaper.GetSetMediaItemTakeInfo_String(midi_take, "P_NAME", "MIDI source", true))
  assert(reaper.MIDI_InsertNote(midi_take, false, false, 0, 960, 0, 60, 100, false))
  reaper.MIDI_Sort(midi_take)
  for item_index = 0, reaper.CountMediaItems(project) - 1 do
    reaper.SetMediaItemSelected(reaper.GetMediaItem(project, item_index), false)
  end
  reaper.SetMediaItemSelected(midi_item, true)
  reaper.Undo_EndBlock2(project, "HIT MIDI probe setup", -1)
  reaper.Main_SaveProjectEx(project, project_path, 8)
  assert(reaper.IsProjectDirty(project) == 0)

  local audio_before_midi = item_facts(assert(find_item(project, created.source_item_guid)))
  local midi_before = item_facts(midi_item)
  local midi_selected, midi_selection_error = ideas.selected_item(project)
  assert(midi_selected, midi_selection_error)
  assert(midi_selected.source_kind == "midi")
  assert(midi_selected.suggested_name == "MIDI source")
  assert(midi_selected.source_item_guid == midi_before.guid)

  local midi_created, midi_create_error = ideas.create(
    project,
    midi_selected.source_item_guid,
    "MIDI Idea"
  )
  assert(midi_created, midi_create_error)
  assert(midi_created.name == "MIDI Idea")
  assert(midi_created.source_item_guid == midi_before.guid)
  assert(reaper.Undo_CanUndo2(project) == "HIT: Create Idea MIDI Idea")
  assert(reaper.IsProjectDirty(project) ~= 0)
  local with_midi, with_midi_error = ideas.load(project)
  assert(with_midi, with_midi_error)
  assert(#with_midi.ideas == 2)
  local midi_created_view = assert(idea_by_id(with_midi, midi_created.id))
  assert(midi_created_view.source_kind == "midi")
  assert(midi_created_view.source_status == "available")
  assert_item_unchanged(project, audio_before_midi)
  assert_item_unchanged(project, midi_before)

  local midi_undo_result = reaper.Undo_DoUndo2(project)
  assert(midi_undo_result ~= 0)
  local without_midi, without_midi_error = ideas.load(project)
  assert(without_midi, without_midi_error)
  assert(#without_midi.ideas == 1)
  local audio_after_midi_undo = assert(idea_by_id(without_midi, created.id))
  assert(audio_after_midi_undo.source_item_guid == created.source_item_guid)
  assert(audio_after_midi_undo.source_status == "available")
  assert(audio_after_midi_undo.source_kind == "audio")
  assert_item_unchanged(project, audio_before_midi)
  assert_item_unchanged(project, midi_before)

  local midi_redo_result = reaper.Undo_DoRedo2(project)
  assert(midi_redo_result ~= 0)
  local after_midi_redo, midi_redo_error = ideas.load(project)
  assert(after_midi_redo, midi_redo_error)
  assert(#after_midi_redo.ideas == 2)
  local midi_redone = assert(idea_by_id(after_midi_redo, midi_created.id))
  assert(midi_redone.id == midi_created.id)
  assert(midi_redone.source_item_guid == midi_created.source_item_guid)
  assert(midi_redone.source_kind == "midi")
  assert(reaper.IsProjectDirty(project) ~= 0)
  assert_item_unchanged(project, audio_before_midi)
  assert_item_unchanged(project, midi_before)

  reaper.Main_SaveProjectEx(project, project_path, 8)
  assert_item_unchanged(project, audio_before_midi)
  assert_item_unchanged(project, midi_before)

  local expected = assert(io.open(expected_path, "w"))
  expected:write(
    run_id,
    "\n",
    created.id,
    "\n",
    created.source_item_guid,
    "\n",
    recovered.name,
    "\n",
    recovered.source_name,
    "\n",
    recovered.track_name,
    "\n",
    recovered.position,
    "\n",
    audio_before_midi.chunk
  )
  expected:close()

  local midi_expected = assert(io.open(midi_expected_path, "w"))
  midi_expected:write(
    run_id,
    "\n",
    midi_created.id,
    "\n",
    midi_created.source_item_guid,
    "\n",
    midi_created.name,
    "\n",
    midi_created_view.source_name,
    "\n",
    midi_before.chunk
  )
  midi_expected:close()

  local output = assert(io.open(output_path, "w"))
  output:write("variant\treal_audio_adapter\n")
  output:write("reaper_version\t", reaper.GetAppVersion(), "\n")
  output:write("audio\t", source_audio_path, "\n")
  output:write("prefill\t", selected.suggested_name, "\n")
  output:write("created_name\t", created.name, "\n")
  output:write("created_id\t", created.id, "\n")
  output:write("created_source\t", created.source_item_guid, "\n")
  output:write("undo_label\tHIT: Create Idea Idea A\n")
  output:write("dirty_after_create\ttrue\n")
  output:write("undo_result\t", undo_result, "\n")
  output:write("ideas_after_undo\t0\n")
  output:write("redo_result\t", redo_result, "\n")
  output:write("redo_id\t", redone.id, "\n")
  output:write("redo_source\t", redone.source_item_guid, "\n")
  output:write("dirty_after_redo\ttrue\n")
  output:write("item_unchanged\ttrue\n")
  output:write("live_name\t", live.name, "\n")
  output:write("live_source_name\t", live.source_name, "\n")
  output:write("live_track\t", live.track_name, "\n")
  output:write("live_position\t", live.position, "\n")
  output:write("active_take_source_name\t", switched_take.source_name, "\n")
  output:write("active_take_idea_name\t", switched_take.name, "\n")
  output:write("select_source\ttrue\n")
  output:write("selected_source\t", selected_facts.guid, "\n")
  output:write("edit_cursor_unchanged\ttrue\n")
  output:write("track_visibility_unchanged\ttrue\n")
  output:write("missing_status\t", missing.source_status, "\n")
  output:write("missing_no_reassignment\ttrue\n")
  output:write("restore_result\t", restore_result, "\n")
  output:write("recovered_id\t", recovered.id, "\n")
  output:write("recovered_status\t", recovered.source_status, "\n")
  output:write("recovered_source_name\t", recovered.source_name, "\n")
  output:write("offline_status\t", offline.source_status, "\n")
  output:write("offline_kind\t", offline.source_kind, "\n")
  output:write("online_recovered\t", online_again.source_status, "\n")
  output:write("ambiguous_status\t", ambiguous.source_status, "\n")
  output:write("ambiguous_select_error\t", ambiguous_error, "\n")
  output:write("midi_prefill\t", midi_selected.suggested_name, "\n")
  output:write("midi_kind\t", midi_selected.source_kind, "\n")
  output:write("midi_created_name\t", midi_created.name, "\n")
  output:write("midi_created_id\t", midi_created.id, "\n")
  output:write("midi_created_source\t", midi_created.source_item_guid, "\n")
  output:write("midi_undo_label\tHIT: Create Idea MIDI Idea\n")
  output:write("midi_dirty_after_create\ttrue\n")
  output:write("midi_item_unchanged\ttrue\n")
  output:write("midi_undo_result\t", midi_undo_result, "\n")
  output:write("ideas_after_midi_undo\t1\n")
  output:write("audio_survived_midi_undo\ttrue\n")
  output:write("midi_redo_result\t", midi_redo_result, "\n")
  output:write("midi_redo_id\t", midi_redone.id, "\n")
  output:write("midi_redo_source\t", midi_redone.source_item_guid, "\n")
  output:write("midi_dirty_after_redo\ttrue\n")
  output:write("saved_project\t", project_path, "\n")
  output:write("saved\t", run_id, "\n")
  output:close()
end

local ok, trace = xpcall(function()
  if mode == "write" then
    write()
  elseif mode == "reload" then
    reload()
  else
    error("HIT_IDEA_PROBE_MODE must be write or reload")
  end
end, debug.traceback)

if not ok then
  local output = assert(io.open(output_path, mode == "write" and "w" or "a"))
  output:write("error\t", trace:gsub("\n", " | "), "\n")
  output:close()
  error(trace)
end
