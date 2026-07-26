local app = reaper
local generation = require("hit.app.generation")
local grammar = require("hit.model.grammar")
local grammar_codec = require("hit.model.grammar_codec")
local state_codec = require("hit.model.state_codec")
local v3_codec = require("hit.model.v3_codec")
local source_items = require("hit.reaper.source_items")

local adapter = {}

local V1_PARAMETER = "P_EXT:HIT_STATE_V1"
local V2_PARAMETER = "P_EXT:HIT_STATE_V2"
local V3_PARAMETER = "P_EXT:HIT_STATE_V3"
local ROLE_PARAMETER = "P_EXT:HIT_ROLE"
local ROOT_ID_PARAMETER = "P_EXT:HIT_ROOT_ID"
local COMPOSITION_ID_PARAMETER = "P_EXT:HIT_COMPOSITION_ID"
local BUILD_ID_PARAMETER = "P_EXT:HIT_BUILD_ID"
local SUGGESTION_ID_PARAMETER = "P_EXT:HIT_SUGGESTION_ID"
local LANE_PARAMETER = "P_EXT:HIT_LANE"
local COMPONENT_ID_PARAMETER = "P_EXT:HIT_COMPONENT_ID"
local FAMILY_PARAMETER = "P_EXT:HIT_PHRASE_FAMILY"
local SOURCE_ID_PARAMETER = "P_EXT:HIT_SOURCE_ITEM_GUID"

local FAMILY_COLOUR = {
  Pickup = { 230, 126, 34 },
  Main = { 46, 204, 113 },
  Turnaround = { 52, 152, 219 },
  Ending = { 155, 89, 182 },
}

local function read_track_string(track, parameter)
  local found, value = app.GetSetMediaTrackInfo_String(track, parameter, "", false)
  return found and value or nil
end

local function write_track_string(track, parameter, value)
  return app.GetSetMediaTrackInfo_String(track, parameter, value, true)
end

local function write_item_string(item, parameter, value)
  return app.GetSetMediaItemInfo_String(item, parameter, value, true)
end

local function project_is_active(project)
  return app.ValidatePtr(project, "ReaProject*") and app.EnumProjects(-1) == project
end

local function exact_source(project, source_item_guid)
  return source_items.find_source(project, source_item_guid)
end

local function palette_for(project, current_idea)
  local facts = source_items.source_facts(project, current_idea)
  local palette = {}
  local summary = { present = 0, gone = 0, ambiguous = 0, offline = 0 }
  for _, family_name in ipairs(grammar.FAMILY_ORDER) do
    local family = current_idea.families[family_name]
    for _, variant in ipairs(family.variants) do
      local source = facts[variant.source_item_guid] or { status = "missing" }
      if source.status == "missing" then
        summary.gone = summary.gone + 1
      elseif source.status == "ambiguous" then
        summary.ambiguous = summary.ambiguous + 1
      else
        summary.present = summary.present + 1
        if source.status == "unavailable" then
          summary.offline = summary.offline + 1
        end
        palette[#palette + 1] = {
          component_id = variant.component_id,
          source_item_guid = variant.source_item_guid,
          family = family_name,
          label = variant.label,
          name = variant.name,
          intensity = variant.intensity,
          default = family.default_component_id == variant.component_id,
          duration = source.duration,
          family_grammar = family.grammar,
          grammar_override = variant.grammar_override,
        }
      end
    end
  end
  return palette, summary
end

local function track_index(project, wanted)
  for index = 0, app.CountTracks(project) - 1 do
    if app.GetTrack(project, index) == wanted then
      return index
    end
  end
end

local function find_root(project, root_id)
  for index = 0, app.CountTracks(project) - 1 do
    local track = app.GetTrack(project, index)
    if
      read_track_string(track, ROLE_PARAMETER) == "generated_root"
      and read_track_string(track, ROOT_ID_PARAMETER) == root_id
    then
      return track, index
    end
  end
end

local function surviving_build_ids(project, state, idea_id)
  local known = {}
  for _, composition in ipairs(state.compositions) do
    if composition.idea_id == idea_id then
      for _, build in ipairs(composition.builds) do
        known[build.id] = true
      end
      break
    end
  end
  local surviving = {}
  for index = 0, app.CountTracks(project) - 1 do
    local track = app.GetTrack(project, index)
    if read_track_string(track, ROLE_PARAMETER) == "build" then
      local build_id = read_track_string(track, BUILD_ID_PARAMETER)
      if known[build_id] then
        surviving[build_id] = true
      end
    end
  end
  return surviving
end

local function root_contents(project, root, root_index, root_id)
  local managed_builds = {}
  local level = app.GetMediaTrackInfo_Value(root, "I_FOLDERDEPTH")
  if level <= 0 then
    return managed_builds, nil
  end
  local closing
  for index = root_index + 1, app.CountTracks(project) - 1 do
    local track = app.GetTrack(project, index)
    if
      level == 1
      and read_track_string(track, ROLE_PARAMETER) == "build"
      and read_track_string(track, ROOT_ID_PARAMETER) == root_id
    then
      managed_builds[#managed_builds + 1] = track
    end
    level = level + app.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    closing = track
    if level <= 0 then
      break
    end
  end
  return managed_builds, closing
end

local function insert_track(project, index, created_tracks)
  app.InsertTrackAtIndex(index, false)
  local track = app.GetTrack(project, index)
  if not track then
    return nil, "track_create_failed"
  end
  app.SetMediaTrackInfo_Value(track, "D_VOL", 1)
  app.SetMediaTrackInfo_Value(track, "D_PAN", 0)
  app.SetMediaTrackInfo_Value(track, "D_WIDTH", 1)
  app.SetMediaTrackInfo_Value(track, "I_RECARM", 0)
  app.SetMediaTrackInfo_Value(track, "B_MUTE", 0)
  created_tracks[#created_tracks + 1] = track
  return track
end

local function name_track(track, name)
  return write_track_string(track, "P_NAME", name)
end

local function tag_track(track, values)
  for parameter, value in pairs(values) do
    if not write_track_string(track, parameter, value) then
      return nil, "metadata_write_failed"
    end
  end
  return true
end

local function create_root(project, root_id, created_tracks)
  local index = app.CountTracks(project)
  local root, create_error = insert_track(project, index, created_tracks)
  if not root then
    return nil, nil, create_error
  end
  if not name_track(root, "GENERATED DEMO") then
    return nil, nil, "track_name_failed"
  end
  local tagged, tag_error = tag_track(root, {
    [ROLE_PARAMETER] = "generated_root",
    [ROOT_ID_PARAMETER] = root_id,
  })
  if not tagged then
    return nil, nil, tag_error
  end
  app.SetMediaTrackInfo_Value(root, "I_FOLDERDEPTH", 1)
  return root, index
end

local function copy_processing(source_track, destination)
  for _, parameter in ipairs({ "D_VOL", "D_PAN", "D_WIDTH" }) do
    app.SetMediaTrackInfo_Value(destination, parameter, app.GetMediaTrackInfo_Value(source_track, parameter))
  end
  local source_fx = app.TrackFX_GetCount(source_track)
  for index = 0, source_fx - 1 do
    app.TrackFX_CopyToTrack(source_track, index, destination, -1, false)
  end
  if app.TrackFX_GetCount(destination) ~= source_fx then
    return nil, "track_fx_copy_failed"
  end
  return true
end

local function regenerated_chunk(chunk)
  chunk = chunk:gsub("([\r\n])GUID%s+{[%x%-]+}", function(prefix)
    return prefix .. "GUID " .. app.genGuid("")
  end)
  chunk = chunk:gsub("([\r\n])IGUID%s+{[%x%-]+}", function(prefix)
    return prefix .. "IGUID " .. app.genGuid("")
  end)
  chunk = chunk:gsub("(POOLEDEVTS%s+){[%x%-]+}", function(prefix)
    return prefix .. app.genGuid("")
  end)
  return chunk
end

local function phrase_text(phrase)
  local identity = phrase.name ~= "" and phrase.name or phrase.label
  return phrase.family .. " - " .. identity
end

local function clone_phrase(source, lane, phrase, build)
  local chunk_ok, chunk = app.GetItemStateChunk(source, "", false)
  if not chunk_ok then
    return nil, "source_snapshot_failed"
  end
  local item = app.AddMediaItemToTrack(lane)
  if not item then
    return nil, "item_create_failed"
  end
  if not app.SetItemStateChunk(item, regenerated_chunk(chunk), false) then
    return nil, "item_copy_failed"
  end
  app.SetMediaItemInfo_Value(item, "D_POSITION", phrase.position)
  app.SetMediaItemInfo_Value(item, "B_MUTE", 0)
  app.SetMediaItemInfo_Value(item, "C_LOCK", 0)
  app.SetMediaItemInfo_Value(item, "I_GROUPID", 0)
  app.SetMediaItemSelected(item, false)
  local colour = FAMILY_COLOUR[phrase.family]
  app.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", app.ColorToNative(colour[1], colour[2], colour[3]) | 0x1000000)
  local text = phrase_text(phrase)
  if not write_item_string(item, "P_NOTES", text) then
    return nil, "metadata_write_failed"
  end
  local take = app.GetActiveTake(item)
  if take and not app.GetSetMediaItemTakeInfo_String(take, "P_NAME", text, true) then
    return nil, "take_name_failed"
  end
  local tagged, tag_error = true
  for parameter, value in pairs({
    [ROLE_PARAMETER] = "generated_phrase",
    [BUILD_ID_PARAMETER] = build.id,
    [COMPONENT_ID_PARAMETER] = phrase.component_id,
    [FAMILY_PARAMETER] = phrase.family,
    [SOURCE_ID_PARAMETER] = phrase.source_item_guid,
  }) do
    if not write_item_string(item, parameter, value) then
      tagged = nil
      tag_error = "metadata_write_failed"
      break
    end
  end
  if not tagged then
    return nil, tag_error
  end
  return item
end

local function processing_source(project, palette, sequence)
  local fallback
  for _, variant in ipairs(palette) do
    if variant.family == "Main" then
      local item = exact_source(project, variant.source_item_guid)
      if item then
        if variant.default then
          return app.GetMediaItem_Track(item)
        end
        fallback = fallback or item
      end
    end
  end
  if fallback then
    return app.GetMediaItem_Track(fallback)
  end
  local first = sequence[1] and exact_source(project, sequence[1].source_item_guid)
  return first and app.GetMediaItem_Track(first) or nil
end

local function restore_parameter(master, found, value)
  local restored = app.GetSetMediaTrackInfo_String(master, V3_PARAMETER, found and value or "", true)
  local restored_found, restored_value = app.GetSetMediaTrackInfo_String(master, V3_PARAMETER, "", false)
  return restored and restored_found == found and restored_value == (found and value or "")
end

function adapter.port(project)
  local port = {}

  function port.load(idea_id)
    local master = app.GetMasterTrack(project)
    assert(master, "REAPER returned no master track")
    local v1_found, v1_value = app.GetSetMediaTrackInfo_String(master, V1_PARAMETER, "", false)
    local v1, v1_error = state_codec.decode(v1_found and v1_value or "")
    if not v1 then
      return nil, v1_error
    end
    local v2_found, v2_value = app.GetSetMediaTrackInfo_String(master, V2_PARAMETER, "", false)
    local v2
    if v2_found and v2_value ~= "" then
      v2, v1_error = grammar_codec.decode(v2_value)
      if not v2 then
        return nil, v1_error
      end
    else
      v2 = grammar.from_v1(v1)
    end
    local current_idea = grammar.idea(v2, idea_id)
    if not current_idea then
      return nil, "idea_missing"
    end
    local v3_found, v3_value = app.GetSetMediaTrackInfo_String(master, V3_PARAMETER, "", false)
    local v3, v3_error = v3_codec.decode(v3_found and v3_value or "")
    if not v3 then
      return nil, v3_error
    end
    local palette, source_summary = palette_for(project, current_idea)
    return {
      idea = current_idea,
      v3 = v3,
      palette = palette,
      source_summary = source_summary,
      surviving_build_ids = surviving_build_ids(project, v3, idea_id),
    }
  end

  function port.cursor()
    return app.GetCursorPositionEx(project)
  end

  function port.measure_boundaries(anchor, bars)
    local beat, measure = app.TimeMap2_timeToBeats(project, anchor)
    if not beat or not measure then
      return nil, "time_map_failed"
    end
    local boundaries = { anchor }
    for offset = 1, bars do
      local boundary = app.TimeMap2_beatsToTime(project, beat, measure + offset)
      if not boundary or boundary <= boundaries[#boundaries] then
        return nil, "time_map_failed"
      end
      boundaries[#boundaries + 1] = boundary
    end
    return boundaries
  end

  function port.bars_for_span(anchor, duration)
    local start_beat, start_measure, start_length = app.TimeMap2_timeToBeats(project, anchor)
    local end_beat, end_measure, end_length = app.TimeMap2_timeToBeats(project, anchor + duration)
    if not start_measure or not end_measure or start_length <= 0 or end_length <= 0 then
      return duration
    end
    return end_measure + end_beat / end_length - (start_measure + start_beat / start_length)
  end

  function port.new_guid()
    return app.genGuid("")
  end

  function port.publish(next_state, composition, build, palette)
    if not project_is_active(project) then
      return nil, "project_inactive"
    end
    local sources = {}
    for _, phrase in ipairs(build.sequence) do
      if not sources[phrase.source_item_guid] then
        local item, source_error = exact_source(project, phrase.source_item_guid)
        if not item then
          return nil, source_error == "source_ambiguous" and "source_ambiguous" or "source_changed"
        end
        sources[phrase.source_item_guid] = item
      end
    end
    local processing = processing_source(project, palette, build.sequence)
    if not processing then
      return nil, "main_required"
    end

    local master = app.GetMasterTrack(project)
    assert(master, "REAPER returned no master track")
    local previous_found, previous = app.GetSetMediaTrackInfo_String(master, V3_PARAMETER, "", false)
    local encoded = v3_codec.encode(next_state)
    local created_tracks = {}
    local previous_mutes = {}
    local previous_closing
    local previous_closing_depth
    local operation_error

    app.Undo_BeginBlock2(project)
    local operation_ok, operation_trace = xpcall(function()
      local root, root_index = find_root(project, composition.root_id)
      local managed_builds = {}
      local closing
      if root then
        managed_builds, closing = root_contents(project, root, root_index, composition.root_id)
        if not closing then
          operation_error = "generated_root_invalid"
          return
        end
        previous_closing = closing
        previous_closing_depth = app.GetMediaTrackInfo_Value(closing, "I_FOLDERDEPTH")
        app.SetMediaTrackInfo_Value(closing, "I_FOLDERDEPTH", previous_closing_depth + 1)
      else
        root, root_index, operation_error = create_root(project, composition.root_id, created_tracks)
        if not root then
          return
        end
      end

      for _, old_build in ipairs(managed_builds) do
        previous_mutes[#previous_mutes + 1] = {
          track = old_build,
          mute = app.GetMediaTrackInfo_Value(old_build, "B_MUTE"),
        }
        app.SetMediaTrackInfo_Value(old_build, "B_MUTE", 1)
      end

      local insertion_index = previous_closing and track_index(project, previous_closing) + 1 or root_index + 1
      local build_track
      build_track, operation_error = insert_track(project, insertion_index, created_tracks)
      if not build_track then
        return
      end
      if not name_track(build_track, string.format("Build %03d", #composition.builds)) then
        operation_error = "track_name_failed"
        return
      end
      local tagged
      tagged, operation_error = tag_track(build_track, {
        [ROLE_PARAMETER] = "build",
        [ROOT_ID_PARAMETER] = composition.root_id,
        [COMPOSITION_ID_PARAMETER] = composition.id,
        [BUILD_ID_PARAMETER] = build.id,
        [SUGGESTION_ID_PARAMETER] = build.suggestion_id,
      })
      if not tagged then
        return
      end
      app.SetMediaTrackInfo_Value(build_track, "I_FOLDERDEPTH", 1)
      app.SetMediaTrackInfo_Value(build_track, "B_MUTE", 0)
      local copied
      copied, operation_error = copy_processing(processing, build_track)
      if not copied then
        return
      end

      local lanes = {}
      for index, lane_name in ipairs({ "A", "B" }) do
        local lane
        lane, operation_error = insert_track(project, insertion_index + index, created_tracks)
        if not lane then
          return
        end
        if not name_track(lane, "Lane " .. lane_name) then
          operation_error = "track_name_failed"
          return
        end
        tagged, operation_error = tag_track(lane, {
          [ROLE_PARAMETER] = "lane",
          [ROOT_ID_PARAMETER] = composition.root_id,
          [BUILD_ID_PARAMETER] = build.id,
          [LANE_PARAMETER] = lane_name,
        })
        if not tagged then
          return
        end
        app.SetMediaTrackInfo_Value(lane, "I_FOLDERDEPTH", lane_name == "B" and -2 or 0)
        lanes[lane_name] = lane
      end

      for _, phrase in ipairs(build.sequence) do
        local item
        item, operation_error = clone_phrase(sources[phrase.source_item_guid], lanes[phrase.lane], phrase, build)
        if not item then
          return
        end
      end

      local written = app.GetSetMediaTrackInfo_String(master, V3_PARAMETER, encoded, true)
      local verified_found, verified = app.GetSetMediaTrackInfo_String(master, V3_PARAMETER, "", false)
      if not written or not verified_found or verified ~= encoded then
        operation_error = "state_write_failed"
      end
    end, debug.traceback)

    local restored = true
    if not operation_ok or operation_error then
      for index = #created_tracks, 1, -1 do
        restored = pcall(app.DeleteTrack, created_tracks[index]) and restored
      end
      if previous_closing then
        app.SetMediaTrackInfo_Value(previous_closing, "I_FOLDERDEPTH", previous_closing_depth)
      end
      for _, saved in ipairs(previous_mutes) do
        app.SetMediaTrackInfo_Value(saved.track, "B_MUTE", saved.mute)
      end
      restored = restore_parameter(master, previous_found, previous) and restored
      app.UpdateArrange()
    end
    app.Undo_EndBlock2(project, "HIT: Generate Build " .. string.format("%03d", #composition.builds), -1)

    if not operation_ok then
      if not restored then
        return nil, "state_restore_failed"
      end
      error(operation_trace, 0)
    end
    if operation_error then
      return nil, restored and operation_error or "state_restore_failed"
    end
    app.MarkProjectDirty(project)
    app.UpdateArrange()
    return true
  end

  return port
end

function adapter.open(project, idea_id)
  return generation.open(adapter.port(project), idea_id)
end

function adapter.execute(project, idea_id, target_bars, seed)
  return generation.execute(adapter.port(project), idea_id, target_bars, seed)
end

return adapter
