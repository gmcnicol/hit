package.path = "src/?.lua;src/?/init.lua;" .. package.path

local codec = require("hit.model.state_codec")
local project = {}
local track_a = { name = "Guitars", index = 1, hidden = false }
local track_b = {
  name = "Bass",
  index = 2,
  hidden = true,
}
local master = {
  state = codec.encode({
    version = 1,
    ideas = {
      { id = "{00000002-0000-0000-0000-000000000002}", name = "Available", source_item_guid = "{10000002-0000-0000-0000-000000000002}" },
      { id = "{00000003-0000-0000-0000-000000000003}", name = "Moved", source_item_guid = "{10000003-0000-0000-0000-000000000003}" },
      { id = "{00000004-0000-0000-0000-000000000004}", name = "Missing", source_item_guid = "{10000004-0000-0000-0000-000000000004}" },
    },
  }),
}
local source_a = { channels = 2 }
local take_a = { name = "Take A", source = source_a, midi = false }
local take_b = { name = "Bass live", source = source_a, midi = false }
local take_c = { name = "MIDI live", source = nil, midi = true }
local item_a = {
  guid = "{10000001-0000-0000-0000-000000000001}",
  track = track_a,
  take = take_a,
  position = 12,
  length = 4,
  selected = false,
}
local item_b = {
  guid = "{10000002-0000-0000-0000-000000000002}",
  track = track_b,
  take = take_b,
  position = 3,
  length = 8,
  selected = false,
}
local item_c = {
  guid = "{10000003-0000-0000-0000-000000000003}",
  track = track_a,
  take = take_c,
  position = 2,
  length = 1.5,
  selected = false,
}
local tracks = { track_a, track_b }
local items = { item_a, item_b, item_c }
local selected = {}
local calls = {}
local edit_cursor = 99
local arrange_start = 0
local arrange_end = 10
local generated_ids = {
  "{00000001-0000-0000-0000-000000000001}",
  "{00000005-0000-0000-0000-000000000005}",
  "{00000006-0000-0000-0000-000000000006}",
  "{00000007-0000-0000-0000-000000000007}",
  "{00000008-0000-0000-0000-000000000008}",
}
local generated_index = 0
local state_write_hook

reaper = {
  CountSelectedMediaItems = function()
    return #selected
  end,
  GetSelectedMediaItem = function(_, index)
    return selected[index + 1]
  end,
  GetActiveTake = function(item)
    return item.take
  end,
  GetMediaItemTake_Source = function(take)
    return take.source
  end,
  TakeIsMIDI = function(take)
    return take.midi
  end,
  GetMediaSourceNumChannels = function(source)
    assert(source, "MIDI selection must not require audio channels")
    return source.channels
  end,
  GetMediaSourceType = function(source)
    return source.kind or "WAVE"
  end,
  GetMediaSourceFileName = function(source)
    return source.filename or ""
  end,
  file_exists = function(path)
    return path ~= "/missing"
  end,
  GetSetMediaItemInfo_String = function(item, parameter)
    assert(parameter == "GUID")
    return item.guid ~= nil, item.guid or ""
  end,
  GetMediaItem_Track = function(item)
    return item.track
  end,
  GetTakeName = function(take)
    return take.name
  end,
  GetMediaItemInfo_Value = function(item, parameter)
    if parameter == "D_POSITION" then
      return item.position
    end
    assert(parameter == "D_LENGTH")
    return item.length
  end,
  SetMediaItemInfo_Value = function(item, parameter, value)
    if parameter == "D_POSITION" then
      item.position = value
    else
      assert(parameter == "D_LENGTH")
      item.length = value
    end
  end,
  GetMediaTrackInfo_Value = function(track, parameter)
    if parameter == "IP_TRACKNUMBER" then
      return track.index
    end
    assert(parameter == "B_SHOWINTCP")
    return track.hidden and 0 or 1
  end,
  SetMediaTrackInfo_Value = function(track, parameter, value)
    assert(parameter == "B_SHOWINTCP")
    track.hidden = value == 0
  end,
  GetTrackName = function(track)
    return true, track.name
  end,
  IsMediaItemSelected = function(item)
    return item.selected
  end,
  format_timestr_pos = function(position, _, mode)
    assert(mode == -1)
    return "P:" .. position
  end,
  format_timestr_len = function(length, _, offset, mode)
    assert(mode == -1)
    return "L:" .. length .. "@" .. offset
  end,
  CountTracks = function()
    return #tracks
  end,
  GetTrack = function(_, index)
    return tracks[index + 1]
  end,
  GetMasterTrack = function()
    return master
  end,
  GetSetMediaTrackInfo_String = function(track, parameter, value, set)
    assert(track == master, "HIT state must use master track")
    assert(parameter == "P_EXT:HIT_STATE_V1")
    if set then
      calls[#calls + 1] = "write"
      if state_write_hook then
        return state_write_hook(track, value)
      end
      track.state = value
      return true, value
    end
    return track.state ~= "", track.state
  end,
  CountMediaItems = function()
    return #items
  end,
  GetMediaItem = function(_, index)
    return items[index + 1]
  end,
  genGuid = function()
    generated_index = generated_index + 1
    return generated_ids[generated_index]
  end,
  Undo_BeginBlock2 = function()
    calls[#calls + 1] = "begin"
  end,
  MarkProjectDirty = function()
    calls[#calls + 1] = "dirty"
  end,
  Undo_EndBlock2 = function(_, label, flags)
    calls[#calls + 1] = "end:" .. label .. ":" .. flags
  end,
  SelectAllMediaItems = function(_, value)
    assert(value == false)
    selected = {}
    for _, item in ipairs(items) do
      item.selected = false
    end
  end,
  SetMediaItemSelected = function(item, value)
    assert(value == true)
    item.selected = true
    selected = { item }
  end,
  UpdateArrange = function()
    calls[#calls + 1] = "refresh"
  end,
  GetCursorPositionEx = function()
    return edit_cursor
  end,
  SetEditCurPos2 = function(_, position)
    edit_cursor = position
  end,
  GetSet_ArrangeView2 = function(_, set, _, _, start_time, end_time)
    if set then
      arrange_start = start_time
      arrange_end = end_time
    end
    return arrange_start, arrange_end
  end,
}

local adapter = require("hit.reaper.ideas")

local no_selection, selection_error = adapter.selected_item(project)
assert(no_selection == nil and selection_error == "selection_none")

selected = { item_a, item_b }
local multiple_selection, multiple_error = adapter.selected_item(project)
assert(multiple_selection == nil and multiple_error == "selection_multiple")

selected = { item_a }
item_a.selected = true
item_a.take = nil
local no_take, take_error = adapter.selected_item(project)
assert(no_take == nil and take_error == "active_take_missing")

item_a.take = take_a
take_a.source = nil
local unavailable, unavailable_error = adapter.selected_item(project)
assert(unavailable == nil and unavailable_error == "source_unsupported")
take_a.source = { channels = 0 }
local unsupported, unsupported_error = adapter.selected_item(project)
assert(unsupported == nil and unsupported_error == "source_unsupported")
take_a.source = source_a
local item_a_guid = item_a.guid
item_a.guid = "invalid"
local invalid_guid, invalid_guid_error = adapter.selected_item(project)
assert(invalid_guid == nil and invalid_guid_error == "source_guid_invalid")
item_a.guid = item_a_guid

local candidate = assert(adapter.selected_item(project))
assert(candidate.source_item_guid == "{10000001-0000-0000-0000-000000000001}")
assert(candidate.suggested_name == "Take A")
assert(candidate.source_kind == "audio")

selected = { item_c }
local midi_candidate = assert(adapter.selected_item(project))
assert(midi_candidate.source_item_guid == "{10000003-0000-0000-0000-000000000003}")
assert(midi_candidate.suggested_name == "MIDI live")
assert(midi_candidate.source_kind == "midi")
selected = { item_a }

local before = {
  guid = item_a.guid,
  track = item_a.track,
  take = item_a.take,
  position = item_a.position,
  length = item_a.length,
}
local created = assert(adapter.create(project, "{10000001-0000-0000-0000-000000000001}", "  Idea A  "))
assert(created.id == "{00000001-0000-0000-0000-000000000001}" and created.name == "Idea A")
assert(table.concat(calls, ",") == "begin,write,end:HIT: Create Idea Idea A:-1,dirty")
assert(item_a.guid == before.guid)
assert(item_a.track == before.track)
assert(item_a.take == before.take)
assert(item_a.position == before.position)
assert(item_a.length == before.length)

local persisted = assert(codec.decode(master.state))
assert(#persisted.ideas == 4)
assert(persisted.ideas[4].source_item_guid == "{10000001-0000-0000-0000-000000000001}")

local view = assert(adapter.load(project))
local rows = {}
for _, current in ipairs(view.ideas) do
  rows[current.id] = current
end
assert(rows["{00000001-0000-0000-0000-000000000001}"].source_status == "available")
assert(rows["{00000002-0000-0000-0000-000000000002}"].source_status == "available")
assert(rows["{00000003-0000-0000-0000-000000000003}"].source_status == "available")
assert(rows["{00000004-0000-0000-0000-000000000004}"].source_status == "missing")
assert(rows["{00000003-0000-0000-0000-000000000003}"].name == "Moved")
assert(rows["{00000003-0000-0000-0000-000000000003}"].source_name == "MIDI live")
assert(rows["{00000003-0000-0000-0000-000000000003}"].source_kind == "midi")
assert(rows["{00000003-0000-0000-0000-000000000003}"].track_name == "Guitars")
assert(rows["{00000003-0000-0000-0000-000000000003}"].track_index == 1)
assert(rows["{00000003-0000-0000-0000-000000000003}"].position == 2)
assert(rows["{00000003-0000-0000-0000-000000000003}"].duration == 1.5)
assert(rows["{00000003-0000-0000-0000-000000000003}"].position_text == "P:2")
assert(rows["{00000003-0000-0000-0000-000000000003}"].duration_text == "L:1.5@2")
assert(rows["{00000003-0000-0000-0000-000000000003}"].selected == false)
assert(rows["{00000003-0000-0000-0000-000000000003}"].track_hidden == false)
assert(rows["{00000001-0000-0000-0000-000000000001}"].selected == true)
assert(rows["{00000002-0000-0000-0000-000000000002}"].source_name == "Bass live")
assert(rows["{00000002-0000-0000-0000-000000000002}"].source_kind == "audio")
assert(rows["{00000002-0000-0000-0000-000000000002}"].track_hidden == true)
assert(view.ideas[1].id == "{00000003-0000-0000-0000-000000000003}")
assert(view.ideas[2].id == "{00000001-0000-0000-0000-000000000001}")
assert(view.ideas[3].id == "{00000002-0000-0000-0000-000000000002}")
assert(view.ideas[4].id == "{00000004-0000-0000-0000-000000000004}")

track_a.name = "Renamed Guitars"
take_c.name = "Renamed MIDI"
item_c.position = 20
local refreshed = assert(adapter.load(project))
local refreshed_rows = {}
for _, current in ipairs(refreshed.ideas) do
  refreshed_rows[current.id] = current
end
assert(refreshed_rows["{00000003-0000-0000-0000-000000000003}"].name == "Moved")
assert(refreshed_rows["{00000003-0000-0000-0000-000000000003}"].source_name == "Renamed MIDI")
assert(refreshed_rows["{00000003-0000-0000-0000-000000000003}"].track_name == "Renamed Guitars")
assert(refreshed_rows["{00000003-0000-0000-0000-000000000003}"].position == 20)
assert(refreshed.ideas[1].id == "{00000001-0000-0000-0000-000000000001}")
assert(refreshed.ideas[2].id == "{00000003-0000-0000-0000-000000000003}")

local before_select = {
  cursor = reaper.GetCursorPositionEx(project),
  hidden = track_b.hidden,
  position = item_b.position,
  length = item_b.length,
}
assert(adapter.select_source(project, "{10000002-0000-0000-0000-000000000002}"))
assert(#selected == 1 and selected[1] == item_b)
assert(calls[#calls] == "refresh")
assert(reaper.GetCursorPositionEx(project) == before_select.cursor)
assert(track_b.hidden == before_select.hidden)
assert(item_b.position == before_select.position and item_b.length == before_select.length)
assert(arrange_start == 2 and arrange_end == 12)

local missing, missing_error = adapter.select_source(project, "{10000004-0000-0000-0000-000000000004}")
assert(missing == nil and missing_error == "source_missing")
assert(#selected == 1 and selected[1] == item_b)

local duplicate_item = { guid = "{10000002-0000-0000-0000-000000000002}", track = track_a, take = take_b }
items[#items + 1] = duplicate_item
local ambiguous_view = assert(adapter.load(project))
local ambiguous_rows = {}
for _, current in ipairs(ambiguous_view.ideas) do
  ambiguous_rows[current.id] = current
end
assert(ambiguous_rows["{00000002-0000-0000-0000-000000000002}"].source_status == "ambiguous")
assert(ambiguous_rows["{00000001-0000-0000-0000-000000000001}"].source_status == "available")
local ambiguous, ambiguous_error = adapter.select_source(project, "{10000002-0000-0000-0000-000000000002}")
assert(ambiguous == nil and ambiguous_error == "source_ambiguous")
assert(#selected == 1 and selected[1] == item_b)
items[#items] = nil

item_b.take = nil
take_a.source = { channels = 2, kind = "WAVE", filename = "/missing" }
local unavailable_view = assert(adapter.load(project))
local unavailable_rows = {}
for _, current in ipairs(unavailable_view.ideas) do
  unavailable_rows[current.id] = current
end
assert(unavailable_rows["{00000001-0000-0000-0000-000000000001}"].source_status == "unavailable")
assert(unavailable_rows["{00000001-0000-0000-0000-000000000001}"].source_kind == "audio")
assert(unavailable_rows["{00000002-0000-0000-0000-000000000002}"].source_status == "unavailable")
assert(unavailable_rows["{00000002-0000-0000-0000-000000000002}"].source_kind == "unknown")
assert(unavailable_rows["{00000003-0000-0000-0000-000000000003}"].source_status == "available")
assert(adapter.select_source(project, "{10000002-0000-0000-0000-000000000002}"))
item_b.take = take_b
take_a.source = source_a

selected = { item_c }
local state_before_existing = master.state
local calls_before_existing = #calls
local repeated, repeated_error, existing = adapter.create(project, "{10000003-0000-0000-0000-000000000003}", "Ignored")
assert(repeated == nil and repeated_error == "source_already_registered")
assert(existing.id == "{00000003-0000-0000-0000-000000000003}" and existing.name == "Moved")
assert(existing.source_item_guid == "{10000003-0000-0000-0000-000000000003}")
assert(master.state == state_before_existing)
assert(#calls == calls_before_existing)

local item_e = {
  guid = "{10000005-0000-0000-0000-000000000005}",
  track = track_a,
  take = { name = "", source = nil, midi = true },
  position = 30,
  length = 2,
  selected = true,
}
items[#items + 1] = item_e
selected = { item_e }
local blank_midi = assert(adapter.selected_item(project))
assert(blank_midi.suggested_name == "")
assert(blank_midi.source_kind == "midi")
local second = assert(adapter.create(project, "{10000005-0000-0000-0000-000000000005}", "Idea A"))
assert(second.id == "{00000005-0000-0000-0000-000000000005}")
assert(second.name == "Idea A")
assert(second.source_item_guid == "{10000005-0000-0000-0000-000000000005}")

local original_state = master.state
local shared_source_state = assert(codec.decode(original_state))
shared_source_state.ideas[#shared_source_state.ideas + 1] = {
  id = "{00000008-0000-0000-0000-000000000008}",
  name = "Shared source",
  source_item_guid = "{10000001-0000-0000-0000-000000000001}",
}
master.state = codec.encode(shared_source_state)
local shared_source_view = assert(adapter.load(project))
local shared_source_count = 0
for _, current in ipairs(shared_source_view.ideas) do
  if current.source_item_guid == "{10000001-0000-0000-0000-000000000001}" then
    shared_source_count = shared_source_count + 1
  end
end
assert(shared_source_count == 2)
master.state = original_state

local item_f = {
  guid = "{10000006-0000-0000-0000-000000000006}",
  track = track_a,
  take = { name = "Write failure", source = source_a, midi = false },
  position = 40,
  length = 2,
  selected = true,
}
items[#items + 1] = item_f
selected = { item_f }
local state_before_mismatch = master.state
local dirty_before_mismatch = 0
for _, call in ipairs(calls) do
  if call == "dirty" then
    dirty_before_mismatch = dirty_before_mismatch + 1
  end
end
local mismatch_writes = 0
state_write_hook = function(track, value)
  mismatch_writes = mismatch_writes + 1
  track.state = mismatch_writes == 1 and (value .. "-mismatch") or value
  return true, track.state
end
local mismatched, mismatch_error = adapter.create(project, "{10000006-0000-0000-0000-000000000006}", "Mismatch")
state_write_hook = nil
assert(mismatched == nil and mismatch_error == "state_write_failed")
assert(mismatch_writes == 2)
assert(master.state == state_before_mismatch)
local dirty_after_mismatch = 0
for _, call in ipairs(calls) do
  if call == "dirty" then
    dirty_after_mismatch = dirty_after_mismatch + 1
  end
end
assert(dirty_after_mismatch == dirty_before_mismatch)

local exception_writes = 0
state_write_hook = function(track, value)
  exception_writes = exception_writes + 1
  track.state = value
  if exception_writes == 1 then
    error("unexpected write failure")
  end
  return true, value
end
local calls_before_exception = #calls
local exception_ok, exception_trace = pcall(
  adapter.create,
  project,
  "{10000006-0000-0000-0000-000000000006}",
  "Exception"
)
state_write_hook = nil
assert(exception_ok == false and exception_trace:find("unexpected write failure", 1, true))
assert(exception_writes == 2)
assert(master.state == state_before_mismatch)
assert(calls[calls_before_exception + 1] == "begin")
assert(calls[#calls]:match("^end:HIT: Create Idea Exception:"))

local writes_before_unsafe = #calls
master.state = "2"
local newer_load, newer_load_error = adapter.load(project)
assert(newer_load == nil and newer_load_error == "state_version_unsupported")
local newer, newer_error = adapter.create(project, "{10000006-0000-0000-0000-000000000006}", "Newer")
assert(newer == nil and newer_error == "state_version_unsupported")
assert(#calls == writes_before_unsafe)
master.state = "broken"
local malformed_load, malformed_load_error = adapter.load(project)
assert(malformed_load == nil and malformed_load_error == "state_invalid")
local malformed, malformed_error = adapter.create(project, "{10000006-0000-0000-0000-000000000006}", "Malformed")
assert(malformed == nil and malformed_error == "state_invalid")
assert(#calls == writes_before_unsafe)

master.state = original_state
local failed_restore_writes = 0
state_write_hook = function(track, value)
  failed_restore_writes = failed_restore_writes + 1
  track.state = failed_restore_writes == 1 and (value .. "-mismatch") or "restore-mismatch"
  return true, track.state
end
local restore_failed, restore_error = adapter.create(project, "{10000006-0000-0000-0000-000000000006}", "Restore failure")
state_write_hook = nil
assert(restore_failed == nil and restore_error == "state_restore_failed")
assert(failed_restore_writes == 2)
master.state = state_before_mismatch

local duplicate_record = codec.encode({
  version = 1,
  ideas = {
    { id = "{00000001-0000-0000-0000-000000000001}", name = "Duplicate", source_item_guid = "{10000007-0000-0000-0000-000000000007}" },
  },
})
master.state = duplicate_record .. "|" .. duplicate_record:sub(3)
local duplicate, duplicate_error = adapter.load(project)
assert(duplicate == nil and duplicate_error == "state_invalid")

print("REAPER ideas adapter tests passed")
