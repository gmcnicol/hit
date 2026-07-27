package.path = "src/?.lua;src/?/init.lua;" .. package.path

local grammar = require("hit.model.grammar")
local grammar_codec = require("hit.model.grammar_codec")
local state_codec = require("hit.model.state_codec")
local v3_codec = require("hit.model.v3_codec")

local IDEA_ID = "{00000001-0000-0000-0000-000000000001}"
local SOURCE_PICKUP = "{10000001-0000-0000-0000-000000000001}"
local SOURCE_MAIN = "{10000002-0000-0000-0000-000000000002}"
local SOURCE_ALT = "{10000003-0000-0000-0000-000000000003}"
local SOURCE_TURN = "{10000004-0000-0000-0000-000000000004}"
local SOURCE_END = "{10000005-0000-0000-0000-000000000005}"
local SOURCE_GONE = "{10000006-0000-0000-0000-000000000006}"
local SOURCE_AMBIGUOUS = "{10000007-0000-0000-0000-000000000007}"

local function component(index)
  return string.format("{200000%02X-0000-0000-0000-000000000000}", index)
end

local v1 = {
  version = 1,
  ideas = {
    { id = IDEA_ID, name = "Mixed passage", source_item_guid = SOURCE_MAIN },
  },
}
local v2 = grammar.from_v1(v1)
local idea = v2.ideas[1]
idea.families.Main.grammar.may_repeat = true
idea.families.Main.grammar.may_overlap = true
idea.families.Pickup.grammar.may_overlap = true
idea.families.Turnaround.grammar.may_overlap = true
idea.families.Pickup.variants[1] = {
  component_id = component(1),
  source_item_guid = SOURCE_PICKUP,
  label = "A",
  name = "Breath",
}
idea.families.Pickup.default_component_id = component(1)
idea.families.Main.variants[2] = {
  component_id = component(2),
  source_item_guid = SOURCE_ALT,
  label = "B",
  name = "Lift",
}
idea.families.Main.variants[3] = {
  component_id = component(3),
  source_item_guid = SOURCE_GONE,
  label = "C",
  name = "",
}
idea.families.Main.variants[4] = {
  component_id = component(4),
  source_item_guid = SOURCE_AMBIGUOUS,
  label = "D",
  name = "",
}
idea.families.Turnaround.variants[1] = {
  component_id = component(5),
  source_item_guid = SOURCE_TURN,
  label = "A",
  name = "",
}
idea.families.Turnaround.default_component_id = component(5)
idea.families.Ending.variants[1] = {
  component_id = component(6),
  source_item_guid = SOURCE_END,
  label = "A",
  name = "Stop",
}
idea.families.Ending.default_component_id = component(6)
grammar.validate(v2)

local guid_counter = 256
local function guid()
  guid_counter = guid_counter + 1
  return string.format("{%08X-0000-0000-0000-000000000000}", guid_counter)
end

local function values(overrides)
  local result = {
    I_FOLDERDEPTH = 0,
    B_MUTE = 0,
    D_VOL = 1,
    D_PAN = 0,
    D_WIDTH = 1,
    I_RECARM = 0,
  }
  for key, value in pairs(overrides or {}) do
    result[key] = value
  end
  return result
end

local project = {
  active = true,
  cursor = 2,
  tracks = {},
  master = { strings = {} },
  facts = {},
  sources = {},
  undo_count = 0,
  redo_count = 0,
  dirty = 0,
  arrange_updates = 0,
}

local function track(name, track_values, fx)
  local result = {
    strings = { P_NAME = name },
    values = values(track_values),
    fx = fx or {},
    items = {},
  }
  project.tracks[#project.tracks + 1] = result
  return result
end

local function source(track_value, source_guid, duration, kind)
  local chunk
  if kind == "MIDI" then
    chunk = table.concat({
      "<ITEM",
      "POSITION 10",
      "LENGTH " .. duration,
      "GUID " .. source_guid,
      "<TAKE",
      "GUID " .. guid(),
      "<SOURCE MIDI",
      "POOLEDEVTS {AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA}",
      "E 0 90 3c 64",
      ">",
      ">",
      ">",
    }, "\n")
  else
    chunk = table.concat({
      "<ITEM",
      "POSITION 10",
      "LENGTH " .. duration,
      "GUID " .. source_guid,
      "<TAKE",
      "GUID " .. guid(),
      "<SOURCE WAVE",
      'FILE "source.wav"',
      ">",
      ">",
      ">",
    }, "\n")
  end
  local item = {
    guid = source_guid,
    track = track_value,
    chunk = chunk,
    strings = {},
    values = {
      D_POSITION = 10,
      D_LENGTH = duration,
      B_MUTE = 1,
      C_LOCK = 1,
      I_GROUPID = 42,
      B_UISEL = 1,
    },
    selected = true,
    take = { strings = { P_NAME = "Original" } },
  }
  track_value.items[#track_value.items + 1] = item
  project.sources[source_guid] = { item }
  return item
end

local pickup_track = track("Pickup source")
local main_track = track("Main source", {
  D_VOL = 0.7,
  D_PAN = -0.25,
  D_WIDTH = 0.8,
  I_RECARM = 1,
  I_FOLDERDEPTH = 1,
}, { "Compressor", "Delay" })
local alt_track = track("Alt source", { D_VOL = 0.5 }, { "Wrong FX" })
local turn_track = track("Turn source")
local end_track = track("End source")
local ambiguous_track = track("Ambiguous")

local source_by_guid = {
  [SOURCE_PICKUP] = source(pickup_track, SOURCE_PICKUP, 3, "AUDIO"),
  [SOURCE_MAIN] = source(main_track, SOURCE_MAIN, 4, "MIDI"),
  [SOURCE_ALT] = source(alt_track, SOURCE_ALT, 6, "AUDIO"),
  [SOURCE_TURN] = source(turn_track, SOURCE_TURN, 8, "AUDIO"),
  [SOURCE_END] = source(end_track, SOURCE_END, 5, "AUDIO"),
}
project.sources[SOURCE_AMBIGUOUS] = {
  source(ambiguous_track, SOURCE_AMBIGUOUS, 2, "AUDIO"),
  source(ambiguous_track, SOURCE_AMBIGUOUS, 2, "AUDIO"),
}

for source_guid, item in pairs(source_by_guid) do
  project.facts[source_guid] = {
    status = source_guid == SOURCE_MAIN and "unavailable" or "available",
    duration = item.values.D_LENGTH,
  }
end
project.facts[SOURCE_GONE] = { status = "missing" }
project.facts[SOURCE_AMBIGUOUS] = { status = "ambiguous" }

local v1_bytes = state_codec.encode(v1)
local v2_bytes = grammar_codec.encode(v2)
project.master.strings["P_EXT:HIT_STATE_V1"] = v1_bytes
project.master.strings["P_EXT:HIT_STATE_V2"] = v2_bytes

local function index_of(wanted)
  for index, current in ipairs(project.tracks) do
    if current == wanted then
      return index
    end
  end
end

local function capture()
  local track_values = {}
  for _, current in ipairs(project.tracks) do
    track_values[current] = {}
    for key, value in pairs(current.values) do
      track_values[current][key] = value
    end
  end
  local tracks = {}
  for index, current in ipairs(project.tracks) do
    tracks[index] = current
  end
  return {
    tracks = tracks,
    track_values = track_values,
    v3 = project.master.strings["P_EXT:HIT_STATE_V3"],
  }
end

local function restore(snapshot)
  project.tracks = {}
  for index, current in ipairs(snapshot.tracks) do
    project.tracks[index] = current
    current.values = {}
    for key, value in pairs(snapshot.track_values[current]) do
      current.values[key] = value
    end
  end
  project.master.strings["P_EXT:HIT_STATE_V3"] = snapshot.v3
end

reaper = {
  GetMasterTrack = function()
    return project.master
  end,
  GetSetMediaTrackInfo_String = function(target, parameter, value, set)
    if set then
      target.strings[parameter] = value ~= "" and value or nil
      return true, value
    end
    local current = target.strings[parameter]
    return current ~= nil, current or ""
  end,
  GetSetMediaItemInfo_String = function(item, parameter, value, set)
    if set then
      item.strings[parameter] = value
      return true, value
    end
    local current = parameter == "GUID" and item.guid or item.strings[parameter]
    return current ~= nil, current or ""
  end,
  GetSetMediaItemTakeInfo_String = function(take, parameter, value, set)
    if set then
      take.strings[parameter] = value
      return true, value
    end
    return take.strings[parameter] ~= nil, take.strings[parameter] or ""
  end,
  ValidatePtr = function(candidate)
    return candidate == project
  end,
  EnumProjects = function()
    return project.active and project or {}
  end,
  CountTracks = function()
    return #project.tracks
  end,
  GetTrack = function(_, index)
    return project.tracks[index + 1]
  end,
  InsertTrackAtIndex = function(index)
    local created = { strings = {}, values = values(), fx = {}, items = {} }
    table.insert(project.tracks, index + 1, created)
  end,
  DeleteTrack = function(wanted)
    local index = index_of(wanted)
    if index then
      table.remove(project.tracks, index)
    end
  end,
  GetMediaTrackInfo_Value = function(target, parameter)
    if parameter == "IP_TRACKNUMBER" then
      return assert(index_of(target))
    end
    return target.values[parameter] or 0
  end,
  SetMediaTrackInfo_Value = function(target, parameter, value)
    target.values[parameter] = value
    return true
  end,
  TrackFX_GetCount = function(target)
    return #target.fx
  end,
  TrackFX_CopyToTrack = function(source_track, index, destination)
    destination.fx[#destination.fx + 1] = source_track.fx[index + 1]
  end,
  GetItemStateChunk = function(item)
    return true, item.chunk
  end,
  AddMediaItemToTrack = function(destination)
    local item = {
      guid = guid(),
      track = destination,
      chunk = "",
      strings = {},
      values = values(),
      selected = false,
      take = { strings = {} },
    }
    destination.items[#destination.items + 1] = item
    return item
  end,
  SetItemStateChunk = function(item, chunk)
    if project.fail_item_copy then
      return false
    end
    item.chunk = chunk
    item.guid = chunk:match("\nGUID%s+({[%x%-]+})") or item.guid
    return true
  end,
  SetMediaItemInfo_Value = function(item, parameter, value)
    item.values[parameter] = value
    return true
  end,
  SetMediaItemSelected = function(item, selected)
    item.selected = selected
  end,
  ColorToNative = function(red, green, blue)
    return red | (green << 8) | (blue << 16)
  end,
  GetActiveTake = function(item)
    return item.take
  end,
  GetMediaItem_Track = function(item)
    return item.track
  end,
  GetCursorPositionEx = function()
    return project.cursor
  end,
  TimeMap2_timeToBeats = function(_, time)
    local lengths = { 4, 4, 3, 3, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 }
    local start = 0
    for measure, length in ipairs(lengths) do
      if time < start + length then
        return time - start, measure - 1, length
      end
      start = start + length
    end
    local measure = #lengths + math.floor((time - start) / 4)
    return (time - start) % 4, measure, 4
  end,
  TimeMap2_beatsToTime = function(_, beat, wanted_measure)
    local lengths = { 4, 4, 3, 3, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 }
    local start = 0
    for measure = 1, wanted_measure do
      start = start + (lengths[measure] or 4)
    end
    return start + beat
  end,
  genGuid = function()
    return guid()
  end,
  Undo_BeginBlock2 = function()
    project.undo_before = capture()
  end,
  Undo_EndBlock2 = function(_, label)
    project.undo_after = capture()
    project.undo_label = label
    project.undo_count = project.undo_count + 1
  end,
  Undo_DoUndo2 = function()
    restore(project.undo_before)
    project.redo_count = project.redo_count + 1
    return 1
  end,
  Undo_DoRedo2 = function()
    restore(project.undo_after)
    return 1
  end,
  MarkProjectDirty = function()
    project.dirty = project.dirty + 1
  end,
  UpdateArrange = function()
    project.arrange_updates = project.arrange_updates + 1
  end,
}

package.loaded["hit.reaper.source_items"] = {
  source_facts = function()
    return project.facts
  end,
  find_source = function(_, source_guid)
    local matches = project.sources[source_guid] or {}
    if #matches == 0 then
      return nil, "source_missing"
    end
    if #matches > 1 then
      return nil, "source_ambiguous"
    end
    return matches[1]
  end,
}

local adapter = require("hit.reaper.generation")
local loaded = adapter.open(project, IDEA_ID)
assert(loaded.classified and loaded.source_summary.present == 5)
assert(loaded.source_summary.offline == 1 and loaded.source_summary.gone == 1 and loaded.source_summary.ambiguous == 1)

local source_chunks = {}
for source_guid, item in pairs(source_by_guid) do
  source_chunks[source_guid] = item.chunk
end

local generated = assert(adapter.execute(project, IDEA_ID, 12, 7))
assert(#generated.builds == 1)
assert(project.master.strings["P_EXT:HIT_STATE_V1"] == v1_bytes)
assert(project.master.strings["P_EXT:HIT_STATE_V2"] == v2_bytes)
assert(project.undo_count == 1 and project.undo_label == "HIT: Generate Build 001")
assert(#project.tracks == 10)

local root = project.tracks[7]
local build_one = project.tracks[8]
local lane_a = project.tracks[9]
local lane_b = project.tracks[10]
assert(root.strings["P_EXT:HIT_ROLE"] == "generated_root")
assert(build_one.strings["P_EXT:HIT_ROLE"] == "build")
assert(lane_a.strings["P_EXT:HIT_LANE"] == "A" and lane_b.strings["P_EXT:HIT_LANE"] == "B")
assert(build_one.values.I_FOLDERDEPTH == 1 and lane_a.values.I_FOLDERDEPTH == 0 and lane_b.values.I_FOLDERDEPTH == -2)
assert(build_one.values.D_VOL == main_track.values.D_VOL)
assert(build_one.values.D_PAN == main_track.values.D_PAN)
assert(build_one.values.D_WIDTH == main_track.values.D_WIDTH)
assert(build_one.values.I_RECARM == 0 and build_one.values.I_FOLDERDEPTH == 1)
assert(#build_one.fx == 2 and build_one.fx[1] == "Compressor" and build_one.fx[2] == "Delay")

local item_count = 0
local saw_midi
for _, lane in ipairs({ lane_a, lane_b }) do
  for _, item in ipairs(lane.items) do
    item_count = item_count + 1
    assert(item.values.B_MUTE == 0 and item.values.C_LOCK == 0 and item.values.I_GROUPID == 0)
    assert(not item.selected)
    assert(item.strings["P_EXT:HIT_ROLE"] == "generated_phrase")
    assert(item.strings["P_EXT:HIT_BUILD_ID"] == generated.builds[1].id)
    assert(item.strings["P_EXT:HIT_COMPONENT_ID"] ~= nil)
    assert(item.strings["P_EXT:HIT_PHRASE_FAMILY"] ~= nil)
    assert(item.strings.P_NOTES:find(" - ", 1, true))
    assert(item.take.strings.P_NAME == item.strings.P_NOTES)
    if item.strings["P_EXT:HIT_SOURCE_ITEM_GUID"] == SOURCE_MAIN then
      saw_midi = true
      assert(item.chunk:find("POOLEDEVTS", 1, true))
      assert(not item.chunk:find("{AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA}", 1, true))
    end
  end
end
assert(item_count == #generated.builds[1].sequence and saw_midi)
for source_guid, item in pairs(source_by_guid) do
  assert(item.chunk == source_chunks[source_guid])
  assert(item.values.B_MUTE == 1 and item.values.C_LOCK == 1 and item.values.I_GROUPID == 42)
end

local v3_bytes = project.master.strings["P_EXT:HIT_STATE_V3"]
local persisted = assert(v3_codec.decode(v3_bytes))
assert(persisted.compositions[1].builds[1].sequence[1].component_id == generated.builds[1].sequence[1].component_id)
assert(persisted.compositions[1].anchor == 2)
assert(persisted.compositions[1].builds[1].target_bars == 12)

reaper.Undo_DoUndo2(project)
assert(#project.tracks == 6 and project.master.strings["P_EXT:HIT_STATE_V3"] == nil)
reaper.Undo_DoRedo2(project)
assert(#project.tracks == 10 and project.master.strings["P_EXT:HIT_STATE_V3"] == v3_bytes)

root.values.B_MUTE = 1
build_one.strings.P_NAME = "Musician renamed this"
local second = assert(adapter.execute(project, IDEA_ID, 10, 8))
assert(#second.builds == 2)
assert(root.values.B_MUTE == 1 and build_one.values.B_MUTE == 1)
assert(#project.tracks == 13)
local build_two = project.tracks[11]
assert(build_two.values.B_MUTE == 0)
assert(lane_b.values.I_FOLDERDEPTH == -1 and project.tracks[13].values.I_FOLDERDEPTH == -2)

table.remove(project.tracks, index_of(build_one))
table.remove(project.tracks, index_of(lane_a))
table.remove(project.tracks, index_of(lane_b))
table.insert(project.tracks, 1, lane_b)
table.insert(project.tracks, 1, lane_a)
table.insert(project.tracks, 1, build_one)
build_one.values.B_MUTE = 0
local third = assert(adapter.execute(project, IDEA_ID, 9, 9))
assert(#third.builds == 3)
assert(build_one.values.B_MUTE == 0)
assert(build_two.values.B_MUTE == 1)

local tracks_before_failure = #project.tracks
local v3_before_failure = project.master.strings["P_EXT:HIT_STATE_V3"]
local build_two_mute = build_two.values.B_MUTE
project.fail_item_copy = true
local failed, failure_error = adapter.execute(project, IDEA_ID, 8, 10)
project.fail_item_copy = false
assert(failed == nil and failure_error == "item_copy_failed")
assert(#project.tracks == tracks_before_failure)
assert(project.master.strings["P_EXT:HIT_STATE_V3"] == v3_before_failure)
assert(build_two.values.B_MUTE == build_two_mute)
for source_guid, item in pairs(source_by_guid) do
  assert(item.chunk == source_chunks[source_guid])
end

reaper.DeleteTrack(lane_b)
reaper.DeleteTrack(lane_a)
reaper.DeleteTrack(build_one)
local surviving = adapter.open(project, IDEA_ID)
assert(#surviving.builds == 2)
assert(surviving.builds[1].number == 2 and surviving.builds[2].number == 3)

local no_main_v2 = assert(grammar_codec.decode(v2_bytes))
no_main_v2.ideas[1].families.Pickup.grammar.may_end = true
no_main_v2.ideas[1].families.Pickup.grammar.allowed_next = {}
project.master.strings["P_EXT:HIT_STATE_V2"] = grammar_codec.encode(no_main_v2)
project.facts[SOURCE_MAIN] = { status = "missing" }
project.facts[SOURCE_ALT] = { status = "missing" }
local without_main = adapter.open(project, IDEA_ID)
assert(not without_main.classified and without_main.generatable)
local fallback = assert(adapter.execute(project, IDEA_ID, 4, 11))
assert(fallback.builds[#fallback.builds].sequence[1].family == "Pickup")
local fallback_tracks = {}
for _, current in ipairs(project.tracks) do
  if
    current.strings["P_EXT:HIT_BUILD_ID"] == fallback.builds[#fallback.builds].id
    and current.strings["P_EXT:HIT_ROLE"] == "build"
  then
    fallback_tracks[#fallback_tracks + 1] = current
  end
end
assert(#fallback_tracks == 1)
assert(fallback_tracks[1].values.D_VOL == pickup_track.values.D_VOL)
assert(#fallback_tracks[1].fx == #pickup_track.fx)

print("REAPER generation adapter tests passed")
