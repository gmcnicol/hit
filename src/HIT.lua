-- @description HIT - Human Intention Toolkit
-- @version 0.1.0
-- @author Gareth McNicol
-- @about
--   Structural composition environment for REAPER.

local app = reaper

local ACTION_RELAUNCH_AND_TOGGLE_ON = 1 | 2 | 4
local ACTION_TOGGLE_OFF = 8
local FONT_SIZE = 18
local REAIMGUI_INSTALL_MESSAGE = table.concat({
  "HIT requires ReaImGui 0.10.",
  "",
  "Install ReaImGui through ReaPack's default ReaTeam Extensions repository, then run HIT again.",
}, "\n")

local function show_expected_error(message)
  app.ShowMessageBox(message, "HIT", 0)
end

local function show_unexpected_error(trace)
  app.ShowConsoleMsg("[HIT] Unexpected error:\n" .. trace .. "\n")
  app.ShowMessageBox("HIT stopped after an unexpected error. See the REAPER console for details.", "HIT", 0)
end

local IDEA_ERRORS = {
  selection_none = "Select one audio or MIDI item.",
  selection_multiple = "Select only one item.",
  active_take_missing = "Selected item has no active take.",
  source_unsupported = "Selected item has no supported audio or MIDI source.",
  audio_unavailable = "Selected audio media is unavailable.",
  source_guid_missing = "Selected item has no stable source identity.",
  source_guid_invalid = "Selected item has an invalid source identity.",
  selection_changed = "Selection changed. Review the item and try again.",
  name_required = "Enter an Idea name.",
  name_invalid = "Idea name cannot contain line breaks or control characters.",
  source_already_registered = "Selected item is already registered as an Idea.",
  state_invalid = "Stored HIT state is invalid.",
  state_version_unsupported = "This project uses a newer HIT state version. Ideas are read-only.",
  state_write_failed = "REAPER could not store the Idea.",
  state_restore_failed = "REAPER could not restore HIT state after a failed write.",
  source_missing = "Source item is missing.",
  source_ambiguous = "Several items share this source identity.",
  source_unavailable = "Source media is unavailable.",
  split_cursor_outside = "Place REAPER edit cursor strictly inside selected Variant source.",
  split_failed = "REAPER could not split source item.",
  source_snapshot_failed = "Could not capture source item before split.",
  idea_missing = "Idea no longer exists.",
  variant_missing = "Variant no longer exists.",
  source_already_classified = "Source already has a Variant in that family.",
  sources_already_classified = "Selected sources are already Main Variants.",
  main_required = "Main must keep at least one Variant.",
  intensity_invalid = "Intensity must be unset or between 1 and 5.",
  grammar_invalid = "Phrase Rules are invalid.",
  project_inactive = "Return to this project before changing Phrases.",
}

local function idea_error_message(error_code)
  return IDEA_ERRORS[error_code] or ("Could not create Idea: " .. tostring(error_code))
end

local function load_imgui()
  package.path = app.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
  local ok, result = pcall(function()
    return require("imgui")("0.10")
  end)

  if not ok then
    return nil
  end

  return result
end

local function start(lifecycle, ideas, grammar_adapter, grammar_ui)
  local support = lifecycle.host_support(
    app.GetAppVersion(),
    app.APIExists("ImGui_GetBuiltinPath")
  )

  if not support.ok then
    if support.error == "reaper_version" then
      show_expected_error("HIT requires REAPER 7 or newer.")
    else
      show_expected_error(REAIMGUI_INSTALL_MESSAGE)
    end
    return
  end

  app.atexit(function()
    app.set_action_options(ACTION_TOGGLE_OFF)
  end)
  app.set_action_options(ACTION_RELAUNCH_AND_TOGGLE_ON)

  local ImGui = load_imgui()
  if not ImGui then
    show_expected_error(REAIMGUI_INSTALL_MESSAGE)
    return
  end

  local bound_project = app.EnumProjects(-1)
  assert(bound_project, "REAPER returned no active project")

  local context_flags = ImGui.ConfigFlags_NavEnableKeyboard | ImGui.ConfigFlags_DockingEnable
  local context = ImGui.CreateContext("HIT", context_flags)
  ImGui.SetConfigVar(context, ImGui.ConfigVar_NavCaptureKeyboard, 0)
  local focus = true
  local open = true
  local draft_guid
  local draft_name = ""
  local draft_dirty = false
  local idea_view = { ideas = {} }
  local view_error
  local loaded_revision
  local feedback
  local highlighted_id
  local grammar_idea_id
  local grammar_view
  local grammar_state = {}

  local function initial_grammar_state(loaded_grammar)
    local state = { selected_family = "Main" }
    local main = loaded_grammar
      and loaded_grammar.families
      and loaded_grammar.families.Main
    if main and main.default_component_id then
      state.selected_component_id = main.default_component_id
      for _, variant in ipairs(main.variants) do
        if variant.component_id == main.default_component_id then
          state.name_draft = variant.name
          break
        end
      end
    end
    return state
  end

  local function idea_for_source(source_item_guid)
    if not source_item_guid then
      return nil
    end
    for _, current in ipairs(idea_view.ideas) do
      if current.source_item_guid == source_item_guid then
        return current
      end
    end
  end

  local function reload_ideas()
    local loaded, load_error = ideas.load(bound_project)
    loaded_revision = app.GetProjectStateChangeCount(bound_project)
    if loaded then
      idea_view = loaded
      view_error = nil
    else
      idea_view = { ideas = {} }
      view_error = load_error
    end

    if feedback and feedback.created_id then
      local created_still_exists = false
      for _, current in ipairs(idea_view.ideas) do
        if current.id == feedback.created_id then
          created_still_exists = true
          break
        end
      end
      if not created_still_exists then
        feedback = nil
      end
    end

    if highlighted_id then
      local highlighted_exists = false
      for _, current in ipairs(idea_view.ideas) do
        if current.id == highlighted_id then
          highlighted_exists = true
          break
        end
      end
      if not highlighted_exists then
        highlighted_id = nil
      end
    end

    if grammar_idea_id then
      local loaded_grammar, grammar_error = grammar_adapter.open(
        bound_project,
        grammar_idea_id
      )
      if loaded_grammar then
        grammar_view = loaded_grammar
      else
        grammar_view = {
          idea_id = grammar_idea_id,
          read_only = true,
          error = grammar_error,
          families = {},
        }
      end
    end
  end

  local function frame()
    local access = lifecycle.project_access(
      app.ValidatePtr(bound_project, "ReaProject*"),
      app.EnumProjects(-1) == bound_project
    )

    if access.should_close then
      return false
    end

    local revision = app.GetProjectStateChangeCount(bound_project)
    if loaded_revision ~= revision then
      reload_ideas()
    end

    local candidate
    local selection_error
    if access.can_mutate then
      candidate, selection_error = ideas.selected_item(bound_project)
      if not draft_dirty then
        local candidate_guid = candidate and candidate.source_item_guid
        if candidate_guid ~= draft_guid then
          draft_guid = candidate_guid
          draft_name = candidate and candidate.suggested_name or ""
          feedback = nil
        end
      end

      local linked = candidate and idea_for_source(candidate.source_item_guid)
      if linked then
        highlighted_id = linked.id
      elseif not draft_dirty then
        highlighted_id = nil
      end
    end

    local project_name = app.GetProjectName(bound_project)
    if project_name == "" then
      project_name = "Unsaved Project"
    end

    ImGui.PushFont(context, nil, FONT_SIZE)
    local grammar_theme = grammar_idea_id and grammar_view
    if grammar_theme then
      grammar_ui.push_theme(ImGui, context)
    end
    if focus then
      ImGui.SetNextWindowFocus(context)
      focus = false
    end
    ImGui.SetNextWindowSize(context, 760, 720, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(context, "HIT - " .. project_name .. "###HIT", open)

    if visible then
      if grammar_idea_id and grammar_view then
        local selected_source_guid = candidate and candidate.source_item_guid
        if selected_source_guid
          and grammar_state.reaper_source_guid ~= selected_source_guid
        then
          grammar_ui.select_source_variant(
            grammar_view,
            grammar_state,
            selected_source_guid
          )
          grammar_state.reaper_source_guid = selected_source_guid
        end
        if ImGui.Button(context, "Back to Ideas") then
          grammar_idea_id = nil
          grammar_view = nil
          grammar_state = {}
        else
          ImGui.SameLine(context)
          local grammar_status = grammar_view.classified and "Classified"
            or "Main unavailable"
          ImGui.Text(
            context,
            (grammar_view.name or "Unavailable Idea")
              .. " · Phrases · "
              .. grammar_status
          )
          local function execute_grammar(command)
            if not access.can_mutate then
              return nil, "project_inactive"
            end
            local next_view, command_error, outcome = grammar_adapter.execute(
              bound_project,
              grammar_idea_id,
              command
            )
            if next_view then
              grammar_view = next_view
              loaded_revision = app.GetProjectStateChangeCount(bound_project)
            end
            return next_view, command_error, outcome
          end
          local previous_component_id = grammar_state.selected_component_id
          grammar_view = grammar_ui.draw(
            ImGui,
            context,
            grammar_view,
            grammar_state,
            access.can_mutate,
            execute_grammar
          )
          if grammar_state.selected_component_id ~= previous_component_id then
            local source_item_guid = grammar_ui.selected_source_guid(
              grammar_view,
              grammar_state
            )
            if source_item_guid then
              local selected = ideas.select_source(bound_project, source_item_guid)
              if selected then
                grammar_state.reaper_source_guid = source_item_guid
              end
            end
          end
        end
      else
        ImGui.Text(context, "Project: " .. project_name)
        ImGui.Separator(context)
        if access.can_mutate then
          if candidate then
            local selected_name = candidate.suggested_name ~= "" and candidate.suggested_name
              or "Unnamed item"
            ImGui.Text(
              context,
              "Selected " .. candidate.source_kind .. ": " .. selected_name
            )
          else
            ImGui.TextWrapped(context, idea_error_message(selection_error))
          end
        else
          ImGui.TextWrapped(
            context,
            "Another project is active. Return to " .. project_name .. " or relaunch HIT."
          )
        end

      local selection_matches_draft = candidate
        and draft_guid == candidate.source_item_guid
      local linked = candidate and idea_for_source(candidate.source_item_guid)
      local draft_detached = draft_dirty and not selection_matches_draft
      local can_edit = access.can_mutate and (candidate ~= nil or draft_guid ~= nil)

      ImGui.BeginDisabled(context, not can_edit)
      local previous_name = draft_name
      local enter_pressed
      enter_pressed, draft_name = ImGui.InputText(
        context,
        "Idea name",
        draft_name,
        ImGui.InputTextFlags_EnterReturnsTrue
      )
      ImGui.EndDisabled(context)
      if draft_name ~= previous_name then
        draft_dirty = true
        feedback = nil
      end

      if draft_detached then
        ImGui.TextWrapped(
          context,
          "Selection changed. Draft kept; select its original item or explicitly reset it."
        )

        ImGui.BeginDisabled(context, not access.can_mutate or not draft_guid)
        if ImGui.Button(context, "Select original") then
          local selected, select_error = ideas.select_source(bound_project, draft_guid)
          if selected then
            feedback = { text = "Selected original draft source." }
            reload_ideas()
          else
            feedback = { text = idea_error_message(select_error) }
          end
        end
        ImGui.EndDisabled(context)

        ImGui.BeginDisabled(context, not access.can_mutate or not candidate)
        if ImGui.Button(context, "Use current selection") then
          draft_guid = candidate.source_item_guid
          draft_name = candidate.suggested_name
          draft_dirty = false
          feedback = nil
          linked = idea_for_source(candidate.source_item_guid)
          highlighted_id = linked and linked.id or nil
        end
        ImGui.EndDisabled(context)
      end

      local create_reason
      if not access.can_mutate then
        create_reason = "Return to this project to create an Idea."
      elseif view_error then
        create_reason = idea_error_message(view_error)
      elseif not candidate then
        create_reason = "Select one available item to create an Idea."
      elseif not selection_matches_draft then
        create_reason = "Select the draft's original item or use the current selection."
      elseif linked then
        create_reason = "Selected item is already Idea " .. linked.name .. "."
      else
        local _, name_error = ideas.validate_name(draft_name)
        if name_error then
          create_reason = idea_error_message(name_error)
        end
      end
      local can_create = create_reason == nil
      local create_requested = enter_pressed and can_create

      ImGui.BeginDisabled(context, not can_create)
      if ImGui.Button(context, "Create Idea") then
        create_requested = true
      end
      ImGui.EndDisabled(context)

      if create_reason then
        ImGui.TextDisabled(context, create_reason)
      end

      if create_requested then
        local created, create_error, existing = ideas.create(
          bound_project,
          candidate.source_item_guid,
          draft_name
        )
        if created then
          draft_guid = created.source_item_guid
          draft_name = ""
          draft_dirty = false
          highlighted_id = created.id
          feedback = {
            text = "Created " .. created.name .. ".",
            created_id = created.id,
          }
          reload_ideas()
        elseif create_error == "source_already_registered" and existing then
          draft_guid = existing.source_item_guid
          draft_name = ""
          draft_dirty = false
          highlighted_id = existing.id
          feedback = { text = "Already an Idea: " .. existing.name .. "." }
        else
          feedback = { text = idea_error_message(create_error) }
        end
      end

      if feedback then
        ImGui.TextWrapped(context, feedback.text)
      end

      ImGui.Separator(context)
      ImGui.Text(context, "Ideas")
      if view_error then
        ImGui.TextWrapped(context, idea_error_message(view_error))
      elseif #idea_view.ideas == 0 then
        ImGui.TextDisabled(context, "No Ideas yet.")
      else
        for _, current in ipairs(idea_view.ideas) do
          local selected_prefix = (current.selected or current.id == highlighted_id)
              and "Selected Idea: "
            or ""
          ImGui.Text(context, selected_prefix .. current.name)
          if current.source_status == "missing" then
            ImGui.TextWrapped(context, "Source item missing.")
          elseif current.source_status == "ambiguous" then
            ImGui.TextWrapped(context, "Several items share this source identity.")
          else
            ImGui.TextDisabled(
              context,
              "Source: " .. current.source_name .. " (" .. current.source_kind .. ")"
            )
            ImGui.TextDisabled(context, "Track: " .. current.track_name)
            ImGui.TextDisabled(
              context,
              "Position: " .. current.position_text .. ", duration: " .. current.duration_text
            )
            if current.track_hidden then
              ImGui.TextWrapped(context, "Source track is hidden.")
            end
            if current.source_status == "unavailable" then
              ImGui.TextWrapped(context, "Source media is unavailable.")
            end
          end

          ImGui.BeginDisabled(
            context,
            not access.can_mutate
              or current.source_status == "missing"
              or current.source_status == "ambiguous"
          )
          if ImGui.Button(context, "Select source###select_" .. current.id) then
            local selected, select_error = ideas.select_source(
              bound_project,
              current.source_item_guid
            )
            if selected then
              highlighted_id = current.id
              feedback = { text = "Selected source for " .. current.name .. "." }
              reload_ideas()
            else
              feedback = { text = idea_error_message(select_error) }
            end
          end
          ImGui.EndDisabled(context)
          ImGui.SameLine(context)
          if ImGui.Button(context, "Phrases###grammar_" .. current.id) then
            local loaded_grammar, grammar_error = grammar_adapter.open(
              bound_project,
              current.id
            )
            grammar_idea_id = current.id
            grammar_view = loaded_grammar or {
              idea_id = current.id,
              name = current.name,
              read_only = true,
              error = grammar_error,
              families = {},
            }
            grammar_state = initial_grammar_state(grammar_view)
          end
        end
      end
      end
    end

    ImGui.End(context)
    if grammar_theme then
      grammar_ui.pop_theme(ImGui, context)
    end
    ImGui.PopFont(context)
    return open
  end

  local function loop()
    local ok, continue = xpcall(frame, debug.traceback)
    if not ok then
      show_unexpected_error(continue)
      return
    end

    if continue then
      app.defer(loop)
    end
  end

  app.defer(loop)
end

local function main()
  local script_source = debug.getinfo(1, "S").source
  local script_dir = script_source:match("^@(.+[\\/])[^\\/]+$")
  assert(script_dir, "HIT must run from a saved script")

  package.path = script_dir .. "?.lua;" .. script_dir .. "?/init.lua;" .. package.path
  start(
    require("hit.lifecycle"),
    require("hit.reaper.ideas"),
    require("hit.reaper.grammar"),
    require("hit.ui.imgui.grammar")
  )
end

local ok, trace = xpcall(main, debug.traceback)
if not ok then
  show_unexpected_error(trace)
end
