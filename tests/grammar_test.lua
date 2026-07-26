package.path = "src/?.lua;src/?/init.lua;" .. package.path

local grammar = require("hit.model.grammar")

local IDEA_ID = "{00000001-0000-0000-0000-000000000001}"
local SOURCE_A = "{10000001-0000-0000-0000-000000000001}"
local SOURCE_B = "{10000002-0000-0000-0000-000000000002}"
local SOURCE_C = "{10000003-0000-0000-0000-000000000003}"
local COMPONENT_B = "{20000002-0000-0000-0000-000000000002}"
local COMPONENT_C = "{20000003-0000-0000-0000-000000000003}"
local COMPONENT_D = "{20000004-0000-0000-0000-000000000004}"

local function legacy()
  return grammar.from_v1({
    version = 1,
    ideas = {
      { id = IDEA_ID, name = "Long performance", source_item_guid = SOURCE_A },
    },
  })
end

local state = legacy()
local current = assert(grammar.idea(state, IDEA_ID))
assert(#current.families.Main.variants == 1)
assert(current.families.Main.variants[1].label == "A")
assert(current.families.Main.variants[1].source_item_guid == SOURCE_A)
assert(current.families.Main.default_component_id == current.families.Main.variants[1].component_id)
assert(#current.families.Pickup.variants == 0)
assert(current.families.Pickup.grammar.may_begin)
assert(current.families.Pickup.grammar.allowed_next.Main)
assert(current.families.Main.grammar.may_begin and current.families.Main.grammar.may_end)
assert(not current.families.Main.grammar.may_repeat)
assert(current.families.Main.grammar.allowed_next.Main)
assert(current.families.Main.grammar.allowed_next.Turnaround)
assert(current.families.Main.grammar.allowed_next.Ending)
local stable_component_id = current.families.Main.variants[1].component_id
assert(grammar.from_v1({
  version = 1,
  ideas = {
    { id = IDEA_ID, name = "Long performance", source_item_guid = SOURCE_A },
  },
}).ideas[1].families.Main.variants[1].component_id == stable_component_id)

local bulk, bulk_error, bulk_label, bulk_outcome = grammar.apply(state, IDEA_ID, {
  type = "bulk_add",
  sources = {
    { source_item_guid = SOURCE_C, track_index = 2, position = 1 },
    { source_item_guid = SOURCE_A, track_index = 1, position = 0 },
    { source_item_guid = SOURCE_B, track_index = 1, position = 4 },
  },
}, { COMPONENT_B, COMPONENT_C, COMPONENT_D })
assert(bulk, bulk_error)
assert(bulk_label == "HIT: Add Main Variants - Long performance")
assert(bulk_outcome.added == 2 and bulk_outcome.skipped == 1)
local main = bulk.ideas[1].families.Main
assert(#main.variants == 3)
assert(main.variants[1].label == "A" and main.variants[1].source_item_guid == SOURCE_A)
assert(main.variants[2].label == "B" and main.variants[2].source_item_guid == SOURCE_B)
assert(main.variants[3].label == "C" and main.variants[3].source_item_guid == SOURCE_C)
assert(#state.ideas[1].families.Main.variants == 1)

local moved = assert(grammar.apply(bulk, IDEA_ID, {
  type = "move",
  component_id = main.variants[2].component_id,
  family = "Pickup",
}))
assert(#moved.ideas[1].families.Pickup.variants == 1)
assert(moved.ideas[1].families.Pickup.default_component_id == main.variants[2].component_id)
assert(moved.ideas[1].families.Pickup.variants[1].label == "B")

local default_b = assert(grammar.apply(bulk, IDEA_ID, {
  type = "set_default",
  component_id = bulk.ideas[1].families.Main.variants[2].component_id,
}))
local moved_default = assert(grammar.apply(default_b, IDEA_ID, {
  type = "move",
  component_id = default_b.ideas[1].families.Main.variants[2].component_id,
  family = "Pickup",
}))
assert(
  moved_default.ideas[1].families.Main.default_component_id
    == moved_default.ideas[1].families.Main.variants[1].component_id
)

local collision_state = grammar.from_v1({
  version = 1,
  ideas = {
    { id = IDEA_ID, name = "Collision", source_item_guid = SOURCE_A },
  },
})
collision_state = assert(grammar.apply(collision_state, IDEA_ID, {
  type = "bulk_add",
  sources = {
    { source_item_guid = SOURCE_B, track_index = 1, position = 1 },
  },
}, { COMPONENT_B }))
collision_state.ideas[1].families.Ending.variants[1] = {
  component_id = COMPONENT_C,
  source_item_guid = SOURCE_C,
  label = "A",
  name = "",
  intensity = nil,
  grammar_override = nil,
}
collision_state.ideas[1].families.Ending.default_component_id = COMPONENT_C
grammar.validate(collision_state)
local collision_move = assert(grammar.apply(collision_state, IDEA_ID, {
  type = "move",
  component_id = collision_state.ideas[1].families.Main.variants[1].component_id,
  family = "Ending",
}))
assert(collision_move.ideas[1].families.Ending.variants[1].label == "A")
assert(collision_move.ideas[1].families.Ending.variants[2].label == "B")

local alternate = assert(grammar.apply(moved, IDEA_ID, {
  type = "alternate_use",
  component_id = stable_component_id,
  family = "Turnaround",
}, { COMPONENT_D }))
assert(alternate.ideas[1].families.Turnaround.variants[1].source_item_guid == SOURCE_A)
assert(alternate.ideas[1].families.Turnaround.variants[1].component_id == COMPONENT_D)

local duplicate, duplicate_error = grammar.apply(alternate, IDEA_ID, {
  type = "alternate_use",
  component_id = stable_component_id,
  family = "Turnaround",
}, { "{20000005-0000-0000-0000-000000000005}" })
assert(duplicate == nil and duplicate_error == "source_already_classified")

local renamed = assert(grammar.apply(alternate, IDEA_ID, {
  type = "set_name",
  component_id = stable_component_id,
  name = "  restrained  ",
}))
assert(renamed.ideas[1].families.Main.variants[1].name == "restrained")

for intensity = 1, 5 do
  local changed = assert(grammar.apply(alternate, IDEA_ID, {
    type = "set_intensity",
    component_id = stable_component_id,
    intensity = intensity,
  }))
  assert(changed.ideas[1].families.Main.variants[1].intensity == intensity)
end
local unset = assert(grammar.apply(alternate, IDEA_ID, {
  type = "set_intensity",
  component_id = stable_component_id,
  intensity = nil,
}))
assert(unset.ideas[1].families.Main.variants[1].intensity == nil)
local invalid_intensity, intensity_error = grammar.apply(alternate, IDEA_ID, {
  type = "set_intensity",
  component_id = stable_component_id,
  intensity = 6,
})
assert(invalid_intensity == nil and intensity_error == "intensity_invalid")

local custom_rules = {
  may_begin = false,
  may_repeat = true,
  may_end = false,
  may_overlap = true,
  allowed_next = { Pickup = true, Ending = true },
}
local family_rules = assert(grammar.apply(alternate, IDEA_ID, {
  type = "set_family_grammar",
  component_id = stable_component_id,
  grammar = custom_rules,
}))
assert(family_rules.ideas[1].families.Main.grammar.allowed_next.Pickup)
local empty_family_rules = assert(grammar.apply(family_rules, IDEA_ID, {
  type = "set_family_grammar",
  family = "Ending",
  grammar = custom_rules,
}))
assert(#empty_family_rules.ideas[1].families.Ending.variants == 0)
assert(empty_family_rules.ideas[1].families.Ending.grammar.may_repeat)
local variant_rules = assert(grammar.apply(family_rules, IDEA_ID, {
  type = "set_variant_grammar",
  component_id = stable_component_id,
  grammar = custom_rules,
}))
assert(variant_rules.ideas[1].families.Main.variants[1].grammar_override.may_repeat)
local inherited = assert(grammar.apply(variant_rules, IDEA_ID, {
  type = "inherit_family_grammar",
  component_id = stable_component_id,
}))
assert(inherited.ideas[1].families.Main.variants[1].grammar_override == nil)

local split = assert(grammar.apply(inherited, IDEA_ID, {
  type = "split",
  component_id = stable_component_id,
  source_item_guid = "{10000004-0000-0000-0000-000000000004}",
}, { "{20000005-0000-0000-0000-000000000005}" }))
assert(split.ideas[1].families.Main.variants[1].component_id == stable_component_id)
assert(split.ideas[1].families.Main.variants[1].source_item_guid == SOURCE_A)
assert(split.ideas[1].families.Main.variants[3].label == "B")
assert(split.ideas[1].families.Main.variants[3].source_item_guid == "{10000004-0000-0000-0000-000000000004}")

local sole_main, main_error = grammar.apply(state, IDEA_ID, {
  type = "move",
  component_id = stable_component_id,
  family = "Ending",
})
assert(sole_main == nil and main_error == "main_required")

print("grammar model tests passed")
