package.path = "src/?.lua;src/?/init.lua;" .. package.path

local grammar = require("hit.model.grammar")
local codec = require("hit.model.grammar_codec")

local state = grammar.from_v1({
  version = 1,
  ideas = {
    {
      id = "{00000001-0000-0000-0000-000000000001}",
      name = "Idée; 高",
      source_item_guid = "{10000001-0000-0000-0000-000000000001}",
    },
  },
})
local component_id = state.ideas[1].families.Main.variants[1].component_id
state = assert(grammar.apply(state, state.ideas[1].id, {
  type = "set_name",
  component_id = component_id,
  name = "Calm; opening",
}))
state = assert(grammar.apply(state, state.ideas[1].id, {
  type = "set_intensity",
  component_id = component_id,
  intensity = 2,
}))
state = assert(grammar.apply(state, state.ideas[1].id, {
  type = "set_variant_grammar",
  component_id = component_id,
  grammar = {
    may_begin = true,
    may_repeat = true,
    may_end = false,
    may_overlap = true,
    allowed_next = { Main = true, Ending = true },
  },
}))
state.ideas[1].dismissed_recoveries[1] = "boundary;20.5|candidate"

local encoded = codec.encode(state)
assert(encoded:sub(1, 2) == "2|")
assert(not encoded:find("[\r\n]"))
local decoded = assert(codec.decode(encoded))
assert(codec.encode(decoded) == encoded)
local variant = decoded.ideas[1].families.Main.variants[1]
assert(variant.component_id == component_id)
assert(variant.name == "Calm; opening")
assert(variant.intensity == 2)
assert(variant.grammar_override.may_repeat)
assert(variant.grammar_override.allowed_next.Ending)
assert(decoded.ideas[1].dismissed_recoveries[1] == "boundary;20.5|candidate")

assert(codec.decode("2").version == 2)
for _, invalid in ipairs({
  "",
  "1",
  "3|future",
  "2|",
  "2|I;bad;Name",
  encoded .. "|",
  (encoded:gsub(";2;override;", ";6;override;", 1)),
}) do
  local value, error_code = codec.decode(invalid)
  assert(value == nil)
  assert(error_code == (invalid:match("^[13]") and "state_version_unsupported" or "state_invalid"))
end

print("grammar codec tests passed")
