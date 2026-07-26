local grammar_model = require("hit.model.grammar")

local view = {}

local UI = {
  window_padding = 16,
  panel_padding = 12,
  gap = 8,
  panel_rounding = 8,
  frame_rounding = 6,
  button_height = 36,
}

local COLOUR = {
  window = 0x10141DFF,
  panel = 0x171C27FF,
  panel_alt = 0x1C2330FF,
  border = 0x30394AFF,
  text = 0xEDF2F7FF,
  muted = 0xA7A9B5FF,
  button = 0x252D3BFF,
  button_hover = 0x344055FF,
  button_active = 0x3D4B63FF,
  selected = 0x27364DFF,
  accent = 0x3978D4FF,
  accent_hover = 0x4A8BE7FF,
  default = 0xE3B341FF,
  available = 0x73C991FF,
  warning = 0xE3B341FF,
  error = 0xF48771FF,
  family = {
    Pickup = 0xA78BFAFF,
    Main = 0x60A5FAFF,
    Turnaround = 0xF59E0BFF,
    Ending = 0xF472B6FF,
  },
}

function view.push_theme(ImGui, context)
  ImGui.PushStyleVar(context, ImGui.StyleVar_WindowPadding, UI.window_padding, UI.window_padding)
  ImGui.PushStyleVar(context, ImGui.StyleVar_ItemSpacing, UI.gap, UI.gap)
  ImGui.PushStyleVar(context, ImGui.StyleVar_FramePadding, 10, 7)
  ImGui.PushStyleVar(context, ImGui.StyleVar_WindowRounding, UI.panel_rounding)
  ImGui.PushStyleVar(context, ImGui.StyleVar_ChildRounding, UI.panel_rounding)
  ImGui.PushStyleVar(context, ImGui.StyleVar_FrameRounding, UI.frame_rounding)
  ImGui.PushStyleColor(context, ImGui.Col_WindowBg, COLOUR.window)
  ImGui.PushStyleColor(context, ImGui.Col_ChildBg, COLOUR.panel)
  ImGui.PushStyleColor(context, ImGui.Col_Border, COLOUR.border)
  ImGui.PushStyleColor(context, ImGui.Col_Text, COLOUR.text)
  ImGui.PushStyleColor(context, ImGui.Col_TextDisabled, COLOUR.muted)
  ImGui.PushStyleColor(context, ImGui.Col_Button, COLOUR.button)
  ImGui.PushStyleColor(context, ImGui.Col_ButtonHovered, COLOUR.button_hover)
  ImGui.PushStyleColor(context, ImGui.Col_ButtonActive, COLOUR.button_active)
  ImGui.PushStyleColor(context, ImGui.Col_Header, COLOUR.selected)
  ImGui.PushStyleColor(context, ImGui.Col_HeaderHovered, COLOUR.button_hover)
end

function view.pop_theme(ImGui, context)
  ImGui.PopStyleColor(context, 10)
  ImGui.PopStyleVar(context, 6)
end

local ERROR_TEXT = {
  selection_none = "Select one or more available audio or MIDI items.",
  active_take_missing = "A selected item has no active take.",
  source_unsupported = "A selected item has no supported audio or MIDI source.",
  audio_unavailable = "Selected audio media is unavailable.",
  source_missing = "Source item is missing.",
  source_ambiguous = "Several items share this Source Reference.",
  source_unavailable = "Source media is unavailable.",
  source_already_classified = "Source already has a Variant in that family.",
  sources_already_classified = "Selected sources are already Main Variants.",
  main_required = "Main must keep at least one Variant.",
  split_cursor_outside = "Place REAPER edit cursor strictly inside this source item.",
  split_failed = "REAPER could not split this source item.",
  intensity_invalid = "Intensity must be unset or between 1 and 5.",
  grammar_invalid = "Phrase Rules are invalid.",
  project_inactive = "Return to the bound project before changing Phrases.",
  recovery_missing = "Recovery candidate changed. Refresh Phrases.",
  state_write_failed = "REAPER could not store phrase data.",
  state_restore_failed = "REAPER could not restore state after failure.",
}

local function copy_rules(rules)
  local allowed_next = {}
  for family_name, allowed in pairs(rules.allowed_next) do
    allowed_next[family_name] = allowed
  end
  return {
    may_begin = rules.may_begin,
    may_repeat = rules.may_repeat,
    may_end = rules.may_end,
    may_overlap = rules.may_overlap,
    allowed_next = allowed_next,
  }
end

local function selected_variant(grammar_view, state)
  for _, family_name in ipairs(grammar_model.FAMILY_ORDER) do
    local family = grammar_view.families[family_name]
    for _, variant in ipairs(family and family.variants or {}) do
      if variant.component_id == state.selected_component_id then
        return variant, family_name
      end
    end
  end
end

function view.select_source_variant(grammar_view, state, source_item_guid)
  local preferred
  local fallback
  for _, family_name in ipairs(grammar_model.FAMILY_ORDER) do
    local family = grammar_view.families[family_name]
    for _, variant in ipairs(family and family.variants or {}) do
      if variant.source_item_guid == source_item_guid then
        if variant.component_id == state.selected_component_id then
          preferred = { variant = variant, family = family_name }
        elseif family_name == state.selected_family and not preferred then
          preferred = { variant = variant, family = family_name }
        elseif not fallback then
          fallback = { variant = variant, family = family_name }
        end
      end
    end
  end

  local match = preferred or fallback
  if match then
    state.selected_family = match.family
    state.selected_component_id = match.variant.component_id
    state.name_draft = match.variant.name or ""
  end
end

function view.selected_source_guid(grammar_view, state)
  local variant = selected_variant(grammar_view, state)
  return variant and variant.source_item_guid
end

local function begin_panel(ImGui, context, id, title, colour)
  ImGui.PushStyleVar(context, ImGui.StyleVar_WindowPadding, UI.panel_padding, UI.panel_padding)
  ImGui.PushStyleColor(context, ImGui.Col_ChildBg, colour or COLOUR.panel)
  local visible = ImGui.BeginChild(
    context,
    id,
    0,
    0,
    ImGui.ChildFlags_Borders | ImGui.ChildFlags_AutoResizeY,
    ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse
  )
  ImGui.PopStyleColor(context)
  ImGui.PopStyleVar(context)
  if visible then
    ImGui.TextColored(context, COLOUR.muted, title)
    ImGui.Spacing(context)
  end
  return visible
end

local function end_panel(ImGui, context, visible)
  if visible then
    ImGui.EndChild(context)
  end
end

local function run(state, execute, command)
  local next_view, error_code, outcome = execute(command)
  if next_view then
    state.feedback = outcome
        and outcome.skipped
        and outcome.skipped > 0
        and ("Added " .. outcome.added .. "; skipped " .. outcome.skipped .. " already classified.")
      or "Saved."
    return next_view
  end
  state.feedback = ERROR_TEXT[error_code] or tostring(error_code)
end

local function draw_families(ImGui, context, grammar_view, state)
  if ImGui.BeginTable(context, "grammar_families", 4, ImGui.TableFlags_SizingStretchSame) then
    ImGui.TableNextRow(context)
    for index, family_name in ipairs(grammar_model.FAMILY_ORDER) do
      ImGui.TableSetColumnIndex(context, index - 1)
      local selected = state.selected_family == family_name
      ImGui.PushStyleColor(context, ImGui.Col_Text, selected and 0xFFFFFFFF or COLOUR.family[family_name])
      if selected then
        ImGui.PushStyleColor(context, ImGui.Col_Button, COLOUR.family[family_name])
        ImGui.PushStyleColor(context, ImGui.Col_ButtonHovered, COLOUR.family[family_name])
        ImGui.PushStyleColor(context, ImGui.Col_ButtonActive, COLOUR.family[family_name])
      end
      if
        ImGui.Button(
          context,
          family_name .. " · " .. #grammar_view.families[family_name].variants .. "###grammar_family_" .. family_name,
          -1,
          UI.button_height
        )
      then
        state.selected_family = family_name
        state.selected_component_id = nil
        state.rules_open = false
        state.family_rules_open = false
      end
      if selected then
        ImGui.PopStyleColor(context, 3)
      end
      ImGui.PopStyleColor(context)
    end
    ImGui.EndTable(context)
  end
end

local function status_text(variant)
  local status = variant.source.status
  if variant.shared then
    return "Shared / " .. status
  end
  return status
end

local function draw_variant_rows(ImGui, context, grammar_view, state, can_mutate, execute)
  local family = grammar_view.families[state.selected_family]
  if #family.variants == 0 then
    ImGui.TextDisabled(context, "No Variants")
    return grammar_view
  end

  local function draw_table()
    if
      not ImGui.BeginTable(
        context,
        "grammar_variant_table",
        4,
        ImGui.TableFlags_RowBg | ImGui.TableFlags_SizingStretchProp
      )
    then
      return
    end
    ImGui.TableSetupColumn(context, "###default", ImGui.TableColumnFlags_WidthFixed, 24)
    ImGui.TableSetupColumn(context, "Variant", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(context, "Intensity", ImGui.TableColumnFlags_WidthFixed, 120)
    ImGui.TableSetupColumn(context, "Status", ImGui.TableColumnFlags_WidthFixed, 150)
    ImGui.TableHeadersRow(context)
    for _, variant in ipairs(family.variants) do
      ImGui.TableNextRow(context)
      ImGui.TableSetColumnIndex(context, 0)
      if family.default_component_id == variant.component_id then
        local marker_width = ImGui.CalcTextSize(context, "★")
        local marker_x, marker_y = ImGui.GetCursorScreenPos(context)
        local available_width = ImGui.GetContentRegionAvail(context)
        ImGui.SetCursorScreenPos(context, marker_x + math.max(0, (available_width - marker_width) / 2), marker_y)
        ImGui.TextColored(context, COLOUR.default, "★")
      end
      ImGui.TableSetColumnIndex(context, 1)
      local name = variant.name ~= "" and (" · " .. variant.name) or ""
      if
        ImGui.Selectable(
          context,
          variant.label .. name .. "###variant_" .. variant.component_id,
          state.selected_component_id == variant.component_id
        )
      then
        state.selected_component_id = variant.component_id
        state.name_draft = variant.name
        state.rules_open = false
      end
      ImGui.TableSetColumnIndex(context, 2)
      ImGui.BeginDisabled(context, not can_mutate)
      if variant.intensity == nil then
        if ImGui.Button(context, "Set 1###intensity_" .. variant.component_id, -1) then
          grammar_view = run(state, execute, {
            type = "set_intensity",
            component_id = variant.component_id,
            intensity = 1,
          }) or grammar_view
        end
      else
        ImGui.SetNextItemWidth(context, -1)
        local changed, intensity =
          ImGui.SliderInt(context, "###intensity_" .. variant.component_id, variant.intensity, 1, 5)
        if changed then
          grammar_view = run(state, execute, {
            type = "set_intensity",
            component_id = variant.component_id,
            intensity = intensity,
          }) or grammar_view
        end
      end
      ImGui.EndDisabled(context)
      ImGui.TableSetColumnIndex(context, 3)
      local colour = variant.source.status == "available" and COLOUR.available
        or (variant.source.status == "missing" or variant.source.status == "ambiguous") and COLOUR.error
        or COLOUR.warning
      ImGui.TextColored(context, colour, status_text(variant))
    end
    ImGui.EndTable(context)
  end

  if #family.variants > 7 then
    local visible = ImGui.BeginChild(context, "grammar_variant_scroll", 0, 280, ImGui.ChildFlags_Borders)
    if visible then
      draw_table()
      ImGui.EndChild(context)
    end
  else
    draw_table()
  end
  return grammar_view
end

local function draw_targets(
  ImGui,
  context,
  label,
  variant,
  current_family,
  grammar_view,
  state,
  can_mutate,
  execute,
  command_type
)
  ImGui.Text(context, label)
  ImGui.SameLine(context)
  for _, family_name in ipairs(grammar_model.FAMILY_ORDER) do
    local duplicate = false
    for _, current in ipairs(grammar_view.families[family_name].variants) do
      duplicate = duplicate or current.source_item_guid == variant.source_item_guid
    end
    local blocked = not can_mutate
      or family_name == current_family
      or duplicate
      or (command_type == "move" and current_family == "Main" and #grammar_view.families.Main.variants == 1)
    ImGui.BeginDisabled(context, blocked)
    if ImGui.SmallButton(context, family_name .. "###" .. command_type .. "_" .. family_name) then
      grammar_view = run(state, execute, {
        type = command_type,
        component_id = variant.component_id,
        family = family_name,
      }) or grammar_view
      state.selected_family = command_type == "move" and family_name or current_family
    end
    ImGui.EndDisabled(context)
    ImGui.SameLine(context)
  end
  ImGui.NewLine(context)
  return grammar_view
end

local function checkbox(ImGui, context, label, value)
  local changed, next_value = ImGui.Checkbox(context, label, value)
  return changed and next_value or value
end

local function draw_rules_editor(ImGui, context, rules, suffix)
  if ImGui.BeginTable(context, "rules_" .. suffix, 4, ImGui.TableFlags_SizingStretchSame) then
    ImGui.TableNextRow(context)
    local controls = {
      { "Begin", "may_begin" },
      { "Repeat", "may_repeat" },
      { "End", "may_end" },
      { "Overlap", "may_overlap" },
    }
    for index, control in ipairs(controls) do
      ImGui.TableSetColumnIndex(context, index - 1)
      rules[control[2]] =
        checkbox(ImGui, context, control[1] .. "###" .. suffix .. "_" .. control[2], rules[control[2]])
    end
    ImGui.EndTable(context)
  end
  ImGui.Text(context, "May lead to")
  if ImGui.BeginTable(context, "next_" .. suffix, 4, ImGui.TableFlags_SizingStretchSame) then
    ImGui.TableNextRow(context)
    for index, family_name in ipairs(grammar_model.FAMILY_ORDER) do
      ImGui.TableSetColumnIndex(context, index - 1)
      rules.allowed_next[family_name] = checkbox(
        ImGui,
        context,
        family_name .. "###" .. suffix .. "_next_" .. family_name,
        rules.allowed_next[family_name] == true
      )
      if not rules.allowed_next[family_name] then
        rules.allowed_next[family_name] = nil
      end
    end
    ImGui.EndTable(context)
  end
end

local function draw_inspector(ImGui, context, grammar_view, state, can_mutate, execute)
  local variant, family_name = selected_variant(grammar_view, state)
  if not variant then
    return grammar_view
  end
  local family = grammar_view.families[family_name]
  state.name_draft = state.name_draft == nil and variant.name or state.name_draft

  local visible =
    begin_panel(ImGui, context, "grammar_inspector", family_name .. " - " .. variant.label, COLOUR.panel_alt)
  if visible then
    ImGui.BeginDisabled(context, not can_mutate)
    ImGui.Text(context, "Name")
    ImGui.SetNextItemWidth(context, -1)
    local submitted
    submitted, state.name_draft =
      ImGui.InputText(context, "###grammar_variant_name", state.name_draft, ImGui.InputTextFlags_EnterReturnsTrue)
    if submitted then
      grammar_view = run(state, execute, {
        type = "set_name",
        component_id = variant.component_id,
        name = state.name_draft,
      }) or grammar_view
    end
    if variant.intensity ~= nil then
      if ImGui.SmallButton(context, "Unset intensity") then
        grammar_view = run(state, execute, {
          type = "set_intensity",
          component_id = variant.component_id,
          intensity = nil,
        }) or grammar_view
      end
      ImGui.SameLine(context)
    end
    ImGui.BeginDisabled(context, family.default_component_id == variant.component_id)
    if ImGui.SmallButton(context, "Make default") then
      grammar_view = run(state, execute, {
        type = "set_default",
        component_id = variant.component_id,
      }) or grammar_view
    end
    ImGui.EndDisabled(context)
    ImGui.EndDisabled(context)

    ImGui.Separator(context)
    grammar_view =
      draw_targets(ImGui, context, "Move", variant, family_name, grammar_view, state, can_mutate, execute, "move")
    grammar_view = draw_targets(
      ImGui,
      context,
      "Alternate Uses",
      variant,
      family_name,
      grammar_view,
      state,
      can_mutate,
      execute,
      "alternate_use"
    )
    ImGui.BeginDisabled(context, not can_mutate or variant.source.status ~= "available")
    if ImGui.Button(context, "HIT Split") then
      grammar_view = run(state, execute, {
        type = "split",
        component_id = variant.component_id,
      }) or grammar_view
    end
    ImGui.EndDisabled(context)
    ImGui.SameLine(context)

    if not state.rules_open then
      if ImGui.Button(context, "Phrase Rules") then
        state.rules_open = true
        state.variant_rules_draft = copy_rules(variant.grammar_override or family.grammar)
        state.override_draft = variant.grammar_override ~= nil
      end
    else
      ImGui.Separator(context)
      state.override_draft = checkbox(ImGui, context, "Override family rules###variant_override", state.override_draft)
      if state.override_draft then
        draw_rules_editor(ImGui, context, state.variant_rules_draft, "variant")
        ImGui.BeginDisabled(context, not can_mutate)
        if ImGui.Button(context, "Save Variant override") then
          grammar_view = run(state, execute, {
            type = "set_variant_grammar",
            component_id = variant.component_id,
            grammar = state.variant_rules_draft,
          }) or grammar_view
        end
        ImGui.EndDisabled(context)
      elseif variant.grammar_override then
        ImGui.BeginDisabled(context, not can_mutate)
        if ImGui.Button(context, "Restore family inheritance") then
          grammar_view = run(state, execute, {
            type = "inherit_family_grammar",
            component_id = variant.component_id,
          }) or grammar_view
        end
        ImGui.EndDisabled(context)
      end
      if ImGui.SmallButton(context, "Done") then
        state.rules_open = false
      end
    end

    ImGui.Separator(context)
    ImGui.TextDisabled(
      context,
      "Source: " .. (variant.source.take_name or "") .. " · Track: " .. (variant.source.track_name or "")
    )
    if variant.source.item_name and variant.source.item_name ~= "" then
      ImGui.TextDisabled(context, "Item: " .. variant.source.item_name)
    end
    if variant.source.position_text then
      ImGui.TextDisabled(
        context,
        "Position: " .. variant.source.position_text .. ", duration: " .. variant.source.duration_text
      )
    end
  end
  end_panel(ImGui, context, visible)
  return grammar_view
end

function view.draw(ImGui, context, grammar_view, state, can_mutate, execute)
  state.selected_family = state.selected_family or "Main"
  state.feedback = state.feedback or nil

  if grammar_view.read_only then
    ImGui.TextWrapped(context, "Phrases are read-only: " .. tostring(grammar_view.error))
    return grammar_view
  end

  local family_visible = begin_panel(ImGui, context, "grammar_family_panel", "FAMILY")
  if family_visible then
    draw_families(ImGui, context, grammar_view, state)
  end
  end_panel(ImGui, context, family_visible)
  ImGui.Spacing(context)

  local variants_visible = begin_panel(ImGui, context, "grammar_variants_panel", state.selected_family .. " Variants")
  if variants_visible then
    grammar_view = draw_variant_rows(ImGui, context, grammar_view, state, can_mutate, execute)
    ImGui.Spacing(context)
    ImGui.BeginDisabled(context, not can_mutate)
    ImGui.PushStyleColor(context, ImGui.Col_Button, COLOUR.accent)
    ImGui.PushStyleColor(context, ImGui.Col_ButtonHovered, COLOUR.accent_hover)
    if ImGui.Button(context, "Add selected items as Main Variants", 0, UI.button_height) then
      grammar_view = run(state, execute, { type = "bulk_add" }) or grammar_view
    end
    ImGui.PopStyleColor(context, 2)
    ImGui.EndDisabled(context)
    if state.feedback then
      ImGui.TextWrapped(context, state.feedback)
    end
    ImGui.SameLine(context)
    if not state.family_rules_open then
      if ImGui.Button(context, "Edit " .. state.selected_family .. " Phrase Rules###family_rules_open") then
        state.family_rules_open = true
        state.family_rules_draft = copy_rules(grammar_view.families[state.selected_family].grammar)
      end
    else
      draw_rules_editor(ImGui, context, state.family_rules_draft, "selected_family")
      ImGui.BeginDisabled(context, not can_mutate)
      if ImGui.Button(context, "Save family Phrase Rules") then
        grammar_view = run(state, execute, {
          type = "set_family_grammar",
          family = state.selected_family,
          grammar = state.family_rules_draft,
        }) or grammar_view
      end
      ImGui.EndDisabled(context)
      ImGui.SameLine(context)
      if ImGui.SmallButton(context, "Done###family_rules_done") then
        state.family_rules_open = false
      end
    end
  end
  end_panel(ImGui, context, variants_visible)
  ImGui.Spacing(context)

  grammar_view = draw_inspector(ImGui, context, grammar_view, state, can_mutate, execute)

  local recovery_visible = begin_panel(ImGui, context, "grammar_recovery_panel", "RECOVERY", COLOUR.panel_alt)
  if recovery_visible then
    if #grammar_view.recovery == 0 then
      ImGui.TextDisabled(context, "No likely ordinary splits.")
    else
      for _, candidate in ipairs(grammar_view.recovery) do
        ImGui.TextColored(
          context,
          COLOUR.warning,
          "Likely split from " .. candidate.family .. " " .. candidate.origin_label
        )
        ImGui.TextWrapped(
          context,
          (candidate.source_name ~= "" and candidate.source_name or "Right-hand item")
            .. " begins at inferred boundary "
            .. string.format("%.3f", candidate.boundary)
            .. ". Matching source and offset."
        )
        ImGui.BeginDisabled(context, not can_mutate)
        if ImGui.Button(context, "Attach###recovery_attach_" .. candidate.fingerprint) then
          grammar_view = run(state, execute, {
            type = "attach_recovery",
            fingerprint = candidate.fingerprint,
          }) or grammar_view
        end
        ImGui.SameLine(context)
        if ImGui.Button(context, "Dismiss###recovery_dismiss_" .. candidate.fingerprint) then
          grammar_view = run(state, execute, {
            type = "dismiss_recovery",
            fingerprint = candidate.fingerprint,
          }) or grammar_view
        end
        ImGui.EndDisabled(context)
      end
    end
  end
  end_panel(ImGui, context, recovery_visible)
  return grammar_view
end

return view
