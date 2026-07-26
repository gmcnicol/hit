local view = {}

local ERROR_TEXT = {
  target_bars_invalid = "Target Bars must be a positive whole number.",
  seed_invalid = "Seed must be a whole number.",
  main_required = "Idea needs one present Main Variant.",
  no_legal_start = "Phrase Rules allow no present Variant to begin.",
  no_legal_end = "Phrase Rules allow no complete passage.",
  source_changed = "Source items changed. Review Phrases and try again.",
  source_ambiguous = "Several items share one source identity.",
  project_inactive = "Return to this project before generating.",
  state_invalid = "Stored HIT generation state is invalid.",
  state_version_unsupported = "Project uses newer HIT generation state. Builds are read-only.",
  time_map_failed = "REAPER could not calculate requested measures.",
  item_copy_failed = "REAPER could not copy one source item.",
  state_write_failed = "REAPER could not store generated Build.",
  state_restore_failed = "REAPER could not restore project after failed generation.",
}

local function phrase_name(phrase)
  return phrase.family .. " " .. (phrase.name ~= "" and phrase.name or phrase.label)
end

function view.sequence_text(sequence)
  local labels = {}
  for index, phrase in ipairs(sequence) do
    labels[index] = phrase_name(phrase) .. (phrase.overlap > 0 and " (overlap)" or "")
  end
  return table.concat(labels, "  >  ")
end

function view.request_seed(current_view, draft_seed)
  if #current_view.builds > 0 and draft_seed == current_view.seed then
    return current_view.next_seed
  end
  return draft_seed
end

function view.draw(ImGui, context, generation_view, state, can_mutate, execute)
  if generation_view.read_only then
    ImGui.TextWrapped(context, ERROR_TEXT[generation_view.error] or tostring(generation_view.error))
    return generation_view
  end

  ImGui.Text(context, generation_view.name .. " · Generate")
  local summary = generation_view.source_summary or {}
  ImGui.TextDisabled(
    context,
    string.format(
      "Source Palette: %d present%s",
      summary.present or 0,
      (summary.offline or 0) > 0 and (" (" .. summary.offline .. " offline)") or ""
    )
  )
  if (summary.gone or 0) > 0 or (summary.ambiguous or 0) > 0 then
    ImGui.TextDisabled(
      context,
      string.format("%d Gone, %d ambiguous excluded", summary.gone or 0, summary.ambiguous or 0)
    )
  end

  local target_changed
  local seed_changed
  target_changed, state.target_bars = ImGui.InputInt(context, "Target Bars", state.target_bars)
  seed_changed, state.seed = ImGui.InputInt(context, "Seed", state.seed)
  if target_changed or seed_changed then
    state.feedback = nil
  end
  local valid_target = state.target_bars > 0 and state.target_bars % 1 == 0
  local valid_seed = state.seed % 1 == 0
  local can_generate = can_mutate and generation_view.generatable and valid_target and valid_seed
  ImGui.BeginDisabled(context, not can_generate)
  local label = #generation_view.builds == 0 and "Generate" or "Try Another"
  if ImGui.Button(context, label) then
    local requested_seed = view.request_seed(generation_view, state.seed)
    local next_view, error_code = execute(state.target_bars, requested_seed)
    if next_view then
      generation_view = next_view
      state.seed = requested_seed
      state.feedback = "Published Build " .. string.format("%03d", #next_view.builds) .. "."
    else
      state.feedback = ERROR_TEXT[error_code] or tostring(error_code)
    end
  end
  ImGui.EndDisabled(context)
  if not valid_target then
    ImGui.TextDisabled(context, ERROR_TEXT.target_bars_invalid)
  elseif not valid_seed then
    ImGui.TextDisabled(context, ERROR_TEXT.seed_invalid)
  elseif not generation_view.generatable then
    ImGui.TextDisabled(context, "No present Variant can be generated.")
  elseif not generation_view.classified then
    ImGui.TextDisabled(context, "Main unavailable. First generated phrase supplies Build processing.")
  end
  if state.feedback then
    ImGui.TextWrapped(context, state.feedback)
  end

  if #generation_view.builds > 0 then
    local latest = generation_view.builds[#generation_view.builds]
    ImGui.Separator(context)
    ImGui.Text(
      context,
      string.format(
        "Requested: %d bars · Achieved: %.2f bars · Seed: %d",
        latest.target_bars,
        latest.achieved_bars,
        latest.seed
      )
    )
    ImGui.TextWrapped(context, view.sequence_text(latest.sequence))
    ImGui.TextWrapped(context, latest.explanation)
    ImGui.Separator(context)
    ImGui.Text(context, "Builds")
    for index, build in ipairs(generation_view.builds) do
      ImGui.TextDisabled(
        context,
        string.format(
          "Build %03d · seed %d · requested %d bars · achieved %.2f bars",
          build.number or index,
          build.seed,
          build.target_bars,
          build.achieved_bars
        )
      )
    end
  end
  return generation_view
end

return view
