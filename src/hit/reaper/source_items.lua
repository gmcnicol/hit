local app = reaper
local idea = require("hit.model.idea")

local source_items = {}

---@class HitSourceFacts
---@field source_item_guid string?
---@field status "available"|"unavailable"|"missing"|"ambiguous"
---@field item_name string?
---@field take_name string?
---@field source_name string?
---@field source_kind "audio"|"midi"|"unknown"?
---@field track_name string?
---@field track_index number?
---@field position number?
---@field duration number?
---@field position_text string?
---@field duration_text string?
---@field selected boolean?
---@field track_hidden boolean?
---@field source_key string?
---@field source_offset number?
---@field playrate number?

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

local function item_source_facts(item)
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
  local _, item_name = app.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
  local source
  local source_type = ""
  local source_file = ""
  local source_offset = 0
  local playrate = 1
  if take then
    source = app.GetMediaItemTake_Source(take)
    if source then
      source_type = app.GetMediaSourceType(source) or ""
      source_file = app.GetMediaSourceFileName(source) or ""
    end
    source_offset = app.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    playrate = app.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  end
  return {
    status = kind and available and "available" or "unavailable",
    item_name = item_name or "",
    take_name = take and (app.GetTakeName(take) or "") or "",
    source_name = take and (app.GetTakeName(take) or "") or "",
    source_kind = kind or "unknown",
    track_name = track_name,
    track_index = app.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"),
    position = position,
    duration = duration,
    position_text = app.format_timestr_pos(position, "", -1),
    duration_text = app.format_timestr_len(duration, "", position, -1),
    selected = app.IsMediaItemSelected(item),
    track_hidden = app.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0,
    source_key = source_file ~= "" and (source_type .. "|" .. source_file) or nil,
    source_offset = source_offset,
    playrate = playrate,
  }
end

function source_items.resolve(project, source_item_guids)
  local indexed = index_items(project)
  local result = {}
  for _, guid in ipairs(source_item_guids) do
    if result[guid] == nil then
      local item = indexed[guid]
      if item == false then
        result[guid] = { status = "ambiguous" }
      elseif item then
        result[guid] = item_source_facts(item)
      else
        result[guid] = { status = "missing" }
      end
    end
  end
  return result
end

function source_items.selected_item(project)
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

function source_items.selected_items(project)
  local result = {}
  for index = 0, app.CountSelectedMediaItems(project) - 1 do
    local item = app.GetSelectedMediaItem(project, index)
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
    local facts = item_source_facts(item)
    facts.source_item_guid = guid
    result[#result + 1] = facts
  end
  if #result == 0 then
    return nil, "selection_none"
  end
  return result
end

---@param current_idea HitGrammarIdea
---@return table<string, HitSourceFacts>
function source_items.source_facts(project, current_idea)
  local source_item_guids = {}
  for _, family_name in ipairs({ "Pickup", "Main", "Turnaround", "Ending" }) do
    local family = current_idea.families[family_name]
    for _, variant in ipairs(family.variants) do
      source_item_guids[#source_item_guids + 1] = variant.source_item_guid
    end
  end
  return source_items.resolve(project, source_item_guids)
end

function source_items.find_source(project, source_item_guid)
  local item = index_items(project)[source_item_guid]
  if item == false then
    return nil, "source_ambiguous"
  end
  if not item then
    return nil, "source_missing"
  end
  return item
end

function source_items.topology(project)
  local result = {}
  for item_index = 0, app.CountMediaItems(project) - 1 do
    local item = app.GetMediaItem(project, item_index)
    local guid = source_guid(item)
    if guid then
      local facts = item_source_facts(item)
      facts.source_item_guid = guid
      result[guid] = facts
    end
  end
  return result
end

function source_items.select_source(project, source_item_guid)
  assert(type(source_item_guid) == "string" and source_item_guid ~= "", "source_item_guid must be non-empty string")

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

return source_items
