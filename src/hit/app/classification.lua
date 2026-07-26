local grammar = require("hit.model.grammar")

local classification = {}

local function load_state(port)
  local loaded, load_error = port.load()
  if not loaded then
    return nil, load_error
  end
  if loaded.v2 then
    return loaded.v2
  end
  return grammar.from_v1(loaded.v1)
end

local function source_counts(current_idea)
  local counts = {}
  for _, family_name in ipairs(grammar.FAMILY_ORDER) do
    for _, variant in ipairs(current_idea.families[family_name].variants) do
      counts[variant.source_item_guid] = (counts[variant.source_item_guid] or 0) + 1
    end
  end
  return counts
end

function classification.open(port, idea_id)
  assert(type(port) == "table" and type(port.load) == "function", "project port required")
  local state, load_error = load_state(port)
  if not state then
    return {
      idea_id = idea_id,
      read_only = true,
      error = load_error,
      families = {},
    }
  end
  local current_idea = grammar.idea(state, idea_id)
  if not current_idea then
    return nil, "idea_missing"
  end

  local facts = port.source_facts(current_idea) or {}
  local counts = source_counts(current_idea)
  local classified = false
  for _, family_name in ipairs(grammar.FAMILY_ORDER) do
    for _, variant in ipairs(current_idea.families[family_name].variants) do
      local source = facts[variant.source_item_guid] or { status = "missing" }
      variant.source = source
      variant.shared = counts[variant.source_item_guid] > 1
      if family_name == "Main" and source.status == "available" then
        classified = true
      end
    end
  end
  current_idea.read_only = false
  current_idea.classified = classified
  current_idea.version = state.version
  current_idea.recovery = port.recovery_candidates and port.recovery_candidates(state, current_idea) or {}
  return current_idea
end

function classification.execute(port, idea_id, command)
  assert(type(port) == "table" and type(port.load) == "function", "project port required")
  assert(type(command) == "table", "command required")
  local state, load_error = load_state(port)
  if not state then
    return nil, load_error
  end

  if command.type == "bulk_add" and command.sources == nil then
    local sources, source_error = port.selected_sources()
    if not sources then
      return nil, source_error
    end
    command = { type = "bulk_add", sources = sources }
  end

  if command.type == "split" then
    local current_idea = grammar.idea(state, idea_id)
    local variant = current_idea and grammar.variant(current_idea, command.component_id)
    if not variant then
      return nil, "variant_missing"
    end
    local source = (port.source_facts(current_idea) or {})[variant.source_item_guid]
    if not source or source.status == "missing" then
      return nil, "source_missing"
    end
    if source.status == "ambiguous" then
      return nil, "source_ambiguous"
    end
    if source.status ~= "available" then
      return nil, "source_unavailable"
    end
    local component_id = port.new_guid()
    local committed, split_error = port.split_source(
      variant.source_item_guid,
      "HIT: Split Variant - " .. current_idea.name,
      function(right_source_item_guid)
        local next_state, apply_error = grammar.apply(state, idea_id, {
          type = "split",
          component_id = command.component_id,
          source_item_guid = right_source_item_guid,
        }, { component_id })
        return next_state, apply_error
      end
    )
    if not committed then
      return nil, split_error
    end
    return classification.open(port, idea_id)
  end

  if command.type == "attach_recovery" or command.type == "dismiss_recovery" then
    local current_idea = grammar.idea(state, idea_id)
    local candidates = current_idea and port.recovery_candidates(state, current_idea) or {}
    local candidate
    for _, current in ipairs(candidates) do
      if current.fingerprint == command.fingerprint then
        candidate = current
        break
      end
    end
    if not candidate then
      return nil, "recovery_missing"
    end
    if command.type == "attach_recovery" then
      command = {
        type = "attach_recovery",
        component_id = candidate.component_id,
        source_item_guid = candidate.source_item_guid,
        fingerprint = candidate.fingerprint,
      }
    end
  end

  local id_count = command.type == "bulk_add" and #command.sources
    or ((command.type == "alternate_use" or command.type == "attach_recovery") and 1 or 0)
  local generated_ids = {}
  for index = 1, id_count do
    generated_ids[index] = port.new_guid()
  end

  local next_state, apply_error, undo_label, outcome = grammar.apply(state, idea_id, command, generated_ids)
  if not next_state then
    return nil, apply_error
  end
  local committed, commit_error = port.commit(next_state, undo_label)
  if not committed then
    return nil, commit_error
  end
  return classification.open(port, idea_id), nil, outcome
end

return classification
