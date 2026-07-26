local app = reaper
local classification = require("hit.app.classification")
local state_codec = require("hit.model.state_codec")
local grammar_codec = require("hit.model.grammar_codec")
local ideas = require("hit.reaper.ideas")

local adapter = {}
local V1_PARAMETER = "P_EXT:HIT_STATE_V1"
local V2_PARAMETER = "P_EXT:HIT_STATE_V2"
local recovery_cache = setmetatable({}, { __mode = "k" })
local EPSILON = 0.000001

local function read_parameter(master, parameter)
  local found, value = app.GetSetMediaTrackInfo_String(master, parameter, "", false)
  return found and value ~= "", found and value or ""
end

local function project_is_active(project)
  return app.ValidatePtr(project, "ReaProject*") and app.EnumProjects(-1) == project
end

local function restore_parameter(master, parameter, found, value)
  local restored = app.GetSetMediaTrackInfo_String(
    master,
    parameter,
    found and value or "",
    true
  )
  if not restored then
    return false
  end
  local restored_found, restored_value = read_parameter(master, parameter)
  return restored_found == found and restored_value == (found and value or "")
end

function adapter.port(project)
  local port = {}

  function port.load()
    local master = app.GetMasterTrack(project)
    assert(master, "REAPER returned no master track")
    local v1_found, v1_value = read_parameter(master, V1_PARAMETER)
    local v1, v1_error = state_codec.decode(v1_found and v1_value or "")
    if not v1 then
      return nil, v1_error
    end
    local v2_found, v2_value = read_parameter(master, V2_PARAMETER)
    if not v2_found then
      return { v1 = v1 }
    end
    local v2, v2_error = grammar_codec.decode(v2_value)
    if not v2 then
      return nil, v2_error
    end
    return { v1 = v1, v2 = v2 }
  end

  function port.source_facts(current_idea)
    return ideas.source_facts(project, current_idea)
  end

  function port.selected_sources()
    return ideas.selected_items(project)
  end

  function port.new_guid()
    return app.genGuid("")
  end

  function port.recovery_candidates(_, current_idea)
    local revision = app.GetProjectStateChangeCount(project)
    local cached = recovery_cache[project]
    if cached and cached.revision == revision then
      return cached.candidates
    end

    local current = ideas.topology(project)
    local candidates = {}
    if cached then
      local known = {}
      local dismissed = {}
      for _, fingerprint in ipairs(current_idea.dismissed_recoveries) do
        dismissed[fingerprint] = true
      end
      for _, family_name in ipairs({ "Pickup", "Main", "Turnaround", "Ending" }) do
        for _, variant in ipairs(current_idea.families[family_name].variants) do
          known[variant.source_item_guid] = {
            component_id = variant.component_id,
            family = family_name,
            label = variant.label,
          }
        end
      end

      for source_item_guid, origin in pairs(known) do
        local before = cached.topology[source_item_guid]
        local after = current[source_item_guid]
        if before and after
          and math.abs(before.position - after.position) < EPSILON
          and after.duration < before.duration - EPSILON
          and before.source_key ~= nil
        then
          local boundary = after.position + after.duration
          local expected_offset = before.source_offset
            + after.duration * before.playrate
          local matches = {}
          for candidate_guid, candidate in pairs(current) do
            if not known[candidate_guid]
              and candidate.track_index == after.track_index
              and math.abs(candidate.position - boundary) < EPSILON
              and candidate.source_key == before.source_key
              and math.abs(candidate.source_offset - expected_offset) < EPSILON
            then
              matches[#matches + 1] = {
                component_id = origin.component_id,
                family = origin.family,
                origin_label = origin.label,
                origin_source_item_guid = source_item_guid,
                source_item_guid = candidate_guid,
                boundary = boundary,
                source_name = candidate.take_name ~= "" and candidate.take_name
                  or candidate.item_name,
              }
            end
          end
          if #matches == 1 then
            local match = matches[1]
            match.fingerprint = table.concat({
              match.origin_source_item_guid,
              match.source_item_guid,
              string.format("%.9f", match.boundary),
              string.format("%.9f", after.duration),
            }, ";")
            if not dismissed[match.fingerprint] then
              candidates[#candidates + 1] = match
            end
          end
        end
      end
    end
    table.sort(candidates, function(left, right)
      return left.fingerprint < right.fingerprint
    end)
    recovery_cache[project] = {
      revision = revision,
      topology = current,
      candidates = candidates,
    }
    return candidates
  end

  function port.commit(next_state, undo_label)
    if not project_is_active(project) then
      return nil, "project_inactive"
    end
    local master = app.GetMasterTrack(project)
    assert(master, "REAPER returned no master track")
    local previous_found, previous = read_parameter(master, V2_PARAMETER)
    local encoded = grammar_codec.encode(next_state)

    app.Undo_BeginBlock2(project)
    local write_ok, written_or_trace = xpcall(function()
      local written = app.GetSetMediaTrackInfo_String(
        master,
        V2_PARAMETER,
        encoded,
        true
      )
      local verified_found, verified = read_parameter(master, V2_PARAMETER)
      return written and verified_found and verified == encoded
    end, debug.traceback)

    local restored
    if not write_ok or not written_or_trace then
      restored = restore_parameter(
        master,
        V2_PARAMETER,
        previous_found,
        previous
      )
    end
    app.Undo_EndBlock2(project, undo_label, -1)

    if not write_ok then
      if not restored then
        return nil, "state_restore_failed"
      end
      error(written_or_trace, 0)
    end
    if not written_or_trace then
      return nil, restored and "state_write_failed" or "state_restore_failed"
    end
    app.MarkProjectDirty(project)
    return true
  end

  function port.split_source(source_item_guid, undo_label, build_next)
    if not project_is_active(project) then
      return nil, "project_inactive"
    end
    local item, source_error = ideas.find_source(project, source_item_guid)
    if not item then
      return nil, source_error
    end
    local position = app.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = app.GetMediaItemInfo_Value(item, "D_LENGTH")
    local cursor = app.GetCursorPositionEx(project)
    if cursor <= position or cursor >= position + length then
      return nil, "split_cursor_outside"
    end
    local chunk_ok, previous_chunk = app.GetItemStateChunk(item, "", false)
    if not chunk_ok then
      return nil, "source_snapshot_failed"
    end

    local master = app.GetMasterTrack(project)
    assert(master, "REAPER returned no master track")
    local previous_found, previous = read_parameter(master, V2_PARAMETER)
    local right_guid
    local operation_error
    local committed_state

    app.Undo_BeginBlock2(project)
    local operation_ok, operation_trace = xpcall(function()
      local right = app.SplitMediaItem(item, cursor)
      if not right then
        operation_error = "split_failed"
        return
      end
      local guid_ok
      guid_ok, right_guid = app.GetSetMediaItemInfo_String(right, "GUID", "", false)
      if not guid_ok or right_guid == "" then
        operation_error = "source_guid_missing"
        return
      end
      local next_state, build_error = build_next(right_guid)
      if not next_state then
        operation_error = build_error
        return
      end
      local encoded = grammar_codec.encode(next_state)
      local written = app.GetSetMediaTrackInfo_String(
        master,
        V2_PARAMETER,
        encoded,
        true
      )
      local verified_found, verified = read_parameter(master, V2_PARAMETER)
      if not written or not verified_found or verified ~= encoded then
        operation_error = "state_write_failed"
        return
      end
      committed_state = next_state
    end, debug.traceback)

    local restored = true
    if not operation_ok or operation_error then
      if right_guid then
        local right = ideas.find_source(project, right_guid)
        if right then
          local track = app.GetMediaItem_Track(right)
          restored = app.DeleteTrackMediaItem(track, right) and restored
        end
      end
      local left = ideas.find_source(project, source_item_guid)
      if left then
        restored = app.SetItemStateChunk(left, previous_chunk, false) and restored
      else
        restored = false
      end
      restored = restore_parameter(
        master,
        V2_PARAMETER,
        previous_found,
        previous
      ) and restored
      app.UpdateArrange()
    end
    app.Undo_EndBlock2(project, undo_label, -1)

    if not operation_ok then
      if not restored then
        return nil, "state_restore_failed"
      end
      error(operation_trace, 0)
    end
    if operation_error then
      return nil, restored and operation_error or "state_restore_failed"
    end
    assert(committed_state, "split committed without state")
    app.MarkProjectDirty(project)
    app.UpdateArrange()
    return true
  end

  return port
end

function adapter.open(project, idea_id)
  return classification.open(adapter.port(project), idea_id)
end

function adapter.execute(project, idea_id, command)
  return classification.execute(adapter.port(project), idea_id, command)
end

return adapter
