local idea = {}

function idea.create(state, item_facts, proposed_name, idea_id)
  assert(type(state) == "table", "state must be table")
  assert(state.version == 1, "state version must be 1")
  assert(type(state.ideas) == "table", "state ideas must be table")
  assert(type(item_facts) == "table", "item_facts must be table")
  assert(
    type(item_facts.source_item_guid) == "string" and item_facts.source_item_guid ~= "",
    "source_item_guid must be non-empty string"
  )
  assert(type(proposed_name) == "string", "proposed_name must be string")
  assert(type(idea_id) == "string" and idea_id ~= "", "idea_id must be non-empty string")

  local name = proposed_name:match("^%s*(.-)%s*$")
  if name == "" then
    return nil, "name_required"
  end

  local ideas = {}
  for index, existing in ipairs(state.ideas) do
    assert(type(existing) == "table", "state idea must be table")
    assert(type(existing.id) == "string", "state idea id must be string")
    assert(type(existing.source_item_guid) == "string", "state source_item_guid must be string")
    assert(existing.id ~= idea_id, "idea_id must be unique")

    if existing.source_item_guid == item_facts.source_item_guid then
      return nil, "source_already_registered"
    end

    ideas[index] = existing
  end

  ideas[#ideas + 1] = {
    id = idea_id,
    name = name,
    source_item_guid = item_facts.source_item_guid,
  }

  return {
    version = state.version,
    ideas = ideas,
  }
end

return idea
