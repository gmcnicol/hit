package.path = "src/?.lua;src/?/init.lua;" .. package.path

local codec = require("hit.model.state_codec")
local grammar_codec = require("hit.model.grammar_codec")
local project = {}
local track_a = { name = "Guitars", index = 1, hidden = false }
local track_b = {
  name = "Bass",
  index = 2,
  hidden = true,
}
local master = {
  v2_state = "",
  state = codec.encode({
    version = 1,
    ideas = {
      {
        id = "{00000002-0000-0000-0000-000000000002}",
        name = "Available",
        source_item_guid = "{10000002-0000-0000-0000-000000000002}",
      },
      {
        id = "{00000003-0000-0000-0000-000000000003}",
        name = "Moved",
        source_item_guid = "{10000003-0000-0000-0000-000000000003}",
      },
      {
        id = "{00000004-0000-0000-0000-000000000004}",
        name = "Missing",
        source_item_guid = "{10000004-0000-0000-0000-000000000004}",
      },
    },
  }),
}
local source_a = { channels = 2, filename = "/audio.wav" }
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
local project_revision = 1
local arrange_start = 0
local arrange_end = 10
local generated_ids = {
  "{00000001-0000-0000-0000-000000000001}",
  "{00000005-0000-0000-0000-000000000005}",
  "{00000006-0000-0000-0000-000000000006}",
  "{00000007-0000-0000-0000-000000000007}",
  "{00000008-0000-0000-0000-000000000008}",
  "{00000009-0000-0000-0000-000000000009}",
  "{0000000A-0000-0000-0000-00000000000A}",
  "{0000000B-0000-0000-0000-00000000000B}",
  "{0000000C-0000-0000-0000-00000000000C}",
  "{0000000D-0000-0000-0000-00000000000D}",
  "{0000000E-0000-0000-0000-00000000000E}",
  "{0000000F-0000-0000-0000-00000000000F}",
}
local generated_index = 0
local split_ids = {
  "{10000009-0000-0000-0000-000000000009}",
  "{1000000A-0000-0000-0000-00000000000A}",
  "{1000000B-0000-0000-0000-00000000000B}",
  "{1000000C-0000-0000-0000-00000000000C}",
}
local split_index = 0
local state_write_hook
local v2_write_hook

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
  GetMediaItemTakeInfo_Value = function(take, parameter)
    if parameter == "D_STARTOFFS" then
      return take.offset or 0
    end
    assert(parameter == "D_PLAYRATE")
    return take.playrate or 1
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
    if parameter == "P_NOTES" then
      return true, item.name or ""
    end
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
    assert(parameter == "P_EXT:HIT_STATE_V1" or parameter == "P_EXT:HIT_STATE_V2")
    local field = parameter == "P_EXT:HIT_STATE_V1" and "state" or "v2_state"
    if set then
      calls[#calls + 1] = "write"
      if parameter == "P_EXT:HIT_STATE_V1" and state_write_hook then
        return state_write_hook(track, value)
      end
      if parameter == "P_EXT:HIT_STATE_V2" and v2_write_hook then
        return v2_write_hook(track, value)
      end
      track[field] = value
      project_revision = project_revision + 1
      return true, value
    end
    return track[field] ~= "", track[field]
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
  GetItemStateChunk = function(item)
    return true, table.concat({ item.guid, item.position, item.length }, ";")
  end,
  SetItemStateChunk = function(item, chunk)
    local guid, position, length = chunk:match("^([^;]+);([^;]+);([^;]+)$")
    item.guid = guid
    item.position = tonumber(position)
    item.length = tonumber(length)
    return true
  end,
  SplitMediaItem = function(item, position)
    if position <= item.position or position >= item.position + item.length then
      return nil
    end
    split_index = split_index + 1
    local right_take = {}
    for key, value in pairs(item.take) do
      right_take[key] = value
    end
    right_take.offset = (item.take.offset or 0) + (position - item.position) * (item.take.playrate or 1)
    local right = {
      guid = split_ids[split_index],
      track = item.track,
      take = right_take,
      position = position,
      length = item.position + item.length - position,
      selected = false,
    }
    item.length = position - item.position
    items[#items + 1] = right
    project_revision = project_revision + 1
    return right
  end,
  DeleteTrackMediaItem = function(track, target)
    assert(target.track == track)
    for index, item in ipairs(items) do
      if item == target then
        table.remove(items, index)
        return true
      end
    end
    return false
  end,
  ValidatePtr = function(value, kind)
    return value == project and kind == "ReaProject*"
  end,
  EnumProjects = function(index)
    assert(index == -1)
    return project
  end,
  GetProjectStateChangeCount = function()
    return project_revision
  end,
}

local adapter = require("hit.reaper.ideas")
local source_items = require("hit.reaper.source_items")

local no_selection, selection_error = source_items.selected_item(project)
assert(no_selection == nil and selection_error == "selection_none")

selected = { item_a, item_b }
local multiple_selection, multiple_error = source_items.selected_item(project)
assert(multiple_selection == nil and multiple_error == "selection_multiple")

selected = { item_a }
item_a.selected = true
item_a.take = nil
local no_take, take_error = source_items.selected_item(project)
assert(no_take == nil and take_error == "active_take_missing")

item_a.take = take_a
take_a.source = nil
local unavailable, unavailable_error = source_items.selected_item(project)
assert(unavailable == nil and unavailable_error == "source_unsupported")
take_a.source = { channels = 0 }
local unsupported, unsupported_error = source_items.selected_item(project)
assert(unsupported == nil and unsupported_error == "source_unsupported")
take_a.source = source_a
local item_a_guid = item_a.guid
item_a.guid = "invalid"
local invalid_guid, invalid_guid_error = source_items.selected_item(project)
assert(invalid_guid == nil and invalid_guid_error == "source_guid_invalid")
item_a.guid = item_a_guid

local candidate = assert(source_items.selected_item(project))
assert(candidate.source_item_guid == "{10000001-0000-0000-0000-000000000001}")
assert(candidate.suggested_name == "Take A")
assert(candidate.source_kind == "audio")

selected = { item_c }
local midi_candidate = assert(source_items.selected_item(project))
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
assert(table.concat(calls, ",") == "begin,write,write,end:HIT: Create Idea Idea A:-1,dirty")
assert(item_a.guid == before.guid)
assert(item_a.track == before.track)
assert(item_a.take == before.take)
assert(item_a.position == before.position)
assert(item_a.length == before.length)

local persisted = assert(codec.decode(master.state))
assert(#persisted.ideas == 4)
assert(persisted.ideas[4].source_item_guid == "{10000001-0000-0000-0000-000000000001}")
local grammar_persisted = assert(grammar_codec.decode(master.v2_state))
assert(grammar_persisted.ideas[4].families.Main.variants[1].source_item_guid == item_a.guid)

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
assert(source_items.select_source(project, "{10000002-0000-0000-0000-000000000002}"))
assert(#selected == 1 and selected[1] == item_b)
assert(calls[#calls] == "refresh")
assert(reaper.GetCursorPositionEx(project) == before_select.cursor)
assert(track_b.hidden == before_select.hidden)
assert(item_b.position == before_select.position and item_b.length == before_select.length)
assert(arrange_start == 2 and arrange_end == 12)

local missing, missing_error = source_items.select_source(project, "{10000004-0000-0000-0000-000000000004}")
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
local ambiguous, ambiguous_error = source_items.select_source(project, "{10000002-0000-0000-0000-000000000002}")
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
assert(source_items.select_source(project, "{10000002-0000-0000-0000-000000000002}"))
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
local blank_midi = assert(source_items.selected_item(project))
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
local exception_ok, exception_trace =
  pcall(adapter.create, project, "{10000006-0000-0000-0000-000000000006}", "Exception")
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
local restore_failed, restore_error =
  adapter.create(project, "{10000006-0000-0000-0000-000000000006}", "Restore failure")
state_write_hook = nil
assert(restore_failed == nil and restore_error == "state_restore_failed")
assert(failed_restore_writes == 2)
master.state = state_before_mismatch

local duplicate_record = codec.encode({
  version = 1,
  ideas = {
    {
      id = "{00000001-0000-0000-0000-000000000001}",
      name = "Duplicate",
      source_item_guid = "{10000007-0000-0000-0000-000000000007}",
    },
  },
})
master.state = duplicate_record .. "|" .. duplicate_record:sub(3)
local duplicate, duplicate_error = adapter.load(project)
assert(duplicate == nil and duplicate_error == "state_invalid")

master.state = original_state
master.v2_state = ""
local grammar_adapter = require("hit.reaper.grammar")
local grammar_view = assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
assert(grammar_view.version == 2)
assert(grammar_view.families.Main.variants[1].label == "A")
assert(grammar_view.families.Main.variants[1].source.track_name == "Bass")
assert(master.v2_state == "", "opening legacy Idea must not write V2")

selected = { item_a, item_e }
item_a.selected = true
local classified, classify_error, classify_outcome =
  grammar_adapter.execute(project, "{00000002-0000-0000-0000-000000000002}", { type = "bulk_add" })
assert(classified, classify_error)
assert(classify_outcome.added == 2)
assert(#classified.families.Main.variants == 3)
assert(classified.families.Main.variants[2].source_item_guid == item_a.guid)
assert(classified.families.Main.variants[3].source_item_guid == item_e.guid)
assert(master.v2_state:sub(1, 2) == "2|")
assert(master.state == original_state, "V2 mutation must preserve V1")
assert(calls[#calls - 2] == "write")
assert(calls[#calls - 1]:match("^end:HIT: Add Main Variants"))
assert(calls[#calls] == "dirty")

local reopened = assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
assert(reopened.families.Main.variants[2].component_id == classified.families.Main.variants[2].component_id)
assert(reopened.families.Main.variants[3].source_item_guid == item_e.guid)
local original_item_b_length = item_b.length
item_b.length = original_item_b_length + 2
item_b.selected = true
local resized = assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
assert(resized.families.Main.variants[1].source.duration == item_b.length)
assert(resized.families.Main.variants[1].source.selected)
item_b.length = original_item_b_length

edit_cursor = 7
local original_component = reopened.families.Main.variants[1].component_id
local split_view, split_error = grammar_adapter.execute(
  project,
  "{00000002-0000-0000-0000-000000000002}",
  { type = "split", component_id = original_component }
)
assert(split_view, split_error)
assert(item_b.length == 4)
local right_item = assert(items[#items])
assert(right_item.guid == split_ids[1] and right_item.position == 7 and right_item.length == 4)
assert(split_view.families.Main.variants[1].component_id == original_component)
assert(split_view.families.Main.variants[1].source_item_guid == item_b.guid)
assert(split_view.families.Main.variants[4].source_item_guid == right_item.guid)
assert(calls[#calls - 2]:match("^end:HIT: Split Variant"))
assert(calls[#calls - 1] == "dirty" and calls[#calls] == "refresh")

local split_saved_v2 = master.v2_state
local item_count_before_failed_split = #items
local item_a_length = item_a.length
edit_cursor = item_a.position + item_a.length / 2
local failed_split_writes = 0
v2_write_hook = function(track, value)
  failed_split_writes = failed_split_writes + 1
  track.v2_state = failed_split_writes == 1 and value .. "-mismatch" or value
  return true, track.v2_state
end
local failed_split, failed_split_error = grammar_adapter.execute(project, "{00000002-0000-0000-0000-000000000002}", {
  type = "split",
  component_id = split_view.families.Main.variants[2].component_id,
})
v2_write_hook = nil
assert(failed_split == nil and failed_split_error == "state_write_failed")
assert(#items == item_count_before_failed_split)
assert(item_a.length == item_a_length)
assert(master.v2_state == split_saved_v2)

local v2_writes = 0
v2_write_hook = function(track, value)
  v2_writes = v2_writes + 1
  track.v2_state = v2_writes == 1 and value .. "-mismatch" or value
  return true, track.v2_state
end
local failed_classification, failed_classification_error =
  grammar_adapter.execute(project, "{00000002-0000-0000-0000-000000000002}", {
    type = "set_intensity",
    component_id = reopened.families.Main.variants[1].component_id,
    intensity = 5,
  })
v2_write_hook = nil
assert(failed_classification == nil and failed_classification_error == "state_write_failed")
assert(master.v2_state == split_saved_v2)

assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
local before_ordinary_split_state = master.v2_state
local ordinary_right = assert(reaper.SplitMediaItem(item_a, item_a.position + item_a.length / 2))
assert(master.v2_state == before_ordinary_split_state)
local with_recovery = assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
assert(#with_recovery.recovery == 1)
local recovery = with_recovery.recovery[1]
assert(recovery.origin_source_item_guid == item_a.guid)
assert(recovery.source_item_guid == ordinary_right.guid)
assert(recovery.family == "Main")
local attached, attach_error = grammar_adapter.execute(
  project,
  "{00000002-0000-0000-0000-000000000002}",
  { type = "attach_recovery", fingerprint = recovery.fingerprint }
)
assert(attached, attach_error)
assert(#attached.recovery == 0)
local attached_found = false
for _, variant in ipairs(attached.families.Main.variants) do
  attached_found = attached_found or variant.source_item_guid == ordinary_right.guid
end
assert(attached_found)

assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
local dismiss_right = assert(reaper.SplitMediaItem(item_b, item_b.position + item_b.length / 2))
local dismiss_view = assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
assert(#dismiss_view.recovery == 1)
assert(dismiss_view.recovery[1].source_item_guid == dismiss_right.guid)
local dismissed, dismiss_error = grammar_adapter.execute(project, "{00000002-0000-0000-0000-000000000002}", {
  type = "dismiss_recovery",
  fingerprint = dismiss_view.recovery[1].fingerprint,
})
assert(dismissed, dismiss_error)
assert(#dismissed.recovery == 0)
assert(#dismissed.dismissed_recoveries == 1)
assert(#assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}")).recovery == 0)

master.v2_state = "3|future"
local newer_grammar = assert(grammar_adapter.open(project, "{00000002-0000-0000-0000-000000000002}"))
assert(newer_grammar.read_only and newer_grammar.error == "state_version_unsupported")
master.v2_state = split_saved_v2

print("REAPER ideas adapter tests passed")
