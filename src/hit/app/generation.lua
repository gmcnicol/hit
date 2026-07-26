local passage = require("hit.suggestions.passage")

local generation = {}

local function composition_for(state, idea_id)
  for _, composition in ipairs(state.compositions) do
    if composition.idea_id == idea_id then
      return composition
    end
  end
end

local function has_main(palette)
  for _, variant in ipairs(palette) do
    if variant.family == "Main" then
      return true
    end
  end
  return false
end

local function copy_state_with_composition(state, current, replacement)
  local result = { version = 3, compositions = {} }
  local replaced = false
  for index, composition in ipairs(state.compositions) do
    if composition == current then
      result.compositions[index] = replacement
      replaced = true
    else
      result.compositions[index] = composition
    end
  end
  if not replaced then
    result.compositions[#result.compositions + 1] = replacement
  end
  return result
end

local function project(loaded, idea_id)
  local composition = composition_for(loaded.v3, idea_id)
  local history = composition and composition.builds or {}
  local builds = {}
  for index, build in ipairs(history) do
    if not loaded.surviving_build_ids or loaded.surviving_build_ids[build.id] then
      local projected = {}
      for key, value in pairs(build) do
        projected[key] = value
      end
      projected.number = index
      builds[#builds + 1] = projected
    end
  end
  local latest = history[#history]
  return {
    idea_id = idea_id,
    name = loaded.idea.name,
    classified = has_main(loaded.palette),
    generatable = #loaded.palette > 0,
    read_only = false,
    target_bars = composition and composition.target_bars or 48,
    seed = latest and latest.seed or 1,
    next_seed = latest and latest.seed + 1 or 1,
    source_summary = loaded.source_summary,
    builds = builds,
  }
end

function generation.open(port, idea_id)
  assert(type(port) == "table" and type(port.load) == "function", "generation port required")
  local loaded, error_code = port.load(idea_id)
  if not loaded then
    return {
      idea_id = idea_id,
      read_only = true,
      error = error_code,
      builds = {},
      target_bars = 48,
      seed = 1,
      next_seed = 1,
    }
  end
  return project(loaded, idea_id)
end

function generation.execute(port, idea_id, target_bars, seed)
  assert(type(port) == "table" and type(port.publish) == "function", "generation port required")
  if type(target_bars) ~= "number" or target_bars <= 0 or target_bars % 1 ~= 0 then
    return nil, "target_bars_invalid"
  end
  if type(seed) ~= "number" or seed % 1 ~= 0 then
    return nil, "seed_invalid"
  end

  local loaded, load_error = port.load(idea_id)
  if not loaded then
    return nil, load_error
  end
  local old_composition = composition_for(loaded.v3, idea_id)
  local anchor = old_composition and old_composition.anchor or port.cursor()
  local boundaries, boundary_error = port.measure_boundaries(anchor, target_bars)
  if not boundaries then
    return nil, boundary_error
  end
  local suggestion, generation_error = passage.generate({
    palette = loaded.palette,
    measure_boundaries = boundaries,
    seed = seed,
    compiler_version = passage.COMPILER_VERSION,
  })
  if not suggestion then
    return nil, generation_error
  end

  local composition = {
    id = old_composition and old_composition.id or port.new_guid(),
    idea_id = idea_id,
    occurrence_id = old_composition and old_composition.occurrence_id or port.new_guid(),
    root_id = old_composition and old_composition.root_id or port.new_guid(),
    revision = old_composition and old_composition.revision + 1 or 1,
    target_bars = target_bars,
    anchor = anchor,
    compiler_version = passage.COMPILER_VERSION,
    builds = {},
  }
  if old_composition then
    for index, build in ipairs(old_composition.builds) do
      composition.builds[index] = build
    end
  end

  local build = {
    id = port.new_guid(),
    suggestion_id = port.new_guid(),
    composition_revision = composition.revision,
    seed = seed,
    compiler_version = passage.COMPILER_VERSION,
    target_bars = target_bars,
    target_duration = suggestion.target_duration,
    achieved_duration = suggestion.achieved_duration,
    achieved_bars = port.bars_for_span(anchor, suggestion.achieved_duration),
    explanation = suggestion.explanation,
    source_palette = {},
    sequence = suggestion.sequence,
  }
  for index, source in ipairs(suggestion.source_palette) do
    build.source_palette[index] = {
      component_id = source.component_id,
      source_item_guid = source.source_item_guid,
      family = source.family,
    }
  end
  composition.builds[#composition.builds + 1] = build
  local next_state = copy_state_with_composition(loaded.v3, old_composition, composition)
  local published, publish_error = port.publish(next_state, composition, build, loaded.palette)
  if not published then
    return nil, publish_error
  end

  local next_loaded, reload_error = port.load(idea_id)
  if not next_loaded then
    return nil, reload_error
  end
  return project(next_loaded, idea_id)
end

return generation
