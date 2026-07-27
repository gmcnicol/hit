package.path = "src/?.lua;src/?/init.lua;" .. package.path

local generation = require("hit.app.generation")

local IDEA_ID = "{00000001-0000-0000-0000-000000000001}"
local next_id = 1

local main_rules = {
  may_begin = true,
  may_repeat = true,
  may_end = true,
  may_overlap = false,
  allowed_next = { Main = true },
}

local state = { version = 3, compositions = {} }
local published
local cursor = 2.5
local palette = {
  {
    family = "Main",
    component_id = "{20000001-0000-0000-0000-000000000001}",
    source_item_guid = "{10000001-0000-0000-0000-000000000001}",
    label = "A",
    name = "",
    default = true,
    duration = 4,
    family_grammar = main_rules,
  },
  {
    family = "Main",
    component_id = "{20000002-0000-0000-0000-000000000002}",
    source_item_guid = "{10000002-0000-0000-0000-000000000002}",
    label = "B",
    name = "Lift",
    default = false,
    duration = 6,
    family_grammar = main_rules,
  },
}

local port = {
  load = function(idea_id)
    assert(idea_id == IDEA_ID)
    return {
      idea = { id = IDEA_ID, name = "Riff", families = {} },
      v3 = state,
      palette = palette,
      source_summary = { present = 2, gone = 1, ambiguous = 0, offline = 1 },
    }
  end,
  cursor = function()
    return cursor
  end,
  measure_boundaries = function(anchor, bars)
    local result = {}
    for index = 0, bars do
      result[index + 1] = anchor + index * 4
    end
    return result
  end,
  bars_for_span = function(_, duration)
    return duration / 4
  end,
  new_guid = function()
    local id = string.format("{%08X-0000-0000-0000-000000000000}", next_id)
    next_id = next_id + 1
    return id
  end,
  publish = function(next_state, composition, build, source_palette)
    state = next_state
    published = { composition = composition, build = build, palette = source_palette }
    return true
  end,
}

local initial = generation.open(port, IDEA_ID)
assert(initial.target_bars == 48 and initial.seed == 1 and initial.next_seed == 1)
assert(initial.classified and initial.source_summary.offline == 1)

local invalid, invalid_error = generation.execute(port, IDEA_ID, 0, 1)
assert(invalid == nil and invalid_error == "target_bars_invalid")
invalid, invalid_error = generation.execute(port, IDEA_ID, 48.5, 1)
assert(invalid == nil and invalid_error == "target_bars_invalid")
invalid, invalid_error = generation.execute(port, IDEA_ID, 48, 1.5)
assert(invalid == nil and invalid_error == "seed_invalid")

local generated = assert(generation.execute(port, IDEA_ID, 12, 4))
assert(generated.target_bars == 12 and generated.seed == 4 and generated.next_seed == 5)
assert(#generated.builds == 1)
assert(published.composition.anchor == cursor)
assert(published.composition.revision == 1 and published.build.composition_revision == 1)
assert(published.build.target_bars == 12 and published.build.compiler_version == "3.0.0")
assert(published.build.achieved_bars == published.build.achieved_duration / 4)
assert(#published.build.source_palette == 2 and #published.build.sequence > 1)
local first_composition_id = published.composition.id
local first_occurrence_id = published.composition.occurrence_id
local first_root_id = published.composition.root_id
local first_build = published.build

cursor = 99
local another = assert(generation.execute(port, IDEA_ID, 10, 5))
assert(#another.builds == 2)
assert(published.composition.anchor == 2.5)
assert(published.composition.id == first_composition_id)
assert(published.composition.occurrence_id == first_occurrence_id)
assert(published.composition.root_id == first_root_id)
assert(published.composition.revision == 2 and published.build.composition_revision == 2)
assert(published.composition.builds[1] == first_build)

local unavailable_port = {}
for key, value in pairs(port) do
  unavailable_port[key] = value
end
unavailable_port.load = function()
  return {
    idea = { id = IDEA_ID, name = "Gone" },
    v3 = { version = 3, compositions = {} },
    palette = {},
    source_summary = { present = 0, gone = 1, ambiguous = 0, offline = 0 },
  }
end
local missing, missing_error = generation.execute(unavailable_port, IDEA_ID, 48, 1)
assert(missing == nil and missing_error == "no_legal_start")

local read_only = generation.open({
  load = function()
    return nil, "state_version_unsupported"
  end,
}, IDEA_ID)
assert(read_only.read_only and read_only.error == "state_version_unsupported")

print("generation application tests passed")
