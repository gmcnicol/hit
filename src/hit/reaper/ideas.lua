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
  return guid
end

function ideas.selected_audio(project)
  if app.CountSelectedMediaItems(project) ~= 1 then
    return nil, "selection_count"
  end

  local item = app.GetSelectedMediaItem(project, 0)
  local take = item and app.GetActiveTake(item)
  if not take then
    return nil, "active_take_missing"
  end

  local source = app.GetMediaItemTake_Source(take)
  if not source or app.TakeIsMIDI(take) or app.GetMediaSourceNumChannels(source) <= 0 then
    return nil, "audio_required"
  end

  local guid, guid_error = source_guid(item)
  if not guid then
    return nil, guid_error
  end

  local track = app.GetMediaItem_Track(item)
  assert(track, "selected media item must have parent track")

  return {
    source_item_guid = guid,
    suggested_name = app.GetTakeName(take) or "",
    _track = track,
  }
end

function ideas.load(project)
  local registrations = {}
  local ids = {}
  local sources = {}

  for track_index = 0, app.CountTracks(project) - 1 do
    local track = app.GetTrack(project, track_index)
    local found, value = app.GetSetMediaTrackInfo_String(track, STATE_PARAMETER, "", false)
    if found and value ~= "" then
      local state, decode_error = codec.decode(value)
      if not state then
        return nil, decode_error
      end

      for _, current in ipairs(state.ideas) do
        if ids[current.id] or sources[current.source_item_guid] then
          return nil, "state_invalid"
        end
        ids[current.id] = true
        sources[current.source_item_guid] = true
        registrations[#registrations + 1] = {
          idea = current,
          track = track,
        }
      end
    end
  end

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

  local view = { ideas = {} }
  for _, registration in ipairs(registrations) do
    local current = registration.idea
    local item = items[current.source_item_guid]
    if item == false then
      return nil, "state_invalid"
    end
    local status = "missing"
    if item then
      status = app.GetMediaItem_Track(item) == registration.track and "available" or "moved"
    end
    view.ideas[#view.ideas + 1] = {
      id = current.id,
      name = current.name,
      source_item_guid = current.source_item_guid,
      source_status = status,
    }
  end

  return view
end

function ideas.create(project, expected_source_item_guid, proposed_name)
  assert(type(expected_source_item_guid) == "string", "expected_source_item_guid must be string")

  local selected, selection_error = ideas.selected_audio(project)
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
      return nil, "source_already_registered"
    end
  end

  local found, value = app.GetSetMediaTrackInfo_String(selected._track, STATE_PARAMETER, "", false)
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

  app.Undo_BeginBlock2(project)
  local written = app.GetSetMediaTrackInfo_String(selected._track, STATE_PARAMETER, encoded, true)
  if written then
    app.MarkProjectDirty(project)
  end
  app.Undo_EndBlock2(project, undo_label, -1)

  if not written then
    return nil, "state_write_failed"
  end
  return created
end

return ideas
