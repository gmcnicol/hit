package.path = "src/?.lua;src/?/init.lua;" .. package.path

local codec = require("hit.model.v3_codec")

local state = {
  version = 3,
  compositions = {
    {
      id = "{30000001-0000-0000-0000-000000000001}",
      idea_id = "{00000001-0000-0000-0000-000000000001}",
      occurrence_id = "{31000001-0000-0000-0000-000000000001}",
      root_id = "{32000001-0000-0000-0000-000000000001}",
      revision = 3,
      target_bars = 48,
      anchor = 2.125,
      compiler_version = "3.0.0",
      builds = {
        {
          id = "{33000001-0000-0000-0000-000000000001}",
          suggestion_id = "{34000001-0000-0000-0000-000000000001}",
          composition_revision = 3,
          seed = -4,
          compiler_version = "3.0.0",
          target_bars = 48,
          target_duration = 96.5,
          achieved_duration = 98.25,
          achieved_bars = 49.25,
          explanation = "Pickup 1; Main 高",
          source_palette = {
            {
              component_id = "{20000001-0000-0000-0000-000000000001}",
              source_item_guid = "{10000001-0000-0000-0000-000000000001}",
              family = "Main",
            },
          },
          sequence = {
            {
              component_id = "{20000001-0000-0000-0000-000000000001}",
              source_item_guid = "{10000001-0000-0000-0000-000000000001}",
              family = "Main",
              label = "A",
              name = "Wide; 高",
              position = 2.125,
              duration = 98.25,
              overlap = 0,
              lane = "A",
            },
          },
        },
      },
    },
  },
}

local encoded = codec.encode(state)
assert(encoded:sub(1, 2) == "3|")
assert(not encoded:find("[\r\n]"))
local decoded = assert(codec.decode(encoded))
assert(codec.encode(decoded) == encoded)
local composition = decoded.compositions[1]
assert(composition.anchor == 2.125 and composition.target_bars == 48)
assert(composition.revision == 3)
local build = composition.builds[1]
assert(build.seed == -4 and build.compiler_version == "3.0.0" and build.explanation == "Pickup 1; Main 高")
assert(build.composition_revision == 3)
assert(build.target_bars == 48 and build.achieved_bars == 49.25)
assert(build.source_palette[1].family == "Main")
assert(build.sequence[1].name == "Wide; 高" and build.sequence[1].lane == "A")

assert(codec.decode("").version == 3)
assert(codec.decode("3").version == 3)
for _, invalid in ipairs({
  "2|old",
  "4|future",
  "3|",
  "3|B;orphan",
  encoded .. "|",
  (encoded:gsub(";A$", ";C")),
  (encoded:gsub(";48;", ";0;", 1)),
}) do
  local value, error_code = codec.decode(invalid)
  assert(value == nil)
  assert(error_code == (invalid:match("^[24]") and "state_version_unsupported" or "state_invalid"))
end

print("V3 codec tests passed")
