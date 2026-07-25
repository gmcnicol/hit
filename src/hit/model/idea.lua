local idea = {}

function idea.guid_is_valid(value)
  return type(value) == "string"
    and value:match(
      "^%{%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%}$"
    ) ~= nil
end

function idea.validate_name(proposed_name)
  assert(type(proposed_name) == "string", "proposed_name must be string")

  local name = proposed_name:match("^%s*(.-)%s*$")
  if name == "" then
    return nil, "name_required"
  end
  if name:find("[%z\1-\31\127]") then
    return nil, "name_invalid"
  end
  return name
end

function idea.create(state, item_facts, proposed_name, idea_id)
  assert(type(state) == "table", "state must be table")
  assert(state.version == 1, "state version must be 1")
  assert(type(state.ideas) == "table", "state ideas must be table")
  assert(type(item_facts) == "table", "item_facts must be table")
  assert(
    idea.guid_is_valid(item_facts.source_item_guid),
    "source_item_guid must be GUID"
  )
  assert(idea.guid_is_valid(idea_id), "idea_id must be GUID")

  local name, name_error = idea.validate_name(proposed_name)
  if not name then
    return nil, name_error
  end

  local ideas = {}
  for index, existing in ipairs(state.ideas) do
    assert(type(existing) == "table", "state idea must be table")
    assert(idea.guid_is_valid(existing.id), "state idea id must be GUID")
    assert(idea.guid_is_valid(existing.source_item_guid), "state source_item_guid must be GUID")
    assert(existing.id ~= idea_id, "idea_id must be unique")

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
