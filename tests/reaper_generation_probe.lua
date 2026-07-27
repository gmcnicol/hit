-- Run only through tests/run_reaper_generation_probe.sh.
package.path = "src/?.lua;src/?/init.lua;" .. package.path

local generation = require("hit.reaper.generation")
local grammar = require("hit.model.grammar")
local grammar_codec = require("hit.model.grammar_codec")
local passage = require("hit.suggestions.passage")
local state_codec = require("hit.model.state_codec")
local generate_ui = require("hit.ui.imgui.generate")
local grammar_ui = require("hit.ui.imgui.grammar")

local mode = assert(
  os.getenv("HIT_GENERATION_PROBE_MODE"),
  "HIT_GENERATION_PROBE_MODE must be write or reload; never run this probe in a working project"
)
local run_id = assert(os.getenv("HIT_GENERATION_PROBE_RUN_ID"), "HIT_GENERATION_PROBE_RUN_ID is required")
local audio_path = "/System/Library/Sounds/Glass.aiff"
local output_path = "/tmp/hit-reaper-generation-probe.txt"
local expected_path = "/tmp/hit-reaper-generation-probe.expected"
local project_path = "/tmp/hit-reaper-generation-probe.rpp"

local function track_string(track, parameter)
  local found, value = reaper.GetSetMediaTrackInfo_String(track, parameter, "", false)
  return found and value or nil
end

local function item_string(item, parameter)
  local found, value = reaper.GetSetMediaItemInfo_String(item, parameter, "", false)
  return found and value or nil
end

local function item_guid(item)
  return assert(item_string(item, "GUID"))
end

local function item_chunk(item)
  local ok, chunk = reaper.GetItemStateChunk(item, "", false)
  assert(ok)
  return chunk
end

local function source_file(item)
  local take = assert(reaper.GetActiveTake(item))
  local source = assert(reaper.GetMediaItemTake_Source(take))
  return reaper.GetMediaSourceFileName(source)
end

local function find_item(project, guid)
  for index = 0, reaper.CountMediaItems(project) - 1 do
    local item = reaper.GetMediaItem(project, index)
    if item_guid(item) == guid then
      return item
    end
  end
end

local function find_tracks(project, role)
  local result = {}
  for index = 0, reaper.CountTracks(project) - 1 do
    local track = reaper.GetTrack(project, index)
    if track_string(track, "P_EXT:HIT_ROLE") == role then
      result[#result + 1] = track
    end
  end
  return result
end

local function insert_track(project, name)
  local index = reaper.CountTracks(project)
  reaper.InsertTrackAtIndex(index, true)
  local track = assert(reaper.GetTrack(project, index))
  assert(reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true))
  return track
end

local function audio_item(track, position, length, name)
  local item = assert(reaper.AddMediaItemToTrack(track))
  local take = assert(reaper.AddTakeToMediaItem(item))
  local source = assert(reaper.PCM_Source_CreateFromFile(audio_path))
  reaper.SetMediaItemTake_Source(take, source)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
  assert(reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true))
  return item
end

local function midi_item(track, position, length, name)
  local item = assert(reaper.CreateNewMIDIItemInProj(track, position, position + length, false))
  local take = assert(reaper.GetActiveTake(item))
  local start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, position)
  local end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, position + length * 0.75)
  assert(reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, 0, 60, 100, false))
  assert(reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true))
  return item
end

local function add_variant(family, source, label, name)
  family.variants[#family.variants + 1] = {
    component_id = reaper.genGuid(""),
    source_item_guid = item_guid(source),
    label = label,
    name = name or "",
    intensity = nil,
    grammar_override = nil,
  }
  family.default_component_id = family.default_component_id or family.variants[#family.variants].component_id
end

local function metadata(project, parameter)
  local master = assert(reaper.GetMasterTrack(project))
  local found, value = reaper.GetSetMediaTrackInfo_String(master, parameter, "", false)
  return found and value or nil
end

local function smoke_generate_ui(generation_view)
  package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
  local ImGui = require("imgui")("0.10")
  local context = ImGui.CreateContext("HIT Generation Probe")
  grammar_ui.push_theme(ImGui, context)
  ImGui.SetNextWindowSize(context, 760, 0)
  local visible = ImGui.Begin(
    context,
    "HIT - Generation Probe - Generate###HIT_GENERATION_PROBE",
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  )
  if visible then
    generate_ui.draw(
      ImGui,
      context,
      generation_view,
      {
        target_bars = generation_view.target_bars,
        seed = generation_view.seed,
      },
      false,
      function()
        error("disabled Generate button executed")
      end
    )
    ImGui.End(context)
  end
  grammar_ui.pop_theme(ImGui, context)
end

local function write()
  local project = reaper.EnumProjects(-1)
  assert(reaper.CountTracks(project) == 0, "generation probe requires empty disposable project")

  local pickup_track = insert_track(project, "Pickup Source")
  local main_track = insert_track(project, "Main Source")
  local alt_track = insert_track(project, "Alternative Source")
  local turnaround_track = insert_track(project, "Turnaround Source")
  local ending_track = insert_track(project, "Ending Source")
  local pickup = audio_item(pickup_track, 20, 3, "Pickup")
  local main = midi_item(main_track, 24, 4, "Main")
  local alternative = audio_item(alt_track, 30, 6.5, "Alternative")
  local turnaround = audio_item(turnaround_track, 38, 11, "Long Turnaround")
  local ending = audio_item(ending_track, 51, 5, "Ending")

  reaper.SetMediaTrackInfo_Value(main_track, "D_VOL", 0.73)
  reaper.SetMediaTrackInfo_Value(main_track, "D_PAN", -0.2)
  reaper.SetMediaTrackInfo_Value(main_track, "D_WIDTH", 0.82)
  reaper.SetMediaTrackInfo_Value(main_track, "I_RECARM", 1)
  assert(reaper.TrackFX_AddByName(main_track, "ReaEQ (Cockos)", false, -1) >= 0)

  local idea_id = reaper.genGuid("")
  local v1 = {
    version = 1,
    ideas = {
      { id = idea_id, name = "Generation Probe", source_item_guid = item_guid(main) },
    },
  }
  local v2 = grammar.from_v1(v1)
  local current = v2.ideas[1]
  current.families.Main.grammar.may_repeat = true
  current.families.Main.grammar.may_overlap = true
  current.families.Pickup.grammar.may_overlap = true
  current.families.Turnaround.grammar.may_overlap = true
  add_variant(current.families.Pickup, pickup, "A", "Breath")
  add_variant(current.families.Main, alternative, "B", "Lift")
  add_variant(current.families.Turnaround, turnaround, "A", "Long")
  add_variant(current.families.Ending, ending, "A", "Stop")
  grammar.validate(v2)
  local master = assert(reaper.GetMasterTrack(project))
  assert(reaper.GetSetMediaTrackInfo_String(master, "P_EXT:HIT_STATE_V1", state_codec.encode(v1), true))
  assert(reaper.GetSetMediaTrackInfo_String(master, "P_EXT:HIT_STATE_V2", grammar_codec.encode(v2), true))

  assert(reaper.SetTempoTimeSigMarker(project, -1, 4, -1, -1, 90, 3, 4, false))
  reaper.SetEditCurPos2(project, 1.25, false, false)
  local port = generation.port(project)
  local boundaries = assert(port.measure_boundaries(1.25, 48))
  assert(boundaries[1] == 1.25 and #boundaries == 49 and boundaries[#boundaries] > boundaries[1])

  local loaded = assert(port.load(idea_id))
  local seed
  for candidate = 1, 100 do
    local suggestion = assert(passage.generate({
      palette = loaded.palette,
      measure_boundaries = boundaries,
      seed = candidate,
    }))
    if suggestion.overlap_count > 0 then
      seed = candidate
      break
    end
  end
  assert(seed, "no deterministic overlap seed found")

  local source_chunks = {}
  for _, item in ipairs({ pickup, main, alternative, turnaround, ending }) do
    source_chunks[item_guid(item)] = item_chunk(item)
  end
  local source_midi_ok, source_midi = reaper.MIDI_GetAllEvts(assert(reaper.GetActiveTake(main)), "")
  assert(source_midi_ok)

  local first, first_error = generation.execute(project, idea_id, 48, seed)
  assert(first, first_error)
  assert(#first.builds == 1)
  assert(reaper.Undo_CanUndo2(project) == "HIT: Generate Build 001")
  local roots = find_tracks(project, "generated_root")
  local builds = find_tracks(project, "build")
  local lanes = find_tracks(project, "lane")
  assert(#roots == 1 and #builds == 1 and #lanes == 2)
  assert(reaper.GetMediaTrackInfo_Value(builds[1], "D_VOL") == reaper.GetMediaTrackInfo_Value(main_track, "D_VOL"))
  assert(reaper.GetMediaTrackInfo_Value(builds[1], "D_PAN") == reaper.GetMediaTrackInfo_Value(main_track, "D_PAN"))
  assert(reaper.GetMediaTrackInfo_Value(builds[1], "D_WIDTH") == reaper.GetMediaTrackInfo_Value(main_track, "D_WIDTH"))
  assert(reaper.GetMediaTrackInfo_Value(builds[1], "I_RECARM") == 0)
  assert(reaper.TrackFX_GetCount(builds[1]) == reaper.TrackFX_GetCount(main_track))
  assert(reaper.GetTrackNumSends(builds[1], 0) == 0 and reaper.CountTrackEnvelopes(builds[1]) == 0)

  local generated_midi
  local generated_audio
  local overlap_seen = false
  for _, lane in ipairs(lanes) do
    for item_index = 0, reaper.CountTrackMediaItems(lane) - 1 do
      local item = reaper.GetTrackMediaItem(lane, item_index)
      assert(reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 0)
      assert(reaper.GetMediaItemInfo_Value(item, "C_LOCK") == 0)
      assert(reaper.GetMediaItemInfo_Value(item, "I_GROUPID") == 0)
      assert(not reaper.IsMediaItemSelected(item))
      assert(item_string(item, "P_EXT:HIT_BUILD_ID") == first.builds[1].id)
      assert(item_string(item, "P_EXT:HIT_COMPONENT_ID"))
      assert(item_string(item, "P_EXT:HIT_PHRASE_FAMILY"))
      local source_guid = item_string(item, "P_EXT:HIT_SOURCE_ITEM_GUID")
      if source_guid == item_guid(main) and not generated_midi then
        generated_midi = item
      elseif source_guid ~= item_guid(main) and not generated_audio then
        generated_audio = item
      end
    end
  end
  for _, phrase in ipairs(first.builds[1].sequence) do
    overlap_seen = overlap_seen or phrase.overlap > 0
  end
  assert(generated_midi and generated_audio and overlap_seen)
  assert(item_guid(generated_midi) ~= item_guid(main))
  local generated_audio_source = assert(find_item(project, item_string(generated_audio, "P_EXT:HIT_SOURCE_ITEM_GUID")))
  assert(item_guid(generated_audio) ~= item_guid(generated_audio_source))
  assert(source_file(generated_audio) == source_file(generated_audio_source))
  local source_take_guid =
    assert(({ reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(main), "GUID", "", false) })[2])
  local generated_take_guid =
    assert(({ reaper.GetSetMediaItemTakeInfo_String(reaper.GetActiveTake(generated_midi), "GUID", "", false) })[2])
  assert(source_take_guid ~= generated_take_guid)

  local generated_take = assert(reaper.GetActiveTake(generated_midi))
  assert(reaper.MIDI_SetNote(generated_take, 0, nil, nil, nil, nil, nil, 72, nil, false))
  local source_after_ok, source_after = reaper.MIDI_GetAllEvts(assert(reaper.GetActiveTake(main)), "")
  assert(source_after_ok and source_after == source_midi)
  for source_guid, chunk in pairs(source_chunks) do
    assert(item_chunk(assert(find_item(project, source_guid))) == chunk)
  end

  local v3_after_first = assert(metadata(project, "P_EXT:HIT_STATE_V3"))
  assert(reaper.Undo_DoUndo2(project) ~= 0)
  assert(metadata(project, "P_EXT:HIT_STATE_V3") == nil)
  assert(reaper.Undo_DoRedo2(project) ~= 0)
  assert(metadata(project, "P_EXT:HIT_STATE_V3") == v3_after_first)

  local second = assert(generation.execute(project, idea_id, 48, seed + 1))
  builds = find_tracks(project, "build")
  assert(#second.builds == 2 and #builds == 2)
  assert(reaper.GetMediaTrackInfo_Value(builds[1], "B_MUTE") == 1)
  assert(reaper.GetMediaTrackInfo_Value(builds[2], "B_MUTE") == 0)

  local first_lane_item = assert(reaper.GetTrackMediaItem(find_tracks(project, "lane")[1], 0))
  local manual_position = reaper.GetMediaItemInfo_Value(first_lane_item, "D_POSITION") + 0.375
  reaper.SetMediaItemInfo_Value(first_lane_item, "D_POSITION", manual_position)
  assert(reaper.GetSetMediaTrackInfo_String(builds[1], "P_NAME", "Musician Edit", true))
  local edited_item_guid = item_guid(first_lane_item)
  local third = assert(generation.execute(project, idea_id, 48, seed + 2))
  assert(#third.builds == 3)
  assert(reaper.GetMediaItemInfo_Value(assert(find_item(project, edited_item_guid)), "D_POSITION") == manual_position)

  roots = find_tracks(project, "generated_root")
  reaper.SetMediaTrackInfo_Value(roots[1], "B_MUTE", 1)
  local before_failure_tracks = reaper.CountTracks(project)
  local before_failure_v3 = assert(metadata(project, "P_EXT:HIT_STATE_V3"))
  builds = find_tracks(project, "build")
  local before_failure_mutes = {}
  for index, build in ipairs(builds) do
    before_failure_mutes[index] = reaper.GetMediaTrackInfo_Value(build, "B_MUTE")
  end
  local real_set_chunk = reaper.SetItemStateChunk
  reaper.SetItemStateChunk = function()
    return false
  end
  local failed, failure_error = generation.execute(project, idea_id, 48, seed + 3)
  reaper.SetItemStateChunk = real_set_chunk
  assert(failed == nil and failure_error == "item_copy_failed")
  assert(reaper.CountTracks(project) == before_failure_tracks)
  assert(metadata(project, "P_EXT:HIT_STATE_V3") == before_failure_v3)
  builds = find_tracks(project, "build")
  for index, build in ipairs(builds) do
    assert(reaper.GetMediaTrackInfo_Value(build, "B_MUTE") == before_failure_mutes[index])
  end
  assert(reaper.GetMediaTrackInfo_Value(roots[1], "B_MUTE") == 1)

  reaper.Main_SaveProjectEx(project, project_path, 8)
  local expected = assert(io.open(expected_path, "w"))
  expected:write(run_id, "\n")
  expected:write(idea_id, "\n")
  expected:write(before_failure_v3, "\n")
  expected:write(edited_item_guid, "\n")
  expected:write(string.format("%.17g", manual_position), "\n")
  expected:close()
  local output = assert(io.open(output_path, "w"))
  output:write("saved\t", run_id, "\n")
  output:close()
end

local function reload()
  local expected = assert(io.open(expected_path, "r"))
  assert(expected:read("*l") == run_id, "stale generation probe expectation")
  local idea_id = assert(expected:read("*l"))
  local expected_v3 = assert(expected:read("*l"))
  local edited_item_guid = assert(expected:read("*l"))
  local manual_position = assert(tonumber(expected:read("*l")))
  expected:close()

  local project = reaper.EnumProjects(-1)
  assert(metadata(project, "P_EXT:HIT_STATE_V3") == expected_v3)
  local reopened = generation.open(project, idea_id)
  assert(not reopened.read_only and #reopened.builds == 3)
  smoke_generate_ui(reopened)
  local roots = find_tracks(project, "generated_root")
  local builds = find_tracks(project, "build")
  local lanes = find_tracks(project, "lane")
  assert(#roots == 1 and #builds == 3 and #lanes == 6)
  assert(reaper.GetMediaTrackInfo_Value(roots[1], "B_MUTE") == 1)
  assert(reaper.GetMediaTrackInfo_Value(builds[1], "B_MUTE") == 1)
  assert(reaper.GetMediaTrackInfo_Value(builds[2], "B_MUTE") == 1)
  assert(reaper.GetMediaTrackInfo_Value(builds[3], "B_MUTE") == 0)
  assert(reaper.GetMediaItemInfo_Value(assert(find_item(project, edited_item_guid)), "D_POSITION") == manual_position)
  for _, lane in ipairs(lanes) do
    assert(track_string(lane, "P_EXT:HIT_BUILD_ID"))
    assert(track_string(lane, "P_EXT:HIT_LANE"))
  end

  local output = assert(io.open(output_path, "a"))
  output:write("ui_smoke\t", run_id, "\n")
  output:write("reloaded\t", run_id, "\n")
  output:close()
end

if mode == "write" then
  write()
elseif mode == "reload" then
  reload()
else
  error("unknown HIT_GENERATION_PROBE_MODE")
end
