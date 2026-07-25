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
  selection_count = "Select exactly one audio item.",
  active_take_missing = "Selected item needs an active take.",
  audio_required = "Selected item needs available audio media.",
  source_guid_missing = "Selected item has no stable source identity.",
  selection_changed = "Selection changed. Review the item and try again.",
  name_required = "Enter an Idea name.",
  source_already_registered = "Selected item is already registered as an Idea.",
  state_invalid = "Stored HIT state is invalid.",
  state_write_failed = "REAPER could not store the Idea.",
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

local function start(lifecycle, ideas)
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
  local focus = true
  local open = true
  local selected_guid
  local draft_name = ""
  local idea_view = { ideas = {} }
  local view_error
  local loaded_revision
  local feedback

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
      candidate, selection_error = ideas.selected_audio(bound_project)
      if candidate and candidate.source_item_guid ~= selected_guid then
        selected_guid = candidate.source_item_guid
        draft_name = candidate.suggested_name
        feedback = nil
      elseif not candidate then
        selected_guid = nil
      end
    end

    local project_name = app.GetProjectName(bound_project)
    if project_name == "" then
      project_name = "Unsaved Project"
    end

    ImGui.PushFont(context, nil, FONT_SIZE)
    if focus then
      ImGui.SetNextWindowFocus(context)
      focus = false
    end
    ImGui.SetNextWindowSize(context, 520, 420, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(context, "HIT - " .. project_name .. "###HIT", open)

    if visible then
      ImGui.Text(context, "Project: " .. project_name)
      ImGui.Separator(context)

      if access.can_mutate then
        if candidate then
          ImGui.Text(context, "Selected audio: " .. candidate.suggested_name)
        else
          ImGui.TextWrapped(context, idea_error_message(selection_error))
        end
      else
        ImGui.TextWrapped(
          context,
          "Another project is active. Return to " .. project_name .. " or relaunch HIT."
        )
      end

      ImGui.BeginDisabled(context, not access.can_mutate or not candidate)
      local _
      _, draft_name = ImGui.InputText(context, "Idea name", draft_name)
      if ImGui.Button(context, "Create Idea") then
        local created, create_error = ideas.create(
          bound_project,
          candidate.source_item_guid,
          draft_name
        )
        if created then
          feedback = {
            text = "Created " .. created.name .. ".",
            created_id = created.id,
          }
          reload_ideas()
        else
          feedback = { text = idea_error_message(create_error) }
        end
      end
      ImGui.EndDisabled(context)

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
          ImGui.Text(context, current.name)
          if current.source_status == "missing" then
            ImGui.TextWrapped(context, "Source item missing.")
          elseif current.source_status == "moved" then
            ImGui.TextWrapped(context, "Source item moved.")
          else
            ImGui.TextDisabled(context, "Source item available.")
          end
        end
      end
    end

    ImGui.End(context)
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
  start(require("hit.lifecycle"), require("hit.reaper.ideas"))
end

local ok, trace = xpcall(main, debug.traceback)
if not ok then
  show_unexpected_error(trace)
end
