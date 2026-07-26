local idea = require("hit.model.idea")

local grammar = {}

grammar.FAMILY_ORDER = { "Pickup", "Main", "Turnaround", "Ending" }

local FAMILY_SET = {}
for _, family_name in ipairs(grammar.FAMILY_ORDER) do
  FAMILY_SET[family_name] = true
end

local DEFAULT_GRAMMAR = {
  Pickup = {
    may_begin = true,
    may_repeat = false,
    may_end = false,
    may_overlap = false,
    allowed_next = { Main = true },
  },
  Main = {
    may_begin = true,
    may_repeat = false,
    may_end = true,
    may_overlap = false,
    allowed_next = { Main = true, Turnaround = true, Ending = true },
  },
  Turnaround = {
    may_begin = false,
    may_repeat = false,
    may_end = true,
    may_overlap = false,
    allowed_next = { Main = true, Ending = true },
  },
  Ending = {
    may_begin = false,
    may_repeat = false,
    may_end = true,
    may_overlap = false,
    allowed_next = {},
  },
}

local function copy_rules(rules)
  local allowed_next = {}
  for family_name, allowed in pairs(rules.allowed_next) do
    if allowed then
      allowed_next[family_name] = true
    end
  end
  return {
    may_begin = rules.may_begin,
    may_repeat = rules.may_repeat,
    may_end = rules.may_end,
    may_overlap = rules.may_overlap,
    allowed_next = allowed_next,
  }
end

local function copy_variant(variant)
  return {
    component_id = variant.component_id,
    source_item_guid = variant.source_item_guid,
    label = variant.label,
    name = variant.name,
    intensity = variant.intensity,
    grammar_override = variant.grammar_override and copy_rules(variant.grammar_override) or nil,
  }
end

local function copy_state(state)
  local result = { version = 2, ideas = {} }
  for idea_index, current_idea in ipairs(state.ideas) do
    local next_idea = {
      id = current_idea.id,
      name = current_idea.name,
      families = {},
      dismissed_recoveries = {},
    }
    for _, family_name in ipairs(grammar.FAMILY_ORDER) do
      local current_family = current_idea.families[family_name]
      local next_family = {
        grammar = copy_rules(current_family.grammar),
        default_component_id = current_family.default_component_id,
        variants = {},
      }
      for variant_index, variant in ipairs(current_family.variants) do
        next_family.variants[variant_index] = copy_variant(variant)
      end
      next_idea.families[family_name] = next_family
    end
    for index, fingerprint in ipairs(current_idea.dismissed_recoveries or {}) do
      next_idea.dismissed_recoveries[index] = fingerprint
    end
    result.ideas[idea_index] = next_idea
  end
  return result
end

local function new_families()
  local families = {}
  for _, family_name in ipairs(grammar.FAMILY_ORDER) do
    families[family_name] = {
      grammar = copy_rules(DEFAULT_GRAMMAR[family_name]),
      default_component_id = nil,
      variants = {},
    }
  end
  return families
end

local function derived_component_id(idea_id)
  local first = tonumber(idea_id:sub(2, 2), 16)
  return "{" .. string.format("%X", first ~ 8) .. idea_id:sub(3)
end

function grammar.component_id_for_idea(idea_id)
  assert(idea.guid_is_valid(idea_id), "idea_id must be GUID")
  return derived_component_id(idea_id)
end

local function new_grammar_idea(v1_idea, component_id)
  local families = new_families()
  families.Main.variants[1] = {
    component_id = component_id,
    source_item_guid = v1_idea.source_item_guid,
    label = "A",
    name = "",
    intensity = nil,
    grammar_override = nil,
  }
  families.Main.default_component_id = component_id
  return {
    id = v1_idea.id,
    name = v1_idea.name,
    families = families,
    dismissed_recoveries = {},
  }
end

function grammar.from_v1(v1_state)
  assert(type(v1_state) == "table" and v1_state.version == 1, "V1 state required")
  local result = { version = 2, ideas = {} }
  for index, current in ipairs(v1_state.ideas) do
    result.ideas[index] = new_grammar_idea(current, derived_component_id(current.id))
  end
  grammar.validate(result)
  return result
end

function grammar.add_created_idea(state, v1_idea, component_id)
  assert(idea.guid_is_valid(component_id), "component_id must be GUID")
  local result = copy_state(state)
  result.ideas[#result.ideas + 1] = new_grammar_idea(v1_idea, component_id)
  grammar.validate(result)
  return result
end

local function array_is_contiguous(values)
  local count = 0
  for key in pairs(values) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
  end
  return count == #values
end

local function rules_are_valid(rules)
  if type(rules) ~= "table"
    or type(rules.may_begin) ~= "boolean"
    or type(rules.may_repeat) ~= "boolean"
    or type(rules.may_end) ~= "boolean"
    or type(rules.may_overlap) ~= "boolean"
    or type(rules.allowed_next) ~= "table"
  then
    return false
  end
  for family_name, allowed in pairs(rules.allowed_next) do
    if not FAMILY_SET[family_name] or allowed ~= true then
      return false
    end
  end
  return true
end

local function optional_name_is_valid(name)
  return type(name) == "string"
    and (name == "" or name == name:match("^%s*(.-)%s*$"))
    and not name:find("[%z\1-\31\127]")
end

function grammar.validate(state)
  assert(type(state) == "table" and state.version == 2, "grammar state version must be 2")
  assert(type(state.ideas) == "table" and array_is_contiguous(state.ideas), "grammar ideas must be array")

  local idea_ids = {}
  local component_ids = {}
  for _, current_idea in ipairs(state.ideas) do
    assert(type(current_idea) == "table", "grammar idea must be table")
    assert(idea.guid_is_valid(current_idea.id) and not idea_ids[current_idea.id], "grammar idea id must be unique GUID")
    local valid_idea_name = type(current_idea.name) == "string"
      and current_idea.name ~= ""
      and optional_name_is_valid(current_idea.name)
    assert(valid_idea_name, "grammar idea name must be valid")
    assert(type(current_idea.families) == "table", "grammar families must be table")
    assert(
      type(current_idea.dismissed_recoveries) == "table"
        and array_is_contiguous(current_idea.dismissed_recoveries),
      "dismissed recoveries must be array"
    )
    for _, fingerprint in ipairs(current_idea.dismissed_recoveries) do
      assert(type(fingerprint) == "string" and fingerprint ~= "", "recovery fingerprint must be non-empty")
    end
    idea_ids[current_idea.id] = true

    local family_count = 0
    for family_name in pairs(current_idea.families) do
      assert(FAMILY_SET[family_name], "unknown phrase family")
      family_count = family_count + 1
    end
    assert(family_count == #grammar.FAMILY_ORDER, "all phrase families required")

    for _, family_name in ipairs(grammar.FAMILY_ORDER) do
      local family = current_idea.families[family_name]
      assert(type(family) == "table", "phrase family required")
      assert(rules_are_valid(family.grammar), "family grammar invalid")
      assert(type(family.variants) == "table" and array_is_contiguous(family.variants), "family variants must be array")
      assert(
        (#family.variants == 0 and family.default_component_id == nil)
          or (#family.variants > 0 and idea.guid_is_valid(family.default_component_id)),
        "family default invalid"
      )

      local labels = {}
      local sources = {}
      local default_found = false
      for _, variant in ipairs(family.variants) do
        assert(type(variant) == "table", "variant must be table")
        assert(
          idea.guid_is_valid(variant.component_id) and not component_ids[variant.component_id],
          "component id must be unique GUID"
        )
        assert(idea.guid_is_valid(variant.source_item_guid), "variant source must be GUID")
        assert(type(variant.label) == "string" and variant.label:match("^[A-Z]+$"), "variant label invalid")
        assert(not labels[variant.label], "variant label must be unique within family")
        assert(not sources[variant.source_item_guid], "source may appear once within family")
        assert(optional_name_is_valid(variant.name), "variant name invalid")
        assert(
          variant.intensity == nil
            or (type(variant.intensity) == "number"
              and variant.intensity % 1 == 0
              and variant.intensity >= 1
              and variant.intensity <= 5),
          "variant intensity invalid"
        )
        assert(variant.grammar_override == nil or rules_are_valid(variant.grammar_override), "variant grammar override invalid")
        component_ids[variant.component_id] = true
        labels[variant.label] = true
        sources[variant.source_item_guid] = true
        default_found = default_found or family.default_component_id == variant.component_id
      end
      assert(#family.variants == 0 or default_found, "family default must identify variant")
    end
    assert(#current_idea.families.Main.variants > 0, "Main family must contain a Variant")
  end
  return true
end

local function find_idea(state, idea_id)
  for _, current in ipairs(state.ideas) do
    if current.id == idea_id then
      return current
    end
  end
end

local function find_variant(current_idea, component_id)
  for _, family_name in ipairs(grammar.FAMILY_ORDER) do
    local family = current_idea.families[family_name]
    for index, variant in ipairs(family.variants) do
      if variant.component_id == component_id then
        return variant, family, family_name, index
      end
    end
  end
end

local function next_label(family)
  local used = {}
  for _, variant in ipairs(family.variants) do
    used[variant.label] = true
  end
  local number = 1
  while true do
    local value = number
    local label = ""
    while value > 0 do
      value = value - 1
      label = string.char(65 + value % 26) .. label
      value = math.floor(value / 26)
    end
    if not used[label] then
      return label
    end
    number = number + 1
  end
end

local function source_in_family(family, source_item_guid)
  for _, variant in ipairs(family.variants) do
    if variant.source_item_guid == source_item_guid then
      return true
    end
  end
  return false
end

local function label_in_family(family, label)
  for _, variant in ipairs(family.variants) do
    if variant.label == label then
      return true
    end
  end
  return false
end

local function repair_default(family)
  if #family.variants == 0 then
    family.default_component_id = nil
  elseif family.default_component_id == nil then
    family.default_component_id = family.variants[1].component_id
  end
end

local function command_label(command, current_idea)
  local labels = {
    bulk_add = "HIT: Add Main Variants",
    move = "HIT: Move Variant",
    alternate_use = "HIT: Add Alternate Use",
    set_default = "HIT: Set Default Variant",
    set_name = "HIT: Name Variant",
    set_intensity = "HIT: Set Variant Intensity",
    set_family_grammar = "HIT: Edit Family Phrase Rules",
    set_variant_grammar = "HIT: Edit Variant Phrase Rules",
    inherit_family_grammar = "HIT: Inherit Family Phrase Rules",
    split = "HIT: Split Variant",
    attach_recovery = "HIT: Attach Split Recovery",
    dismiss_recovery = "HIT: Dismiss Split Recovery",
  }
  return labels[command.type] and (labels[command.type] .. " - " .. current_idea.name) or nil
end

function grammar.apply(state, idea_id, command, generated_ids)
  grammar.validate(state)
  assert(type(command) == "table" and type(command.type) == "string", "command required")
  generated_ids = generated_ids or {}

  local result = copy_state(state)
  local current_idea = find_idea(result, idea_id)
  if not current_idea then
    return nil, "idea_missing"
  end
  local label = command_label(command, current_idea)
  if not label then
    return nil, "command_unsupported"
  end

  if command.type == "bulk_add" then
    if type(command.sources) ~= "table" or #command.sources == 0 then
      return nil, "selection_none"
    end
    local sources = {}
    for index, source in ipairs(command.sources) do
      sources[index] = source
    end
    table.sort(sources, function(left, right)
      if left.track_index ~= right.track_index then
        return left.track_index < right.track_index
      end
      if left.position ~= right.position then
        return left.position < right.position
      end
      return left.source_item_guid < right.source_item_guid
    end)
    local main = current_idea.families.Main
    local added = 0
    local skipped = 0
    for _, source in ipairs(sources) do
      if source_in_family(main, source.source_item_guid) then
        skipped = skipped + 1
      else
        local component_id = generated_ids[added + 1]
        if not idea.guid_is_valid(component_id) then
          return nil, "component_id_invalid"
        end
        main.variants[#main.variants + 1] = {
          component_id = component_id,
          source_item_guid = source.source_item_guid,
          label = next_label(main),
          name = "",
          intensity = nil,
          grammar_override = nil,
        }
        added = added + 1
      end
    end
    repair_default(main)
    if added == 0 then
      return nil, "sources_already_classified"
    end
    grammar.validate(result)
    return result, nil, label, { added = added, skipped = skipped }
  end

  if command.type == "dismiss_recovery" then
    if type(command.fingerprint) ~= "string" or command.fingerprint == "" then
      return nil, "recovery_invalid"
    end
    for _, fingerprint in ipairs(current_idea.dismissed_recoveries) do
      if fingerprint == command.fingerprint then
        return nil, "recovery_dismissed"
      end
    end
    current_idea.dismissed_recoveries[#current_idea.dismissed_recoveries + 1] =
      command.fingerprint
    grammar.validate(result)
    return result, nil, label
  end

  if command.type == "set_family_grammar" and command.family then
    local family = current_idea.families[command.family]
    if not family then
      return nil, "family_invalid"
    end
    if not rules_are_valid(command.grammar) then
      return nil, "grammar_invalid"
    end
    family.grammar = copy_rules(command.grammar)
    grammar.validate(result)
    return result, nil, label
  end

  local variant, source_family, source_family_name, variant_index = find_variant(
    current_idea,
    command.component_id
  )
  if not variant then
    return nil, "variant_missing"
  end

  if command.type == "move" then
    local target = current_idea.families[command.family]
    if not target then
      return nil, "family_invalid"
    end
    if source_family == target then
      return nil, "family_unchanged"
    end
    if source_family_name == "Main" and #source_family.variants == 1 then
      return nil, "main_required"
    end
    if source_in_family(target, variant.source_item_guid) then
      return nil, "source_already_classified"
    end
    table.remove(source_family.variants, variant_index)
    if source_family.default_component_id == variant.component_id then
      source_family.default_component_id = nil
    end
    repair_default(source_family)
    if label_in_family(target, variant.label) then
      variant.label = next_label(target)
    end
    target.variants[#target.variants + 1] = variant
    repair_default(target)
  elseif command.type == "alternate_use" then
    local target = current_idea.families[command.family]
    if not target then
      return nil, "family_invalid"
    end
    if source_in_family(target, variant.source_item_guid) then
      return nil, "source_already_classified"
    end
    local component_id = generated_ids[1]
    if not idea.guid_is_valid(component_id) then
      return nil, "component_id_invalid"
    end
    target.variants[#target.variants + 1] = {
      component_id = component_id,
      source_item_guid = variant.source_item_guid,
      label = label_in_family(target, variant.label) and next_label(target) or variant.label,
      name = "",
      intensity = nil,
      grammar_override = nil,
    }
    repair_default(target)
  elseif command.type == "split" or command.type == "attach_recovery" then
    if not idea.guid_is_valid(command.source_item_guid) then
      return nil, "source_guid_invalid"
    end
    if source_in_family(source_family, command.source_item_guid) then
      return nil, "source_already_classified"
    end
    local component_id = generated_ids[1]
    if not idea.guid_is_valid(component_id) then
      return nil, "component_id_invalid"
    end
    source_family.variants[#source_family.variants + 1] = {
      component_id = component_id,
      source_item_guid = command.source_item_guid,
      label = next_label(source_family),
      name = "",
      intensity = nil,
      grammar_override = nil,
    }
  elseif command.type == "set_default" then
    source_family.default_component_id = variant.component_id
  elseif command.type == "set_name" then
    if type(command.name) ~= "string" then
      return nil, "variant_name_invalid"
    end
    local name = command.name:match("^%s*(.-)%s*$")
    if not optional_name_is_valid(name) then
      return nil, "variant_name_invalid"
    end
    variant.name = name
  elseif command.type == "set_intensity" then
    if command.intensity ~= nil
      and (type(command.intensity) ~= "number"
        or command.intensity % 1 ~= 0
        or command.intensity < 1
        or command.intensity > 5)
    then
      return nil, "intensity_invalid"
    end
    variant.intensity = command.intensity
  elseif command.type == "set_family_grammar" then
    if not rules_are_valid(command.grammar) then
      return nil, "grammar_invalid"
    end
    source_family.grammar = copy_rules(command.grammar)
  elseif command.type == "set_variant_grammar" then
    if not rules_are_valid(command.grammar) then
      return nil, "grammar_invalid"
    end
    variant.grammar_override = copy_rules(command.grammar)
  elseif command.type == "inherit_family_grammar" then
    variant.grammar_override = nil
  end

  grammar.validate(result)
  return result, nil, label
end

function grammar.idea(state, idea_id)
  return find_idea(state, idea_id)
end

function grammar.variant(current_idea, component_id)
  return find_variant(current_idea, component_id)
end

function grammar.rules_are_valid(rules)
  return rules_are_valid(rules)
end

return grammar
