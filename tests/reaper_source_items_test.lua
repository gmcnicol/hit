package.path = "src/?.lua;src/?/init.lua;" .. package.path

local project = {}
local track = { name = "Sources", index = 1, hidden = false }
local audio_source = { channels = 2, filename = "/audio.wav", kind = "WAVE" }
local offline_source = { channels = 2, filename = "/offline.wav", kind = "_OFFLINE" }
local audio_take = { name = "Audio", source = audio_source, midi = false, offset = 2, playrate = 1.5 }
local midi_take = { name = "MIDI", midi = true }
local offline_take = { name = "Offline", source = offline_source, midi = false }
local audio = {
  guid = "{10000001-0000-0000-0000-000000000001}",
  track = track,
  take = audio_take,
  name = "Audio item",
  position = 12,
  length = 4,
  selected = false,
}
local midi = {
  guid = "{10000002-0000-0000-0000-000000000002}",
  track = track,
  take = midi_take,
  position = 3,
  length = 2,
  selected = false,
}
local offline = {
  guid = "{10000003-0000-0000-0000-000000000003}",
  track = track,
  take = offline_take,
  position = 20,
  length = 6,
  selected = false,
}
local ambiguous = {
  guid = "{10000004-0000-0000-0000-000000000004}",
  track = track,
  take = audio_take,
  position = 30,
  length = 1,
  selected = false,
}
local ambiguous_copy = {
  guid = ambiguous.guid,
  track = track,
  take = audio_take,
  position = 31,
  length = 1,
  selected = false,
}
local items = { audio, midi, offline, ambiguous, ambiguous_copy }
local selected = {}
local arrange_start = 0
local arrange_end = 10
local arrange_updates = 0

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
  TakeIsMIDI = function(take)
    return take.midi
  end,
  GetMediaItemTake_Source = function(take)
    return take.source
  end,
  GetMediaSourceNumChannels = function(source)
    return source.channels
  end,
  GetMediaSourceType = function(source)
    return source.kind
  end,
  GetMediaSourceFileName = function(source)
    return source.filename
  end,
  file_exists = function(path)
    return path == "/audio.wav"
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
  GetMediaItemTakeInfo_Value = function(take, parameter)
    if parameter == "D_STARTOFFS" then
      return take.offset or 0
    end
    assert(parameter == "D_PLAYRATE")
    return take.playrate or 1
  end,
  GetTrackName = function(current_track)
    return true, current_track.name
  end,
  GetMediaTrackInfo_Value = function(current_track, parameter)
    if parameter == "IP_TRACKNUMBER" then
      return current_track.index
    end
    assert(parameter == "B_SHOWINTCP")
    return current_track.hidden and 0 or 1
  end,
  IsMediaItemSelected = function(item)
    return item.selected
  end,
  format_timestr_pos = function(position)
    return tostring(position)
  end,
  format_timestr_len = function(length)
    return tostring(length)
  end,
  CountMediaItems = function()
    return #items
  end,
  GetMediaItem = function(_, index)
    return items[index + 1]
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
  GetSet_ArrangeView2 = function(_, set, _, _, start_time, end_time)
    if set then
      arrange_start = start_time
      arrange_end = end_time
    end
    return arrange_start, arrange_end
  end,
  UpdateArrange = function()
    arrange_updates = arrange_updates + 1
  end,
}

local source_items = require("hit.reaper.source_items")

local none, none_error = source_items.selected_item(project)
assert(none == nil and none_error == "selection_none")

selected = { audio }
audio.selected = true
local selected_audio = assert(source_items.selected_item(project))
assert(selected_audio.source_item_guid == audio.guid)
assert(selected_audio.suggested_name == "Audio")
assert(selected_audio.source_kind == "audio")

selected = { midi, audio }
midi.selected = true
local selected_sources = assert(source_items.selected_items(project))
assert(selected_sources[1].source_item_guid == midi.guid)
assert(selected_sources[2].source_item_guid == audio.guid)

assert(source_items.find_source(project, audio.guid) == audio)
local missing, missing_error = source_items.find_source(project, "{10000005-0000-0000-0000-000000000005}")
assert(missing == nil and missing_error == "source_missing")
local duplicate, duplicate_error = source_items.find_source(project, ambiguous.guid)
assert(duplicate == nil and duplicate_error == "source_ambiguous")

local current_idea = {
  families = {
    Pickup = { variants = {} },
    Main = {
      variants = {
        { source_item_guid = audio.guid },
        { source_item_guid = offline.guid },
        { source_item_guid = ambiguous.guid },
        { source_item_guid = "{10000005-0000-0000-0000-000000000005}" },
      },
    },
    Turnaround = { variants = {} },
    Ending = { variants = {} },
  },
}
local facts = source_items.source_facts(project, current_idea)
assert(facts[audio.guid].status == "available")
assert(facts[audio.guid].position == 12 and facts[audio.guid].duration == 4)
assert(facts[audio.guid].source_offset == 2 and facts[audio.guid].playrate == 1.5)
assert(facts[offline.guid].status == "unavailable")
assert(facts[ambiguous.guid].status == "ambiguous")
assert(facts["{10000005-0000-0000-0000-000000000005}"].status == "missing")

local topology = source_items.topology(project)
assert(topology[audio.guid].position == 12 and topology[audio.guid].duration == 4)
assert(topology[audio.guid].source_item_guid == audio.guid)

assert(source_items.select_source(project, audio.guid))
assert(#selected == 1 and selected[1] == audio)
assert(arrange_start == 9 and arrange_end == 19)
assert(arrange_updates == 1)

print("REAPER source-item behaviour tests passed")
