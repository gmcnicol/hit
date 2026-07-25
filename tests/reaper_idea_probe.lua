-- Run from repository root: tests/run_reaper_idea_probe.sh
package.path = "src/?.lua;src/?/init.lua;" .. package.path

local ideas = require("hit.reaper.ideas")
local mode = assert(
  os.getenv("HIT_IDEA_PROBE_MODE"),
  "HIT_IDEA_PROBE_MODE must be write or reload; never run this probe in a working project"
)
local run_id = assert(os.getenv("HIT_IDEA_PROBE_RUN_ID"), "HIT_IDEA_PROBE_RUN_ID is required")
local audio_path = "/System/Library/Sounds/Glass.aiff"
local output_path = "/tmp/hit-reaper-idea-probe.txt"
local expected_path = "/tmp/hit-reaper-idea-probe.expected"
local project_path = "/tmp/hit-reaper-idea-probe.rpp"

local function item_facts(item)
  local chunk_ok, chunk = reaper.GetItemStateChunk(item, "", false)
  local guid_ok, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
  local take = reaper.GetActiveTake(item)
  assert(chunk_ok and guid_ok and take)
  local take_guid_ok, take_guid = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
  assert(take_guid_ok)
  return {
    chunk = chunk,
    guid = guid,
    position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    take_guid = take_guid,
    take_name = reaper.GetTakeName(take),
    channels = reaper.GetMediaSourceNumChannels(reaper.GetMediaItemTake_Source(take)),
  }
end

local function assert_item_unchanged(project, expected)
  local item
  for index = 0, reaper.CountMediaItems(project) - 1 do
    local current = reaper.GetMediaItem(project, index)
    local ok, guid = reaper.GetSetMediaItemInfo_String(current, "GUID", "", false)
    if ok and guid == expected.guid then
      item = current
      break
    end
  end
  assert(item, "source item missing")
  local actual = item_facts(item)
  assert(actual.chunk == expected.chunk)
  assert(actual.guid == expected.guid)
  assert(actual.position == expected.position)
  assert(actual.length == expected.length)
  assert(actual.take_guid == expected.take_guid)
  assert(actual.take_name == expected.take_name)
  assert(actual.channels == expected.channels)
end

local function only_idea(project)
  local view, load_error = ideas.load(project)
  assert(view, load_error)
  assert(#view.ideas == 1)
  return view.ideas[1]
end

local function reload()
  local expected = assert(io.open(expected_path, "r"))
  assert(expected:read("*l") == run_id, "stale probe expectation")
  local expected_id = assert(expected:read("*l"))
  local expected_source = assert(expected:read("*l"))
  local expected_chunk = expected:read("*a")
  expected:close()

  local project = reaper.EnumProjects(-1)
  assert(reaper.CountMediaItems(project) == 1)
  local item = reaper.GetMediaItem(project, 0)
  local current = only_idea(project)
  assert(current.id == expected_id)
  assert(current.source_item_guid == expected_source)
  assert(current.source_status == "available")

  local facts = item_facts(item)
  assert(facts.guid == expected_source)
  assert(facts.chunk == expected_chunk)

  local output = assert(io.open(output_path, "a"))
  output:write("reloaded_id\t", current.id, "\n")
  output:write("reloaded_source\t", current.source_item_guid, "\n")
  output:write("reloaded_status\t", current.source_status, "\n")
  output:write("reloaded_item_unchanged\ttrue\n")
  output:write("reloaded\t", run_id, "\n")
  output:close()
end

local function write()
  local audio = assert(io.open(audio_path, "rb"), "probe audio file unavailable")
  audio:close()

  local project = reaper.EnumProjects(-1)
  assert(reaper.CountTracks(project) == 0, "write probe requires a disposable empty project")

  reaper.Undo_BeginBlock2(project)
  reaper.InsertTrackAtIndex(0, false)
  local track = reaper.GetTrack(project, 0)
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  local source = assert(reaper.PCM_Source_CreateFromFile(audio_path))
  reaper.SetMediaItemTake_Source(take, source)
  local source_length = reaper.GetMediaSourceLength(source)
  assert(source_length > 0)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", source_length)
  assert(reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "Glass source", true))
  reaper.SetMediaItemSelected(item, true)
  reaper.Undo_EndBlock2(project, "HIT probe setup", -1)
  reaper.Main_SaveProjectEx(project, project_path, 8)
  assert(reaper.IsProjectDirty(project) == 0)

  local before = item_facts(item)
  local selected, selection_error = ideas.selected_audio(project)
  assert(selected, selection_error)
  assert(selected.suggested_name ~= "")
  assert(selected.source_item_guid == before.guid)

  local created, create_error = ideas.create(project, selected.source_item_guid, "  Idea A  ")
  assert(created, create_error)
  assert(created.name == "Idea A")
  assert(created.source_item_guid == before.guid)
  assert(reaper.Undo_CanUndo2(project) == "HIT: Create Idea Idea A")
  assert(reaper.IsProjectDirty(project) ~= 0)
  local created_view = only_idea(project)
  assert(created_view.id == created.id)
  assert(created_view.source_item_guid == created.source_item_guid)
  assert(created_view.source_status == "available")
  assert_item_unchanged(project, before)

  local undo_result = reaper.Undo_DoUndo2(project)
  assert(undo_result ~= 0)
  local undone, undo_load_error = ideas.load(project)
  assert(undone, undo_load_error)
  assert(#undone.ideas == 0)
  assert_item_unchanged(project, before)

  local redo_result = reaper.Undo_DoRedo2(project)
  assert(redo_result ~= 0)
  local redone = only_idea(project)
  assert(redone.id == created.id)
  assert(redone.source_item_guid == created.source_item_guid)
  assert(redone.source_status == "available")
  assert(reaper.IsProjectDirty(project) ~= 0)
  assert_item_unchanged(project, before)

  reaper.Main_SaveProjectEx(project, project_path, 8)
  assert_item_unchanged(project, before)

  local expected = assert(io.open(expected_path, "w"))
  expected:write(run_id, "\n", created.id, "\n", created.source_item_guid, "\n", before.chunk)
  expected:close()

  local output = assert(io.open(output_path, "w"))
  output:write("variant\treal_audio_adapter\n")
  output:write("reaper_version\t", reaper.GetAppVersion(), "\n")
  output:write("audio\t", audio_path, "\n")
  output:write("prefill\t", selected.suggested_name, "\n")
  output:write("created_name\t", created.name, "\n")
  output:write("created_id\t", created.id, "\n")
  output:write("created_source\t", created.source_item_guid, "\n")
  output:write("undo_label\tHIT: Create Idea Idea A\n")
  output:write("dirty_after_create\ttrue\n")
  output:write("undo_result\t", undo_result, "\n")
  output:write("ideas_after_undo\t0\n")
  output:write("redo_result\t", redo_result, "\n")
  output:write("redo_id\t", redone.id, "\n")
  output:write("redo_source\t", redone.source_item_guid, "\n")
  output:write("dirty_after_redo\ttrue\n")
  output:write("item_unchanged\ttrue\n")
  output:write("saved_project\t", project_path, "\n")
  output:write("saved\t", run_id, "\n")
  output:close()
end

local ok, trace = xpcall(function()
  if mode == "write" then
    write()
  elseif mode == "reload" then
    reload()
  else
    error("HIT_IDEA_PROBE_MODE must be write or reload")
  end
end, debug.traceback)

if not ok then
  local output = assert(io.open(output_path, mode == "write" and "w" or "a"))
  output:write("error\t", trace:gsub("\n", " | "), "\n")
  output:close()
  error(trace)
end
