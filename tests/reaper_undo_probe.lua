-- Verified 2026-07-25: REAPER 7.77/macOS-arm64.
-- Run from the repository root: tests/run_reaper_undo_probe.sh
local mode = assert(
  os.getenv("HIT_UNDO_PROBE_MODE"),
  "HIT_UNDO_PROBE_MODE must be write or reload; never run this probe in a working project"
)
local run_id = assert(os.getenv("HIT_UNDO_PROBE_RUN_ID"), "HIT_UNDO_PROBE_RUN_ID is required")
local output_path = "/tmp/hit-reaper-undo-probe.txt"
local project_path = "/tmp/hit-reaper-undo-probe.rpp"
local section = "HIT_UNDO_PROBE"
local key = "state"
local track_parameter = "P_EXT:HIT_UNDO_PROBE"
local value = "same-id-after-redo"

local function project_state(project)
  return reaper.GetProjExtState(project, section, key)
end

local function track_state(track)
  return reaper.GetSetMediaTrackInfo_String(track, track_parameter, "", false)
end

local function reload()
  local project = reaper.EnumProjects(-1)
  local track = reaper.GetTrack(project, 0)
  assert(track, "saved probe project must contain its carrier track")

  local project_found, project_value = project_state(project)
  local track_found, track_value = track_state(track)
  assert(project_found == 1 and project_value == value)
  assert(track_found and track_value == value)

  local output = assert(io.open(output_path, "a"))
  output:write("reloaded_project\t", project_found, "\t", project_value, "\n")
  output:write("reloaded_track\t", tostring(track_found), "\t", track_value, "\n")
  output:write("reloaded\t", run_id, "\n")
  output:close()
end

local function write()
  local project = reaper.EnumProjects(-1)
  assert(reaper.CountTracks(project) == 0, "write probe requires a disposable empty project")

  reaper.Undo_BeginBlock2(project)
  reaper.InsertTrackAtIndex(0, false)
  local track = reaper.GetTrack(project, 0)
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemSelected(item, true)
  reaper.Undo_EndBlock2(project, "HIT probe setup", -1)

  reaper.Undo_BeginBlock2(project)
  reaper.SetProjExtState(project, section, key, value)
  reaper.GetSetMediaTrackInfo_String(track, track_parameter, value, true)
  reaper.MarkTrackItemsDirty(track, item)
  reaper.MarkProjectDirty(project)
  reaper.Undo_EndBlock2(project, "HIT: Probe project state undo", -1)

  local project_created, project_created_value = project_state(project)
  local track_created, track_created_value = track_state(track)
  local dirty_after_create = reaper.IsProjectDirty(project)

  reaper.defer(function()
    local undo_result = reaper.Undo_DoUndo2(project)
    local project_after_undo, project_undo_value = project_state(project)
    local track_after_undo, track_undo_value = track_state(track)

    reaper.defer(function()
      local redo_result = reaper.Undo_DoRedo2(project)
      local project_after_redo, project_redo_value = project_state(project)
      local track_after_redo, track_redo_value = track_state(track)
      local dirty_after_redo = reaper.IsProjectDirty(project)

      local output = assert(io.open(output_path, "w"))
      output:write("variant\tproject_extstate_with_track_carrier\n")
      output:write("reaper_version\t", reaper.GetAppVersion(), "\n")
      output:write("project_created\t", project_created, "\t", project_created_value, "\n")
      output:write("track_created\t", tostring(track_created), "\t", track_created_value, "\n")
      output:write("dirty_after_create\t", dirty_after_create, "\n")
      output:write("undo_result\t", undo_result, "\n")
      output:write("project_after_undo\t", project_after_undo, "\t", project_undo_value, "\n")
      output:write("track_after_undo\t", tostring(track_after_undo), "\t", track_undo_value, "\n")
      output:write("redo_result\t", redo_result, "\n")
      output:write("project_after_redo\t", project_after_redo, "\t", project_redo_value, "\n")
      output:write("track_after_redo\t", tostring(track_after_redo), "\t", track_redo_value, "\n")
      output:write("dirty_after_redo\t", dirty_after_redo, "\n")
      output:close()

      assert(project_created == 1 and project_created_value == value)
      assert(undo_result ~= 0 and project_after_undo == 1 and project_undo_value == value)
      assert(redo_result ~= 0 and project_after_redo == 1 and project_redo_value == value)
      assert(track_created and track_created_value == value)
      assert(not track_after_undo and track_undo_value == "")
      assert(track_after_redo and track_redo_value == value)
      reaper.Main_SaveProjectEx(project, project_path, 0)
      local saved_output = assert(io.open(output_path, "a"))
      saved_output:write("saved_project\t", project_path, "\n")
      saved_output:write("saved\t", run_id, "\n")
      saved_output:close()
    end)
  end)
end

if mode == "write" then
  write()
elseif mode == "reload" then
  reload()
else
  error("HIT_UNDO_PROBE_MODE must be write or reload")
end
