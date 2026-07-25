package.path = "src/?.lua;src/?/init.lua;" .. package.path

local idea = require("hit.model.idea")

local state = {
  version = 1,
  ideas = {
    {
      id = "{00000009-0000-0000-0000-000000000009}",
      name = "Existing",
      source_item_guid = "{10000008-0000-0000-0000-000000000008}",
    },
  },
}
local item_facts = { source_item_guid = "{10000009-0000-0000-0000-000000000009}" }

local created = assert(idea.create(state, item_facts, "  Idée 高!  ", "{00000001-0000-0000-0000-000000000001}"))
assert(created ~= state)
assert(created.ideas ~= state.ideas)
assert(#created.ideas == 2)
assert(created.ideas[2].id == "{00000001-0000-0000-0000-000000000001}")
assert(created.ideas[2].name == "Idée 高!")
assert(created.ideas[2].source_item_guid == "{10000009-0000-0000-0000-000000000009}")
local field_count = 0
for _ in pairs(created.ideas[2]) do
  field_count = field_count + 1
end
assert(field_count == 3)
assert(#state.ideas == 1)
assert(item_facts.source_item_guid == "{10000009-0000-0000-0000-000000000009}")

local missing_name, name_error = idea.create(state, item_facts, " \t\n ", "{00000001-0000-0000-0000-000000000001}")
assert(missing_name == nil)
assert(name_error == "name_required")

local shared_source = assert(idea.create(
  state,
  { source_item_guid = "{10000008-0000-0000-0000-000000000008}" },
  "Existing",
  "{0000000A-0000-0000-0000-00000000000A}"
))
assert(shared_source.ideas[2].name == "Existing")
assert(shared_source.ideas[2].source_item_guid == "{10000008-0000-0000-0000-000000000008}")

for _, invalid_name in ipairs({
  "Line\nBreak",
  "Tab\tBreak",
  "Nul\0Break",
  "Delete\127Break",
}) do
  local invalid, invalid_error = idea.create(state, item_facts, invalid_name, "{00000001-0000-0000-0000-000000000001}")
  assert(invalid == nil)
  assert(invalid_error == "name_invalid")
end

local duplicate_id_ok = pcall(idea.create, state, item_facts, "Duplicate ID", "{00000009-0000-0000-0000-000000000009}")
assert(duplicate_id_ok == false)

print("idea tests passed")
