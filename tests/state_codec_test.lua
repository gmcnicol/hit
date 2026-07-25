package.path = "src/?.lua;src/?/init.lua;" .. package.path

local codec = require("hit.model.state_codec")

local empty = assert(codec.decode(nil))
local another_empty = assert(codec.decode(""))
assert(empty.version == 1 and #empty.ideas == 0)
assert(another_empty.version == 1 and #another_empty.ideas == 0)
assert(empty ~= another_empty and empty.ideas ~= another_empty.ideas)

for _, unsupported in ipairs({
  "0",
  "2",
  "2|future;shape;here",
}) do
  local result, error_code = codec.decode(unsupported)
  assert(result == nil)
  assert(error_code == "state_version_unsupported")
end

local state = {
  version = 1,
  ideas = {
    {
      id = "{0000000B-0000-0000-0000-00000000000B}",
      name = "Riff; 50% 高!",
      source_item_guid = "{1000000A-0000-0000-0000-00000000000A}",
    },
    {
      id = "{0000000C-0000-0000-0000-00000000000C}",
      name = "Riff; 50% 高!",
      source_item_guid = "{1000000A-0000-0000-0000-00000000000A}",
    },
  },
}

local encoded = codec.encode(state)
assert(encoded:sub(1, 2) == "1|")
assert(not encoded:find("[\r\n]"))

local decoded = assert(codec.decode(encoded))
assert(decoded.version == 1)
assert(#decoded.ideas == 2)
assert(decoded.ideas[1].id == "{0000000B-0000-0000-0000-00000000000B}")
assert(decoded.ideas[1].name == "Riff; 50% 高!")
assert(decoded.ideas[1].source_item_guid == "{1000000A-0000-0000-0000-00000000000A}")
assert(decoded.ideas[2].id == "{0000000C-0000-0000-0000-00000000000C}")
assert(decoded.ideas[2].name == "Riff; 50% 高!")
assert(decoded.ideas[2].source_item_guid == "{1000000A-0000-0000-0000-00000000000A}")

for _, malformed in ipairs({
  "not-a-version",
  "1|",
  "1|id;name",
  "1|id;name;guid;extra",
  "1|id;;guid",
  "1|id;%ZZ;guid",
  "1|id;raw\nline;guid",
  "1|id;Line%0ABreak;guid",
  "1|id;Nul%00Break;guid",
  "1|id;Delete%7FBreak;guid",
  "1|%0A;Name;%0A",
  "1|not-a-guid;Name;also-not-a-guid",
  "1|id;name;guid|id;other;guid-2",
}) do
  local result, error_code = codec.decode(malformed)
  assert(result == nil)
  assert(error_code == "state_invalid")
end

local invalid_memory_ok = pcall(codec.encode, { version = 1, ideas = { { id = "id" } } })
assert(invalid_memory_ok == false)

local duplicate_memory_id_ok = pcall(codec.encode, {
  version = 1,
  ideas = {
    { id = "id", name = "One", source_item_guid = "source-1" },
    { id = "id", name = "Two", source_item_guid = "source-2" },
  },
})
assert(duplicate_memory_id_ok == false)

print("state codec tests passed")
