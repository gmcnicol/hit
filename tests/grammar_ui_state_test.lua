package.path = "src/?.lua;src/?/init.lua;" .. package.path

local grammar_ui = require("hit.ui.imgui.grammar")

local selected_source = "{10000001-0000-0000-0000-000000000001}"
local view = {
  families = {
    Pickup = {
      variants = {
        { component_id = "pickup-a", source_item_guid = selected_source },
      },
    },
    Main = {
      variants = {
        { component_id = "main-a", source_item_guid = selected_source },
        { component_id = "main-b", source_item_guid = "other" },
      },
    },
    Turnaround = { variants = {} },
    Ending = { variants = {} },
  },
}

local state = {
  selected_family = "Main",
  selected_component_id = "main-b",
  name_draft = "stale",
}
grammar_ui.select_source_variant(view, state, selected_source)
assert(state.selected_family == "Main")
assert(state.selected_component_id == "main-a")
assert(state.name_draft == "")

state.selected_family = "Pickup"
state.selected_component_id = "pickup-a"
grammar_ui.select_source_variant(view, state, selected_source)
assert(state.selected_family == "Pickup")
assert(state.selected_component_id == "pickup-a")

grammar_ui.select_source_variant(view, state, "unclassified")
assert(state.selected_component_id == "pickup-a")
grammar_ui.select_source_variant({ families = {} }, state, selected_source)
assert(state.selected_component_id == "pickup-a")

print("Grammar UI state tests passed")
