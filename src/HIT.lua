-- @description HIT - Human Intention Toolkit
-- @version 0.1.0
-- @author Gareth McNicol
-- @about
--   Structural composition environment for REAPER.

local script_source = debug.getinfo(1, "S").source
local script_dir = script_source:match("^@(.+[\\/])[^\\/]+$")
assert(script_dir, "HIT must run from a saved script")

package.path = script_dir .. "?.lua;" .. script_dir .. "?/init.lua;" .. package.path

local lifecycle = require("hit.lifecycle")
local app = reaper

local ACTION_RELAUNCH_AND_TOGGLE_ON = 1 | 2 | 4
local ACTION_TOGGLE_OFF = 8
local FONT_SIZE = 18
local REAIMGUI_INSTALL_MESSAGE = table.concat({
  "HIT requires ReaImGui 0.10.",
  "",
  "Install ReaImGui through ReaPack's default ReaTeam Extensions repository, then run HIT again.",
}, "\n")

app.set_action_options(ACTION_RELAUNCH_AND_TOGGLE_ON)
app.atexit(function()
  app.set_action_options(ACTION_TOGGLE_OFF)
end)

local function show_expected_error(message)
  app.ShowMessageBox(message, "HIT", 0)
end

local function show_unexpected_error(trace)
  app.ShowConsoleMsg("[HIT] Unexpected error:\n" .. trace .. "\n")
  app.ShowMessageBox("HIT stopped after an unexpected error. See the REAPER console for details.", "HIT", 0)
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

local function start()
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

  local ImGui = load_imgui()
  if not ImGui then
    show_expected_error(REAIMGUI_INSTALL_MESSAGE)
    return
  end

  local bound_project = app.EnumProjects(-1)
  assert(bound_project, "REAPER returned no active project")

  local context_flags = ImGui.ConfigFlags_NavEnableKeyboard | ImGui.ConfigFlags_DockingEnable
  local context = ImGui.CreateContext("HIT", context_flags)
  local open = true

  local function frame()
    local access = lifecycle.project_access(
      app.ValidatePtr(bound_project, "ReaProject*"),
      app.EnumProjects(-1) == bound_project
    )

    if access.should_close then
      return false
    end

    local project_name = app.GetProjectName(bound_project)
    if project_name == "" then
      project_name = "Unsaved Project"
    end

    ImGui.PushFont(context, nil, FONT_SIZE)
    ImGui.SetNextWindowSize(context, 520, 220, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(context, "HIT - " .. project_name .. "###HIT", open)

    if visible then
      ImGui.Text(context, "Project: " .. project_name)
      ImGui.Separator(context)

      if access.can_mutate then
        ImGui.Text(context, "HIT is ready.")
      else
        ImGui.TextWrapped(
          context,
          "Another project is active. Return to " .. project_name .. " or relaunch HIT."
        )
      end

      ImGui.TextDisabled(context, "Idea creation arrives in the next slice.")
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

local ok, trace = xpcall(start, debug.traceback)
if not ok then
  show_unexpected_error(trace)
end
