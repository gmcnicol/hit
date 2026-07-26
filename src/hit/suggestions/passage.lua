local passage = {}

passage.COMPILER_VERSION = "3.0.0"

local FAMILY_ORDER = {
  Pickup = 1,
  Main = 2,
  Turnaround = 3,
  Ending = 4,
}

local function rules_for(variant)
  return variant.grammar_override or variant.family_grammar
end

local function random(seed)
  local state = (seed * 2654435761) % 4294967296
  return function(limit)
    state = (1664525 * state + 1013904223) % 4294967296
    return math.floor(state / 4294967296 * limit) + 1
  end
end

local function copy_sequence(sequence)
  local result = {}
  for index, phrase in ipairs(sequence) do
    local copy = {}
    for key, value in pairs(phrase) do
      copy[key] = value
    end
    result[index] = copy
  end
  return result
end

local function weighted_choice(candidates, next_random, extra_weight)
  local total = 0
  local weights = {}
  for index, candidate in ipairs(candidates) do
    local weight = (candidate.default and 2 or 1) + (extra_weight and extra_weight(candidate) or 0)
    weights[index] = weight
    total = total + weight
  end
  local chosen = next_random(total)
  for index, candidate in ipairs(candidates) do
    chosen = chosen - weights[index]
    if chosen <= 0 then
      return candidate
    end
  end
  error("weighted choice failed")
end

local function sorted_palette(palette)
  local result = {}
  for index, variant in ipairs(palette) do
    result[index] = variant
  end
  table.sort(result, function(left, right)
    local left_family = FAMILY_ORDER[left.family] or 99
    local right_family = FAMILY_ORDER[right.family] or 99
    if left_family ~= right_family then
      return left_family < right_family
    end
    return left.component_id < right.component_id
  end)
  return result
end

local function can_follow(current, candidate)
  local current_rules = rules_for(current)
  return current_rules.allowed_next[candidate.family]
    and (candidate.component_id ~= current.component_id or current_rules.may_repeat)
end

local function finish_distances(palette)
  local distances = {}
  for _, variant in ipairs(palette) do
    if rules_for(variant).may_end then
      distances[variant] = 0
    end
  end
  for _ = 1, #palette do
    local changed = false
    for _, variant in ipairs(palette) do
      if distances[variant] == nil then
        local closest
        for _, candidate in ipairs(palette) do
          if can_follow(variant, candidate) and distances[candidate] ~= nil then
            closest = not closest and distances[candidate] or math.min(closest, distances[candidate])
          end
        end
        if closest then
          distances[variant] = closest + 1
          changed = true
        end
      end
    end
    if not changed then
      break
    end
  end
  return distances
end

local function beginning_candidates(palette, distances)
  local starts = {}
  for _, variant in ipairs(palette) do
    if rules_for(variant).may_begin and distances[variant] ~= nil then
      starts[#starts + 1] = variant
    end
  end
  if #starts == 0 then
    return starts
  end
  for _, preferred_family in ipairs({ "Pickup", "Main" }) do
    local preferred = {}
    for _, variant in ipairs(starts) do
      if variant.family == preferred_family then
        preferred[#preferred + 1] = variant
      end
    end
    if #preferred > 0 then
      return preferred
    end
  end
  return starts
end

local function continuation_candidates(palette, current, distances)
  local result = {}
  for _, candidate in ipairs(palette) do
    if distances[candidate] ~= nil and can_follow(current, candidate) then
      result[#result + 1] = candidate
    end
  end
  return result
end

local function bar_length_at(boundaries, position)
  for index = 1, #boundaries - 1 do
    if position < boundaries[index + 1] then
      return boundaries[index + 1] - boundaries[index]
    end
  end
  return boundaries[#boundaries] - boundaries[#boundaries - 1]
end

local function overlap_for(current, next_variant, cursor, boundaries, next_random)
  if not rules_for(current).may_overlap or next_random(2) == 1 then
    return 0
  end
  return math.min(bar_length_at(boundaries, cursor), math.min(current.duration, next_variant.duration) / 4)
end

local function append(sequence, variant, position, overlap)
  sequence[#sequence + 1] = {
    component_id = variant.component_id,
    source_item_guid = variant.source_item_guid,
    family = variant.family,
    label = variant.label,
    name = variant.name,
    position = position,
    duration = variant.duration,
    overlap = overlap,
    lane = (#sequence % 2 == 0) and "A" or "B",
  }
end

local function available_default_main(candidates)
  for _, candidate in ipairs(candidates) do
    if candidate.family == "Main" and candidate.default then
      return candidate
    end
  end
end

local function closest_ending(candidates, cursor, target_end, current, boundaries, next_random)
  local endings = {}
  for _, candidate in ipairs(candidates) do
    if candidate.family == "Ending" then
      local maximum_overlap = rules_for(current).may_overlap
          and math.min(bar_length_at(boundaries, cursor), math.min(current.duration, candidate.duration) / 4)
        or 0
      local difference = math.min(
        math.abs(cursor + candidate.duration - target_end),
        math.abs(cursor - maximum_overlap + candidate.duration - target_end)
      )
      endings[#endings + 1] = { variant = candidate, difference = difference }
    end
  end
  if #endings == 0 then
    return nil
  end
  table.sort(endings, function(left, right)
    if math.abs(left.difference - right.difference) > 0.000000001 then
      return left.difference < right.difference
    end
    return left.variant.component_id < right.variant.component_id
  end)
  local choices = {}
  local bonus = {}
  for index, ending in ipairs(endings) do
    choices[index] = ending.variant
    bonus[ending.variant] = #endings - index
  end
  return weighted_choice(choices, next_random, function(candidate)
    return bonus[candidate]
  end)
end

---@param input table
---@return table? suggestion
---@return string? error_code
function passage.generate(input)
  assert(type(input) == "table", "input required")
  assert(type(input.palette) == "table", "palette required")
  assert(type(input.measure_boundaries) == "table" and #input.measure_boundaries >= 2, "measure boundaries required")
  assert(type(input.seed) == "number" and input.seed % 1 == 0, "integer seed required")

  local boundaries = input.measure_boundaries
  local anchor = boundaries[1]
  local target_end = boundaries[#boundaries]
  assert(target_end > anchor, "positive target span required")

  local palette = sorted_palette(input.palette)
  local legal_start = false
  for _, variant in ipairs(palette) do
    legal_start = legal_start or rules_for(variant).may_begin
  end
  if not legal_start then
    return nil, "no_legal_start"
  end
  local distances = finish_distances(palette)
  local starts = beginning_candidates(palette, distances)
  if #starts == 0 then
    return nil, "no_legal_end"
  end

  local next_random = random(input.seed)
  local first = weighted_choice(starts, next_random)
  local sequence = {}
  append(sequence, first, anchor, 0)
  local cursor = anchor + first.duration
  local current = first
  local best
  local best_difference
  local turnaround_seen = first.family == "Turnaround"
  local minimum_duration = first.duration
  for _, variant in ipairs(palette) do
    minimum_duration = math.min(minimum_duration, variant.duration)
  end
  local maximum_phrases = math.max(16, math.ceil((target_end - anchor) / minimum_duration) + 8)

  for phrase_index = 1, maximum_phrases do
    if rules_for(current).may_end then
      local difference = math.abs(cursor - target_end)
      if not best_difference or difference < best_difference then
        best = copy_sequence(sequence)
        best_difference = difference
      end
      if cursor >= target_end then
        break
      end
    end

    local candidates = continuation_candidates(palette, current, distances)
    if #candidates == 0 then
      break
    end

    local next_variant
    local remaining = maximum_phrases - phrase_index + 1
    if not best and remaining <= distances[current] then
      local shortest = distances[current]
      local finishing = {}
      for _, candidate in ipairs(candidates) do
        if distances[candidate] < shortest then
          shortest = distances[candidate]
          finishing = { candidate }
        elseif distances[candidate] == shortest then
          finishing[#finishing + 1] = candidate
        end
      end
      next_variant = weighted_choice(finishing, next_random)
    end
    if current.family == "Pickup" or current.family == "Turnaround" then
      next_variant = next_variant or available_default_main(candidates)
    end

    local progress = (cursor - anchor) / (target_end - anchor)
    if not next_variant and progress >= 0.7 then
      next_variant = closest_ending(candidates, cursor, target_end, current, boundaries, next_random)
    end

    if not next_variant then
      local non_endings = {}
      for _, candidate in ipairs(candidates) do
        if candidate.family ~= "Ending" then
          non_endings[#non_endings + 1] = candidate
        end
      end
      local choices = #non_endings > 0 and non_endings or candidates
      next_variant = weighted_choice(choices, next_random, function(candidate)
        if candidate.family == "Turnaround" and not turnaround_seen then
          return math.max(0, math.floor(progress * 4))
        end
        return 0
      end)
    end

    local overlap = overlap_for(current, next_variant, cursor, boundaries, next_random)
    append(sequence, next_variant, cursor - overlap, overlap)
    cursor = cursor - overlap + next_variant.duration
    current = next_variant
    turnaround_seen = turnaround_seen or current.family == "Turnaround"
  end

  if not best and rules_for(current).may_end then
    best = copy_sequence(sequence)
  end
  if not best then
    return nil, "no_legal_end"
  end

  local achieved_end = best[#best].position + best[#best].duration
  local families = {}
  local overlaps = 0
  for _, phrase in ipairs(best) do
    families[phrase.family] = (families[phrase.family] or 0) + 1
    if phrase.overlap > 0 then
      overlaps = overlaps + 1
    end
  end
  local explanation = {}
  if families.Pickup then
    explanation[#explanation + 1] = "Pickup establishes the Idea"
  end
  if families.Main then
    explanation[#explanation + 1] = "Default Main anchors returns while alternatives vary them"
  end
  if families.Turnaround then
    explanation[#explanation + 1] = "Turnaround redirects the passage near its target"
  end
  if families.Ending then
    explanation[#explanation + 1] = "Ending closes the complete phrase span"
  end
  explanation[#explanation + 1] = overlaps > 0
      and (overlaps .. " seeded overlap" .. (overlaps == 1 and "" or "s") .. " add continuity")
    or "Phrase changes remain discrete"

  return {
    compiler_version = input.compiler_version or passage.COMPILER_VERSION,
    seed = input.seed,
    source_palette = palette,
    sequence = best,
    target_duration = target_end - anchor,
    achieved_duration = achieved_end - anchor,
    overlap_count = overlaps,
    explanation = table.concat(explanation, ". ") .. ".",
  }
end

return passage
