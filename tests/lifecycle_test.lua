package.path = "src/?.lua;src/?/init.lua;" .. package.path

local lifecycle = require("hit.lifecycle")

local active = lifecycle.project_access(true, true)
assert(active.should_close == false)
assert(active.can_mutate == true)

local inactive = lifecycle.project_access(true, false)
assert(inactive.should_close == false)
assert(inactive.can_mutate == false)

local closed = lifecycle.project_access(false, false)
assert(closed.should_close == true)
assert(closed.can_mutate == false)

local supported = lifecycle.host_support("7.78/arm64", true)
assert(supported.ok == true)

local old_reaper = lifecycle.host_support("6.83/arm64", true)
assert(old_reaper.ok == false)
assert(old_reaper.error == "reaper_version")

local missing_imgui = lifecycle.host_support("7.78/arm64", false)
assert(missing_imgui.ok == false)
assert(missing_imgui.error == "reaimgui_missing")

print("lifecycle tests passed")
