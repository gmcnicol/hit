package.path = "src/?.lua;src/?/init.lua;" .. package.path

local codec = require("hit.model.state_codec")
local project = {}
local track_a = { state = "" }
local track_b = {
  state = codec.encode({
    version = 1,
    ideas = {
      { id = "{IDEA-B}", name = "Available", source_item_guid = "{ITEM-B}" },
      { id = "{IDEA-C}", name = "Moved", source_item_guid = "{ITEM-C}" },
      { id = "{IDEA-D}", name = "Missing", source_item_guid = "{ITEM-D}" },
    },
  }),
}
local source_a = { channels = 2 }
local take_a = { name = "Take A", source = source_a, midi = false }
local item_a = { guid = "{ITEM-A}", track = track_a, take = take_a, position = 12, length = 4 }
local item_b = { guid = "{ITEM-B}", track = track_b, take = take_a }
local item_c = { guid = "{ITEM-C}", track = track_a, take = take_a }
local tracks = { track_a, track_b }
local items = { item_a, item_b, item_c }
local selected = {}
local calls = {}

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
    return source.channels
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
  CountTracks = function()
    return #tracks
  end,
  GetTrack = function(_, index)
    return tracks[index + 1]
  end,
  GetSetMediaTrackInfo_String = function(track, parameter, value, set)
    assert(parameter == "P_EXT:HIT_STATE_V1")
    if set then
      calls[#calls + 1] = "write"
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
    return "{IDEA-A}"
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
}

local adapter = require("hit.reaper.ideas")

local no_selection, selection_error = adapter.selected_audio(project)
assert(no_selection == nil and selection_error == "selection_count")

selected = { item_a }
item_a.take = nil
local no_take, take_error = adapter.selected_audio(project)
assert(no_take == nil and take_error == "active_take_missing")

item_a.take = take_a
take_a.midi = true
local midi, midi_error = adapter.selected_audio(project)
assert(midi == nil and midi_error == "audio_required")
take_a.midi = false

local candidate = assert(adapter.selected_audio(project))
assert(candidate.source_item_guid == "{ITEM-A}")
assert(candidate.suggested_name == "Take A")

local before = {
  guid = item_a.guid,
  track = item_a.track,
  take = item_a.take,
  position = item_a.position,
  length = item_a.length,
}
local created = assert(adapter.create(project, "{ITEM-A}", "  Idea A  "))
assert(created.id == "{IDEA-A}" and created.name == "Idea A")
assert(table.concat(calls, ",") == "begin,write,dirty,end:HIT: Create Idea Idea A:-1")
assert(item_a.guid == before.guid)
assert(item_a.track == before.track)
assert(item_a.take == before.take)
assert(item_a.position == before.position)
assert(item_a.length == before.length)

local persisted = assert(codec.decode(track_a.state))
assert(#persisted.ideas == 1)
assert(persisted.ideas[1].source_item_guid == "{ITEM-A}")

local view = assert(adapter.load(project))
local statuses = {}
for _, current in ipairs(view.ideas) do
  statuses[current.id] = current.source_status
end
assert(statuses["{IDEA-A}"] == "available")
assert(statuses["{IDEA-B}"] == "available")
assert(statuses["{IDEA-C}"] == "moved")
assert(statuses["{IDEA-D}"] == "missing")

track_b.state = codec.encode({
  version = 1,
  ideas = {
    { id = "{IDEA-A}", name = "Duplicate", source_item_guid = "{OTHER-ITEM}" },
  },
})
local duplicate, duplicate_error = adapter.load(project)
assert(duplicate == nil and duplicate_error == "state_invalid")

print("REAPER ideas adapter tests passed")
