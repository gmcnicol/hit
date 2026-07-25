package.path = "src/?.lua;src/?/init.lua;" .. package.path

local idea = require("hit.model.idea")

local state = {
  version = 1,
  ideas = {
    {
      id = "{EXISTING-IDEA}",
      name = "Existing",
      source_item_guid = "{EXISTING-ITEM}",
    },
  },
}
local item_facts = { source_item_guid = "{SOURCE-ITEM}" }

local created = assert(idea.create(state, item_facts, "  Idea A  ", "{IDEA-A}"))
assert(created ~= state)
assert(created.ideas ~= state.ideas)
assert(#created.ideas == 2)
assert(created.ideas[2].id == "{IDEA-A}")
assert(created.ideas[2].name == "Idea A")
assert(created.ideas[2].source_item_guid == "{SOURCE-ITEM}")
local field_count = 0
for _ in pairs(created.ideas[2]) do
  field_count = field_count + 1
end
assert(field_count == 3)
assert(#state.ideas == 1)
assert(item_facts.source_item_guid == "{SOURCE-ITEM}")

local missing_name, name_error = idea.create(state, item_facts, " \t\n ", "{IDEA-A}")
assert(missing_name == nil)
assert(name_error == "name_required")

local duplicate_source, source_error = idea.create(
  state,
  { source_item_guid = "{EXISTING-ITEM}" },
  "Duplicate",
  "{OTHER-IDEA}"
)
assert(duplicate_source == nil)
assert(source_error == "source_already_registered")

local duplicate_id_ok = pcall(idea.create, state, item_facts, "Duplicate ID", "{EXISTING-IDEA}")
assert(duplicate_id_ok == false)

print("idea tests passed")
