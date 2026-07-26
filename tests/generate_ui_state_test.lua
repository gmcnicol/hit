package.path = "src/?.lua;src/?/init.lua;" .. package.path

local view = require("hit.ui.imgui.generate")

local sequence = {
  { family = "Pickup", label = "A", name = "Breath", overlap = 0 },
  { family = "Main", label = "A", name = "", overlap = 0.5 },
}
assert(view.sequence_text(sequence) == "Pickup Breath  >  Main A (overlap)")
assert(view.request_seed({ builds = {}, seed = 1, next_seed = 1 }, 1) == 1)
assert(view.request_seed({ builds = { {} }, seed = 4, next_seed = 5 }, 4) == 5)
assert(view.request_seed({ builds = { {} }, seed = 4, next_seed = 5 }, 20) == 20)

print("generate UI state tests passed")
