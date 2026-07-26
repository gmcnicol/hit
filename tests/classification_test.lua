package.path = "src/?.lua;src/?/init.lua;" .. package.path

local classification = require("hit.app.classification")

local IDEA_ID = "{00000001-0000-0000-0000-000000000001}"
local SOURCE_A = "{10000001-0000-0000-0000-000000000001}"
local SOURCE_B = "{10000002-0000-0000-0000-000000000002}"
local next_id = 1
local commits = {}
local stored = {
  v1 = {
    version = 1,
    ideas = {
      { id = IDEA_ID, name = "Performance", source_item_guid = SOURCE_A },
    },
  },
}

local port = {
  load = function()
    return stored
  end,
  source_facts = function()
    return {
      [SOURCE_A] = {
        status = "available",
        track_name = "Guitar",
        item_name = "Verse item",
        take_name = "Take one",
        source_kind = "audio",
        position = 0,
        duration = 8,
      },
      [SOURCE_B] = { status = "unavailable", source_kind = "audio" },
    }
  end,
  selected_sources = function()
    return {
      { source_item_guid = SOURCE_B, source_kind = "audio", track_index = 2, position = 4 },
    }
  end,
  new_guid = function()
    next_id = next_id + 1
    return string.format("{200000%02X-0000-0000-0000-0000000000%02X}", next_id, next_id)
  end,
  commit = function(state, label)
    commits[#commits + 1] = label
    stored = { v1 = stored.v1, v2 = state }
    return true
  end,
  split_source = function(source_item_guid, label, build_next)
    assert(source_item_guid == SOURCE_A)
    assert(label == "HIT: Split Variant - Performance")
    local next_state, build_error = build_next("{10000003-0000-0000-0000-000000000003}")
    assert(next_state, build_error)
    stored = { v1 = stored.v1, v2 = next_state }
    commits[#commits + 1] = label
    return true
  end,
}

local view = assert(classification.open(port, IDEA_ID))
assert(view.version == 2 and not view.read_only)
assert(view.families.Main.variants[1].source.track_name == "Guitar")
assert(view.families.Main.variants[1].source.take_name == "Take one")

local added, add_error, outcome = classification.execute(port, IDEA_ID, { type = "bulk_add" })
assert(added, add_error)
assert(outcome.added == 1 and outcome.skipped == 0)
assert(#added.families.Main.variants == 2)
assert(added.families.Main.variants[2].source.status == "unavailable")
assert(commits[1] == "HIT: Add Main Variants - Performance")
assert(stored.v1.version == 1)

local component = added.families.Main.variants[1].component_id
local alternate = assert(classification.execute(port, IDEA_ID, {
  type = "alternate_use",
  component_id = component,
  family = "Pickup",
}))
assert(alternate.families.Main.variants[1].shared)
assert(alternate.families.Pickup.variants[1].shared)

local split_component = alternate.families.Main.variants[1].component_id
local split_view = assert(classification.execute(port, IDEA_ID, {
  type = "split",
  component_id = split_component,
}))
assert(#split_view.families.Main.variants == 3)
assert(split_view.families.Main.variants[1].component_id == split_component)
assert(split_view.families.Main.variants[3].source_item_guid == "{10000003-0000-0000-0000-000000000003}")

local failing_port = {
  load = port.load,
  source_facts = port.source_facts,
  new_guid = port.new_guid,
  commit = function()
    return nil, "state_write_failed"
  end,
}
local failed, failed_error = classification.execute(failing_port, IDEA_ID, {
  type = "set_intensity",
  component_id = component,
  intensity = 5,
})
assert(failed == nil and failed_error == "state_write_failed")
assert(stored.v2.ideas[1].families.Main.variants[1].intensity == nil)

local read_only = classification.open({
  load = function()
    return nil, "state_version_unsupported"
  end,
}, IDEA_ID)
assert(read_only.read_only and read_only.error == "state_version_unsupported")

print("classification service tests passed")
