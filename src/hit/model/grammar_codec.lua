local state_codec = require("hit.model.state_codec")
local grammar = require("hit.model.grammar")

local codec = {}

local function boolean(value)
  return value and "1" or "0"
end

local function parse_boolean(value)
  if value == "1" then
    return true
  end
  if value == "0" then
    return false
  end
end

local function split(value, separator)
  local result = {}
  local start = 1
  while true do
    local boundary = value:find(separator, start, true)
    if not boundary then
      result[#result + 1] = value:sub(start)
      return result
    end
    result[#result + 1] = value:sub(start, boundary - 1)
    start = boundary + #separator
  end
end

local function allowed_next_text(rules)
  local values = {}
  for _, family_name in ipairs(grammar.FAMILY_ORDER) do
    if rules.allowed_next[family_name] then
      values[#values + 1] = family_name
    end
  end
  return table.concat(values, ",")
end

local function encode_rules(fields, rules)
  fields[#fields + 1] = boolean(rules.may_begin)
  fields[#fields + 1] = boolean(rules.may_repeat)
  fields[#fields + 1] = boolean(rules.may_end)
  fields[#fields + 1] = boolean(rules.may_overlap)
  fields[#fields + 1] = state_codec.escape(allowed_next_text(rules))
end

local function decode_rules(fields, offset)
  local rules = {
    may_begin = parse_boolean(fields[offset]),
    may_repeat = parse_boolean(fields[offset + 1]),
    may_end = parse_boolean(fields[offset + 2]),
    may_overlap = parse_boolean(fields[offset + 3]),
    allowed_next = {},
  }
  if rules.may_begin == nil or rules.may_repeat == nil or rules.may_end == nil or rules.may_overlap == nil then
    return nil
  end
  local allowed = state_codec.unescape(fields[offset + 4])
  if not allowed then
    return nil
  end
  if allowed ~= "" then
    for _, family_name in ipairs(split(allowed, ",")) do
      rules.allowed_next[family_name] = true
    end
  end
  if not grammar.rules_are_valid(rules) then
    return nil
  end
  return rules
end

function codec.encode(state)
  grammar.validate(state)
  local records = { "2" }
  for _, current_idea in ipairs(state.ideas) do
    records[#records + 1] = table.concat({
      "I",
      state_codec.escape(current_idea.id),
      state_codec.escape(current_idea.name),
    }, ";")
    for _, family_name in ipairs(grammar.FAMILY_ORDER) do
      local family = current_idea.families[family_name]
      local fields = {
        "F",
        state_codec.escape(current_idea.id),
        family_name,
        state_codec.escape(family.default_component_id or ""),
      }
      encode_rules(fields, family.grammar)
      records[#records + 1] = table.concat(fields, ";")
      for _, variant in ipairs(family.variants) do
        fields = {
          "V",
          state_codec.escape(current_idea.id),
          family_name,
          state_codec.escape(variant.component_id),
          variant.label,
          state_codec.escape(variant.source_item_guid),
          state_codec.escape(variant.name),
          variant.intensity and tostring(variant.intensity) or "",
          variant.grammar_override and "override" or "inherit",
        }
        if variant.grammar_override then
          encode_rules(fields, variant.grammar_override)
        else
          for _ = 1, 5 do
            fields[#fields + 1] = ""
          end
        end
        records[#records + 1] = table.concat(fields, ";")
      end
    end
    for _, fingerprint in ipairs(current_idea.dismissed_recoveries) do
      records[#records + 1] = table.concat({
        "D",
        state_codec.escape(current_idea.id),
        state_codec.escape(fingerprint),
      }, ";")
    end
  end
  return table.concat(records, "|")
end

function codec.decode(value)
  if type(value) ~= "string" then
    return nil, "state_invalid"
  end
  local version = value:match("^(%d+)$") or value:match("^(%d+)|")
  if version and version ~= "2" then
    return nil, "state_version_unsupported"
  end
  if value == "2" then
    return { version = 2, ideas = {} }
  end
  if value:sub(1, 2) ~= "2|" or value:sub(-1) == "|" then
    return nil, "state_invalid"
  end

  local state = { version = 2, ideas = {} }
  local by_id = {}
  for record in (value:sub(3) .. "|"):gmatch("(.-)|") do
    local fields = split(record, ";")
    local record_type = fields[1]
    if record_type == "I" and #fields == 3 then
      local idea_id = state_codec.unescape(fields[2])
      local name = state_codec.unescape(fields[3])
      if not idea_id or not name or by_id[idea_id] then
        return nil, "state_invalid"
      end
      local current = {
        id = idea_id,
        name = name,
        families = {},
        dismissed_recoveries = {},
      }
      state.ideas[#state.ideas + 1] = current
      by_id[idea_id] = current
    elseif record_type == "F" and #fields == 9 then
      local idea_id = state_codec.unescape(fields[2])
      local current = idea_id and by_id[idea_id]
      local default_component_id = state_codec.unescape(fields[4])
      local rules = decode_rules(fields, 5)
      if not current or current.families[fields[3]] or default_component_id == nil or not rules then
        return nil, "state_invalid"
      end
      current.families[fields[3]] = {
        grammar = rules,
        default_component_id = default_component_id ~= "" and default_component_id or nil,
        variants = {},
      }
    elseif record_type == "V" and #fields == 14 then
      local idea_id = state_codec.unescape(fields[2])
      local current = idea_id and by_id[idea_id]
      local family = current and current.families[fields[3]]
      local component_id = state_codec.unescape(fields[4])
      local source_item_guid = state_codec.unescape(fields[6])
      local name = state_codec.unescape(fields[7])
      local intensity = fields[8] ~= "" and tonumber(fields[8]) or nil
      local override
      if fields[9] == "override" then
        override = decode_rules(fields, 10)
      elseif
        fields[9] ~= "inherit"
        or fields[10] ~= ""
        or fields[11] ~= ""
        or fields[12] ~= ""
        or fields[13] ~= ""
        or fields[14] ~= ""
      then
        return nil, "state_invalid"
      end
      if
        not family
        or not component_id
        or not source_item_guid
        or not name
        or (fields[8] ~= "" and not intensity)
        or (fields[9] == "override" and not override)
      then
        return nil, "state_invalid"
      end
      family.variants[#family.variants + 1] = {
        component_id = component_id,
        source_item_guid = source_item_guid,
        label = fields[5],
        name = name,
        intensity = intensity,
        grammar_override = override,
      }
    elseif record_type == "D" and #fields == 3 then
      local idea_id = state_codec.unescape(fields[2])
      local fingerprint = state_codec.unescape(fields[3])
      local current = idea_id and by_id[idea_id]
      if not current or not fingerprint then
        return nil, "state_invalid"
      end
      current.dismissed_recoveries[#current.dismissed_recoveries + 1] = fingerprint
    else
      return nil, "state_invalid"
    end
  end

  local valid = pcall(grammar.validate, state)
  if not valid then
    return nil, "state_invalid"
  end
  return state
end

return codec
