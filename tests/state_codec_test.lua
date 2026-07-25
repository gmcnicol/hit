package.path = "src/?.lua;src/?/init.lua;" .. package.path

local codec = require("hit.model.state_codec")

local empty = assert(codec.decode(nil))
local another_empty = assert(codec.decode(""))
assert(empty.version == 1 and #empty.ideas == 0)
assert(another_empty.version == 1 and #another_empty.ideas == 0)
assert(empty ~= another_empty and empty.ideas ~= another_empty.ideas)

local state = {
  version = 1,
  ideas = {
    {
      id = "{IDEA|1}",
      name = "Riff; 50%\n高",
      source_item_guid = "{ITEM;1}",
    },
  },
}

local encoded = codec.encode(state)
assert(encoded:sub(1, 2) == "1|")
assert(not encoded:find("[\r\n]"))

local decoded = assert(codec.decode(encoded))
assert(decoded.version == 1)
assert(#decoded.ideas == 1)
assert(decoded.ideas[1].id == "{IDEA|1}")
assert(decoded.ideas[1].name == "Riff; 50%\n高")
assert(decoded.ideas[1].source_item_guid == "{ITEM;1}")

for _, malformed in ipairs({
  "2",
  "1|",
  "1|id;name",
  "1|id;name;guid;extra",
  "1|id;;guid",
  "1|id;%ZZ;guid",
  "1|id;raw\nline;guid",
}) do
  local result, error_code = codec.decode(malformed)
  assert(result == nil)
  assert(error_code == "state_invalid")
end

local invalid_memory_ok = pcall(codec.encode, { version = 1, ideas = { { id = "id" } } })
assert(invalid_memory_ok == false)

print("state codec tests passed")
