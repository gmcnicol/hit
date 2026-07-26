local app = reaper
local idea = require("hit.model.idea")
local codec = require("hit.model.state_codec")
local grammar = require("hit.model.grammar")
local grammar_codec = require("hit.model.grammar_codec")
local source_items = require("hit.reaper.source_items")

local ideas = {}
local STATE_PARAMETER = "P_EXT:HIT_STATE_V1"
local GRAMMAR_STATE_PARAMETER = "P_EXT:HIT_STATE_V2"

function ideas.validate_name(proposed_name)
  return idea.validate_name(proposed_name)
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

  local items = source_items.index(project)
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
      local facts = source_items.inspect(item)
      for key, fact in pairs(facts) do
        row[key == "status" and "source_status" or key] = fact
      end
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

function ideas.create(project, expected_source_item_guid, proposed_name)
  assert(type(expected_source_item_guid) == "string", "expected_source_item_guid must be string")

  local selected, selection_error = source_items.selected_item(project)
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

  local next_state, create_error =
    idea.create(state, { source_item_guid = selected.source_item_guid }, proposed_name, app.genGuid(""))
  if not next_state then
    return nil, create_error
  end

  local encoded = codec.encode(next_state)
  local created = next_state.ideas[#next_state.ideas]
  local grammar_found, grammar_value = app.GetSetMediaTrackInfo_String(master, GRAMMAR_STATE_PARAMETER, "", false)
  local current_grammar
  if grammar_found and grammar_value ~= "" then
    current_grammar, decode_error = grammar_codec.decode(grammar_value)
    if not current_grammar then
      return nil, decode_error
    end
  else
    current_grammar = grammar.from_v1(state)
  end
  local next_grammar = grammar.add_created_idea(current_grammar, created, grammar.component_id_for_idea(created.id))
  local grammar_encoded = grammar_codec.encode(next_grammar)
  local undo_label = "HIT: Create Idea " .. created.name
  local previous = found and value or ""
  local previous_grammar = grammar_found and grammar_value or ""

  app.Undo_BeginBlock2(project)
  local write_ok, written_or_trace = xpcall(function()
    local written = app.GetSetMediaTrackInfo_String(master, STATE_PARAMETER, encoded, true)
    local grammar_written = app.GetSetMediaTrackInfo_String(master, GRAMMAR_STATE_PARAMETER, grammar_encoded, true)
    local verified_found, verified_value = app.GetSetMediaTrackInfo_String(master, STATE_PARAMETER, "", false)
    local grammar_verified_found, grammar_verified_value =
      app.GetSetMediaTrackInfo_String(master, GRAMMAR_STATE_PARAMETER, "", false)
    return written
      and grammar_written
      and verified_found
      and verified_value == encoded
      and grammar_verified_found
      and grammar_verified_value == grammar_encoded
  end, debug.traceback)

  local function restore()
    local restored_ok = pcall(app.GetSetMediaTrackInfo_String, master, STATE_PARAMETER, previous, true)
    if not restored_ok then
      return false
    end
    local grammar_restored_ok =
      pcall(app.GetSetMediaTrackInfo_String, master, GRAMMAR_STATE_PARAMETER, previous_grammar, true)
    if not grammar_restored_ok then
      return false
    end
    local read_ok, restored_found, restored_value =
      pcall(app.GetSetMediaTrackInfo_String, master, STATE_PARAMETER, "", false)
    local prior_found = found and value ~= ""
    local grammar_read_ok, restored_grammar_found, restored_grammar_value =
      pcall(app.GetSetMediaTrackInfo_String, master, GRAMMAR_STATE_PARAMETER, "", false)
    local prior_grammar_found = grammar_found and grammar_value ~= ""
    return read_ok
      and restored_found == prior_found
      and restored_value == (prior_found and value or "")
      and grammar_read_ok
      and restored_grammar_found == prior_grammar_found
      and restored_grammar_value == (prior_grammar_found and grammar_value or "")
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
