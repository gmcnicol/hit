local app = reaper
local idea = require("hit.model.idea")
local codec = require("hit.model.state_codec")

local ideas = {}
local STATE_PARAMETER = "P_EXT:HIT_STATE_V1"

local function source_guid(item)
  local ok, guid = app.GetSetMediaItemInfo_String(item, "GUID", "", false)
  if not ok or guid == "" then
    return nil, "source_guid_missing"
  end
  if not idea.guid_is_valid(guid) then
    return nil, "source_guid_invalid"
  end
  return guid
end

local function index_items(project)
  local items = {}
  for item_index = 0, app.CountMediaItems(project) - 1 do
    local item = app.GetMediaItem(project, item_index)
    local guid = source_guid(item)
    if guid then
      if items[guid] ~= nil then
        items[guid] = false
      else
        items[guid] = item
      end
    end
  end
  return items
end

local function take_facts(take)
  if app.TakeIsMIDI(take) then
    return "midi", true
  end
  local source = app.GetMediaItemTake_Source(take)
  if not source or app.GetMediaSourceNumChannels(source) <= 0 then
    return
  end
  if app.GetMediaSourceType(source):match("^_OFFLINE") then
    return "audio", false
  end
  local filename = app.GetMediaSourceFileName(source)
  return "audio", filename == "" or app.file_exists(filename)
end

function ideas.validate_name(proposed_name)
  return idea.validate_name(proposed_name)
end

function ideas.selected_item(project)
  local selection_count = app.CountSelectedMediaItems(project)
  if selection_count == 0 then
    return nil, "selection_none"
  end
  if selection_count > 1 then
    return nil, "selection_multiple"
  end

  local item = app.GetSelectedMediaItem(project, 0)
  local take = item and app.GetActiveTake(item)
  if not take then
    return nil, "active_take_missing"
  end

  local source_kind, source_available = take_facts(take)
  if not source_kind then
    return nil, "source_unsupported"
  end
  if not source_available then
    return nil, "audio_unavailable"
  end

  local guid, guid_error = source_guid(item)
  if not guid then
    return nil, guid_error
  end

  return {
    source_item_guid = guid,
    suggested_name = app.GetTakeName(take) or "",
    source_kind = source_kind,
  }
end

function ideas.load(project)
  local registrations = {}

  local master = app.GetMasterTrack(project)
  assert(master, "REAPER returned no master track")
  local found, value = app.GetSetMediaTrackInfo_String(master, STATE_PARAMETER, "", false)
  local state, decode_error = codec.decode(found and value or "")
  if not state then
    return nil, decode_error
  end
  for _, current in ipairs(state.ideas) do
    registrations[#registrations + 1] = {
      idea = current,
    }
  end

  local items = index_items(project)
  local view = { ideas = {} }
  for _, registration in ipairs(registrations) do
    local current = registration.idea
    local item = items[current.source_item_guid]

    local row = {
      id = current.id,
      name = current.name,
      source_item_guid = current.source_item_guid,
      source_status = "missing",
      selected = false,
    }
    if item == false then
      row.source_status = "ambiguous"
    elseif item then
      local track = app.GetMediaItem_Track(item)
      local take = app.GetActiveTake(item)
      local kind
      local available
      if take then
        kind, available = take_facts(take)
      end
      local position = app.GetMediaItemInfo_Value(item, "D_POSITION")
      local duration = app.GetMediaItemInfo_Value(item, "D_LENGTH")
      local _, track_name = app.GetTrackName(track)
      row.source_status = kind and available and "available" or "unavailable"
      row.source_name = take and (app.GetTakeName(take) or "") or ""
      row.source_kind = kind or "unknown"
      row.track_name = track_name
      row.track_index = app.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
      row.position = position
      row.duration = duration
      row.position_text = app.format_timestr_pos(position, "", -1)
      row.duration_text = app.format_timestr_len(duration, "", position, -1)
      row.selected = app.IsMediaItemSelected(item)
      row.track_hidden = app.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0
    end
    view.ideas[#view.ideas + 1] = row
  end

  table.sort(view.ideas, function(left, right)
    local left_resolved = left.track_index ~= nil
    local right_resolved = right.track_index ~= nil
    if left_resolved ~= right_resolved then
      return left_resolved
    end
    if not left_resolved then
      return left.id < right.id
    end
    if left.track_index ~= right.track_index then
      return left.track_index < right.track_index
    end
    if left.position ~= right.position then
      return left.position < right.position
    end
    return left.id < right.id
  end)

  return view
end

function ideas.select_source(project, source_item_guid)
  assert(
    type(source_item_guid) == "string" and source_item_guid ~= "",
    "source_item_guid must be non-empty string"
  )

  local item = index_items(project)[source_item_guid]
  if item == false then
    return nil, "source_ambiguous"
  end
  if not item then
    return nil, "source_missing"
  end

  app.SelectAllMediaItems(project, false)
  app.SetMediaItemSelected(item, true)
  local view_start, view_end = app.GetSet_ArrangeView2(project, false, 0, 0, 0, 0)
  local item_start = app.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_end = item_start + app.GetMediaItemInfo_Value(item, "D_LENGTH")
  if item_start < view_start or item_end > view_end then
    local width = math.max(view_end - view_start, item_end - item_start)
    local centre = (item_start + item_end) / 2
    local next_start = math.max(0, centre - width / 2)
    app.GetSet_ArrangeView2(project, true, 0, 0, next_start, next_start + width)
  end
  app.UpdateArrange()
  return true
end

function ideas.create(project, expected_source_item_guid, proposed_name)
  assert(type(expected_source_item_guid) == "string", "expected_source_item_guid must be string")

  local selected, selection_error = ideas.selected_item(project)
  if not selected then
    return nil, selection_error
  end
  if selected.source_item_guid ~= expected_source_item_guid then
    return nil, "selection_changed"
  end

  local project_state, load_error = ideas.load(project)
  if not project_state then
    return nil, load_error
  end
  for _, current in ipairs(project_state.ideas) do
    if current.source_item_guid == selected.source_item_guid then
      return nil, "source_already_registered", current
    end
  end

  local master = app.GetMasterTrack(project)
  assert(master, "REAPER returned no master track")
  local found, value = app.GetSetMediaTrackInfo_String(master, STATE_PARAMETER, "", false)
  local state, decode_error = codec.decode(found and value or "")
  if not state then
    return nil, decode_error
  end

  local next_state, create_error = idea.create(
    state,
    { source_item_guid = selected.source_item_guid },
    proposed_name,
    app.genGuid("")
  )
  if not next_state then
    return nil, create_error
  end

  local encoded = codec.encode(next_state)
  local created = next_state.ideas[#next_state.ideas]
  local undo_label = "HIT: Create Idea " .. created.name
  local previous = found and value or ""

  app.Undo_BeginBlock2(project)
  local write_ok, written_or_trace = xpcall(function()
    local written = app.GetSetMediaTrackInfo_String(
      master,
      STATE_PARAMETER,
      encoded,
      true
    )
    local verified_found, verified_value = app.GetSetMediaTrackInfo_String(
      master,
      STATE_PARAMETER,
      "",
      false
    )
    return written and verified_found and verified_value == encoded
  end, debug.traceback)

  local function restore()
    local restored_ok = pcall(
      app.GetSetMediaTrackInfo_String,
      master,
      STATE_PARAMETER,
      previous,
      true
    )
    if not restored_ok then
      return false
    end
    local read_ok, restored_found, restored_value = pcall(
      app.GetSetMediaTrackInfo_String,
      master,
      STATE_PARAMETER,
      "",
      false
    )
    local prior_found = found and value ~= ""
    return read_ok
      and restored_found == prior_found
      and restored_value == (prior_found and value or "")
  end

  local restored
  if not write_ok or not written_or_trace then
    restored = restore()
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
  return created
end

return ideas
