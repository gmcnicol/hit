local idea = require("hit.model.idea")
local state_codec = require("hit.model.state_codec")

local codec = {}
local FAMILY = { Pickup = true, Main = true, Turnaround = true, Ending = true }

local function finite(value)
  return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function number(value)
  return string.format("%.17g", value)
end

local function fields(record, count)
  local result = {}
  for value in (record .. ";"):gmatch("(.-);") do
    result[#result + 1] = value
  end
  if #result ~= count then
    return nil
  end
  for index = 2, #result do
    result[index] = state_codec.unescape(result[index])
    if result[index] == nil then
      return nil
    end
  end
  return result
end

local function validate_sequence(sequence)
  assert(type(sequence) == "table" and #sequence > 0, "build sequence required")
  for _, phrase in ipairs(sequence) do
    assert(type(phrase) == "table", "phrase must be table")
    assert(idea.guid_is_valid(phrase.component_id), "phrase component_id must be GUID")
    assert(idea.guid_is_valid(phrase.source_item_guid), "phrase source_item_guid must be GUID")
    assert(FAMILY[phrase.family], "phrase family invalid")
    assert(type(phrase.label) == "string" and phrase.label ~= "", "phrase label required")
    assert(type(phrase.name) == "string", "phrase name required")
    assert(finite(phrase.position), "phrase position invalid")
    assert(finite(phrase.duration) and phrase.duration > 0, "phrase duration invalid")
    assert(finite(phrase.overlap) and phrase.overlap >= 0, "phrase overlap invalid")
    assert(phrase.lane == "A" or phrase.lane == "B", "phrase lane invalid")
  end
end

function codec.validate(state)
  assert(type(state) == "table" and state.version == 3, "V3 state required")
  assert(type(state.compositions) == "table", "compositions required")
  local compositions = {}
  local ideas = {}
  for _, composition in ipairs(state.compositions) do
    assert(type(composition) == "table", "composition must be table")
    assert(idea.guid_is_valid(composition.id), "composition id must be GUID")
    assert(not compositions[composition.id], "composition id must be unique")
    assert(idea.guid_is_valid(composition.idea_id), "composition idea_id must be GUID")
    assert(not ideas[composition.idea_id], "one composition per idea")
    assert(idea.guid_is_valid(composition.occurrence_id), "occurrence id must be GUID")
    assert(idea.guid_is_valid(composition.root_id), "root id must be GUID")
    assert(
      type(composition.revision) == "number" and composition.revision > 0 and composition.revision % 1 == 0,
      "composition revision invalid"
    )
    assert(
      type(composition.target_bars) == "number" and composition.target_bars > 0 and composition.target_bars % 1 == 0,
      "target bars invalid"
    )
    assert(finite(composition.anchor), "composition anchor invalid")
    assert(
      type(composition.compiler_version) == "string" and composition.compiler_version ~= "",
      "compiler version required"
    )
    assert(type(composition.builds) == "table", "composition builds required")
    compositions[composition.id] = true
    ideas[composition.idea_id] = true
    local builds = {}
    for _, build in ipairs(composition.builds) do
      assert(type(build) == "table", "build must be table")
      assert(idea.guid_is_valid(build.id), "build id must be GUID")
      assert(not builds[build.id], "build id must be unique")
      assert(idea.guid_is_valid(build.suggestion_id), "suggestion id must be GUID")
      assert(
        type(build.composition_revision) == "number"
          and build.composition_revision > 0
          and build.composition_revision % 1 == 0,
        "build composition revision invalid"
      )
      assert(type(build.seed) == "number" and build.seed % 1 == 0, "build seed must be integer")
      assert(
        type(build.compiler_version) == "string" and build.compiler_version ~= "",
        "build compiler version required"
      )
      assert(
        type(build.target_bars) == "number" and build.target_bars > 0 and build.target_bars % 1 == 0,
        "build target bars invalid"
      )
      assert(finite(build.target_duration) and build.target_duration > 0, "target duration invalid")
      assert(finite(build.achieved_duration) and build.achieved_duration > 0, "achieved duration invalid")
      assert(finite(build.achieved_bars) and build.achieved_bars > 0, "achieved bars invalid")
      assert(type(build.explanation) == "string", "explanation required")
      assert(type(build.source_palette) == "table", "source palette required")
      for _, source in ipairs(build.source_palette) do
        assert(idea.guid_is_valid(source.component_id), "palette component_id must be GUID")
        assert(idea.guid_is_valid(source.source_item_guid), "palette source_item_guid must be GUID")
        assert(FAMILY[source.family], "palette family invalid")
      end
      validate_sequence(build.sequence)
      builds[build.id] = true
    end
  end
  return true
end

function codec.encode(state)
  codec.validate(state)
  local records = { "3" }
  local escape = state_codec.escape
  for _, composition in ipairs(state.compositions) do
    records[#records + 1] = table.concat({
      "C",
      escape(composition.id),
      escape(composition.idea_id),
      escape(composition.occurrence_id),
      escape(composition.root_id),
      number(composition.revision),
      number(composition.target_bars),
      number(composition.anchor),
      escape(composition.compiler_version),
    }, ";")
    for _, build in ipairs(composition.builds) do
      records[#records + 1] = table.concat({
        "B",
        escape(build.id),
        escape(build.suggestion_id),
        number(build.composition_revision),
        number(build.seed),
        escape(build.compiler_version),
        number(build.target_bars),
        number(build.target_duration),
        number(build.achieved_duration),
        number(build.achieved_bars),
        escape(build.explanation),
      }, ";")
      for _, source in ipairs(build.source_palette) do
        records[#records + 1] = table.concat({
          "P",
          escape(source.component_id),
          escape(source.source_item_guid),
          escape(source.family),
        }, ";")
      end
      for _, phrase in ipairs(build.sequence) do
        records[#records + 1] = table.concat({
          "Q",
          escape(phrase.component_id),
          escape(phrase.source_item_guid),
          escape(phrase.family),
          escape(phrase.label),
          escape(phrase.name),
          number(phrase.position),
          number(phrase.duration),
          number(phrase.overlap),
          phrase.lane,
        }, ";")
      end
    end
  end
  return table.concat(records, "|")
end

local function invalid()
  return nil, "state_invalid"
end

function codec.decode(value)
  if value == nil or value == "" or value == "3" then
    return { version = 3, compositions = {} }
  end
  if type(value) == "string" then
    local version = value:match("^(%d+)$") or value:match("^(%d+)|")
    if version and version ~= "3" then
      return nil, "state_version_unsupported"
    end
  end
  if type(value) ~= "string" or value:sub(1, 2) ~= "3|" or value:sub(-1) == "|" then
    return invalid()
  end

  local state = { version = 3, compositions = {} }
  local composition
  local build
  for record in (value:sub(3) .. "|"):gmatch("(.-)|") do
    local kind = record:sub(1, 1)
    if kind == "C" then
      local values = fields(record, 9)
      if not values then
        return invalid()
      end
      composition = {
        id = values[2],
        idea_id = values[3],
        occurrence_id = values[4],
        root_id = values[5],
        revision = tonumber(values[6]),
        target_bars = tonumber(values[7]),
        anchor = tonumber(values[8]),
        compiler_version = values[9],
        builds = {},
      }
      state.compositions[#state.compositions + 1] = composition
      build = nil
    elseif kind == "B" and composition then
      local values = fields(record, 11)
      if not values then
        return invalid()
      end
      build = {
        id = values[2],
        suggestion_id = values[3],
        composition_revision = tonumber(values[4]),
        seed = tonumber(values[5]),
        compiler_version = values[6],
        target_bars = tonumber(values[7]),
        target_duration = tonumber(values[8]),
        achieved_duration = tonumber(values[9]),
        achieved_bars = tonumber(values[10]),
        explanation = values[11],
        source_palette = {},
        sequence = {},
      }
      composition.builds[#composition.builds + 1] = build
    elseif kind == "P" and build then
      local values = fields(record, 4)
      if not values then
        return invalid()
      end
      build.source_palette[#build.source_palette + 1] = {
        component_id = values[2],
        source_item_guid = values[3],
        family = values[4],
      }
    elseif kind == "Q" and build then
      local values = fields(record, 10)
      if not values then
        return invalid()
      end
      build.sequence[#build.sequence + 1] = {
        component_id = values[2],
        source_item_guid = values[3],
        family = values[4],
        label = values[5],
        name = values[6],
        position = tonumber(values[7]),
        duration = tonumber(values[8]),
        overlap = tonumber(values[9]),
        lane = values[10],
      }
    else
      return invalid()
    end
  end

  local ok = pcall(codec.validate, state)
  if not ok then
    return invalid()
  end
  return state
end

return codec
