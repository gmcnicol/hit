package.path = "src/?.lua;src/?/init.lua;" .. package.path

local passage = require("hit.suggestions.passage")

local function rules(beginning, repeating, ending, overlap, allowed)
  return {
    may_begin = beginning,
    may_repeat = repeating,
    may_end = ending,
    may_overlap = overlap,
    allowed_next = allowed,
  }
end

local family_rules = {
  Pickup = rules(true, false, false, true, { Main = true }),
  Main = rules(true, true, true, true, { Main = true, Turnaround = true, Ending = true }),
  Turnaround = rules(false, false, true, true, { Main = true, Ending = true }),
  Ending = rules(false, false, true, false, {}),
}

local function variant(family, id, duration, default, intensity)
  return {
    family = family,
    component_id = "{" .. id .. "0000000-0000-0000-0000-000000000000}",
    source_item_guid = "{" .. id .. "1000000-0000-0000-0000-000000000000}",
    label = id,
    name = "",
    intensity = intensity,
    default = default,
    duration = duration,
    family_grammar = family_rules[family],
  }
end

local palette = {
  variant("Pickup", "1", 3, true),
  variant("Main", "2", 8, true, 1),
  variant("Main", "3", 5, false, 5),
  variant("Turnaround", "4", 13, true),
  variant("Ending", "5", 7, true),
}

local function input(seed, source_palette)
  return {
    seed = seed,
    compiler_version = "test",
    palette = source_palette or palette,
    measure_boundaries = { 2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50 },
  }
end

local first = assert(passage.generate(input(1)))
local repeated = assert(passage.generate(input(1)))
assert(#first.sequence == #repeated.sequence)
for index, phrase in ipairs(first.sequence) do
  for _, key in ipairs({ "component_id", "position", "duration", "overlap", "lane" }) do
    assert(phrase[key] == repeated.sequence[index][key])
  end
end
assert(first.sequence[1].family == "Pickup")
assert(first.sequence[2].family == "Main" and first.sequence[2].component_id == palette[2].component_id)
assert(first.target_duration == 48)
assert(first.achieved_duration ~= first.target_duration or #first.sequence > 1)

local changed = false
for seed = 2, 30 do
  local other = assert(passage.generate(input(seed)))
  for index, phrase in ipairs(other.sequence) do
    if not first.sequence[index] or phrase.component_id ~= first.sequence[index].component_id then
      changed = true
      break
    end
  end
  if changed then
    break
  end
end
assert(changed)

local by_id = {}
for _, current in ipairs(palette) do
  by_id[current.component_id] = current
end
local concurrent = {}
for index, phrase in ipairs(first.sequence) do
  local current = by_id[phrase.component_id]
  local effective = current.grammar_override or current.family_grammar
  if index == 1 then
    assert(effective.may_begin)
  else
    local previous_phrase = first.sequence[index - 1]
    local previous = by_id[previous_phrase.component_id]
    local previous_rules = previous.grammar_override or previous.family_grammar
    assert(previous_rules.allowed_next[current.family])
    assert(current.component_id ~= previous.component_id or previous_rules.may_repeat)
    if phrase.overlap > 0 then
      assert(previous_rules.may_overlap)
      assert(phrase.overlap <= math.min(4, math.min(previous.duration, current.duration) / 4))
    end
  end
  concurrent[#concurrent + 1] = { start = phrase.position, finish = phrase.position + phrase.duration }
  assert(phrase.duration == current.duration)
  assert(phrase.lane == (index % 2 == 1 and "A" or "B"))
end
assert(
  (
    by_id[first.sequence[#first.sequence].component_id].grammar_override
    or by_id[first.sequence[#first.sequence].component_id].family_grammar
  ).may_end
)
for _, point in ipairs(concurrent) do
  local count = 0
  for _, span in ipairs(concurrent) do
    if span.start < point.finish and span.finish > point.start then
      count = count + 1
    end
  end
  assert(count <= 2)
end

local no_start = {
  variant("Main", "6", 4, true),
}
no_start[1].family_grammar = rules(false, false, true, false, {})
local missing, missing_error = passage.generate(input(1, no_start))
assert(missing == nil and missing_error == "no_legal_start")

local dead_pickup = {
  variant("Pickup", "6", 4, true),
  variant("Main", "7", 4, true),
}
dead_pickup[1].family_grammar = rules(true, false, false, false, {})
dead_pickup[2].family_grammar = rules(true, false, true, false, {})
local viable_start = assert(passage.generate(input(1, dead_pickup)))
assert(viable_start.sequence[1].family == "Main")
local no_end, no_end_error = passage.generate(input(1, { dead_pickup[1] }))
assert(no_end == nil and no_end_error == "no_legal_end")

local restrictive = {
  variant("Main", "8", 19, true),
}
restrictive[1].family_grammar = rules(true, false, true, false, {})
local short = assert(passage.generate(input(1, restrictive)))
assert(#short.sequence == 1 and short.achieved_duration == 19)

local no_main = {
  variant("Pickup", "A", 7, true),
}
no_main[1].family_grammar = rules(true, false, true, false, {})
local no_main_suggestion = assert(passage.generate(input(1, no_main)))
assert(#no_main_suggestion.sequence == 1 and no_main_suggestion.sequence[1].family == "Pickup")

local low_intensity = assert(passage.generate(input(9)))
local intensity_changed = {}
for index, current in ipairs(palette) do
  intensity_changed[index] = {}
  for key, value in pairs(current) do
    intensity_changed[index][key] = key == "intensity" and (6 - value) or value
  end
end
local high_intensity = assert(passage.generate(input(9, intensity_changed)))
for index, phrase in ipairs(low_intensity.sequence) do
  assert(phrase.component_id == high_intensity.sequence[index].component_id)
  assert(phrase.position == high_intensity.sequence[index].position)
end

local default_count = 0
local alternative_count = 0
local choice_palette = {
  variant("Main", "8", 4, true),
  variant("Main", "9", 4, false),
}
choice_palette[1].family_grammar = rules(true, false, true, false, {})
choice_palette[2].family_grammar = choice_palette[1].family_grammar
for seed = 1, 300 do
  local suggestion = assert(passage.generate(input(seed, choice_palette)))
  if suggestion.sequence[1].component_id == choice_palette[1].component_id then
    default_count = default_count + 1
  else
    alternative_count = alternative_count + 1
  end
end
assert(default_count > alternative_count * 1.7)
assert(default_count < alternative_count * 2.3)

local ending_palette = {
  variant("Main", "B", 4, true),
  variant("Ending", "C", 4, true),
  variant("Ending", "D", 20, false),
}
ending_palette[1].family_grammar = rules(true, false, false, false, { Ending = true })
ending_palette[2].family_grammar = rules(false, false, true, false, {})
ending_palette[3].family_grammar = ending_palette[2].family_grammar
local endings_seen = {}
for seed = 1, 100 do
  local suggestion = assert(passage.generate(input(seed, ending_palette)))
  endings_seen[suggestion.sequence[#suggestion.sequence].component_id] = true
end
assert(endings_seen[ending_palette[2].component_id] and endings_seen[ending_palette[3].component_id])
assert(first.explanation:find("Default Main anchors returns", 1, true))

local closest_palette = {
  variant("Main", "E", 7, true),
}
closest_palette[1].family_grammar = rules(true, true, true, false, { Main = true })
local closest = assert(passage.generate(input(1, closest_palette)))
assert(closest.achieved_duration == 49)

local span_palette = {
  variant("Pickup", "F", 3, true),
  variant("Ending", "0", 5, true),
}
span_palette[1].family_grammar = rules(true, false, false, true, { Ending = true })
span_palette[2].family_grammar = rules(false, false, true, false, {})
local overlapped
for seed = 1, 20 do
  local suggestion = assert(passage.generate({
    seed = seed,
    palette = span_palette,
    measure_boundaries = { 2, 6, 10 },
  }))
  if suggestion.sequence[2].overlap > 0 then
    overlapped = suggestion
    break
  end
end
assert(overlapped)
assert(overlapped.target_duration == 8)
assert(
  overlapped.achieved_duration == span_palette[1].duration + span_palette[2].duration - overlapped.sequence[2].overlap
)

local duration_aware = false
for seed = 1, 100 do
  local function turnaround_palette(main_duration)
    local result = {
      variant("Pickup", "1", 1, true),
      variant("Main", "2", main_duration, true),
      variant("Turnaround", "3", 4, true),
    }
    result[1].family_grammar = rules(true, false, false, false, { Main = true })
    result[2].family_grammar = rules(false, true, true, false, { Main = true, Turnaround = true })
    result[3].family_grammar = rules(false, false, true, false, {})
    return result
  end
  local short_main = assert(passage.generate(input(seed, turnaround_palette(3))))
  local long_main = assert(passage.generate(input(seed, turnaround_palette(20))))
  if
    short_main.sequence[3]
    and long_main.sequence[3]
    and short_main.sequence[3].family == "Main"
    and long_main.sequence[3].family == "Turnaround"
  then
    duration_aware = true
    break
  end
end
assert(duration_aware)

print("passage generator tests passed")
