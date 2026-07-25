local output = assert(io.open("/tmp/hit-reaper-probe.txt", "w"))
output:write("reaper_version\t", reaper.GetAppVersion(), "\n")

for _, name in ipairs({
  "ImGui_GetBuiltinPath",
  "ImGui_CreateContext",
  "ImGui_GetVersion",
  "ImGui_ConfigFlags_DockingEnable",
}) do
  output:write(name, "\t", tostring(reaper.APIExists(name)), "\t", type(reaper[name]), "\n")
end

local builtin_path = reaper.ImGui_GetBuiltinPath()
output:write("builtin_path\t", tostring(builtin_path), "\n")
package.path = builtin_path .. "/?.lua;" .. package.path
local ok, result = pcall(function()
  return require("imgui")("0.10")
end)
output:write("require_imgui\t", tostring(ok), "\t", tostring(result), "\n")
if ok then
  local imgui_version, _, reaimgui_version = result.GetVersion()
  output:write("imgui_version\t", imgui_version, "\n")
  output:write("reaimgui_version\t", reaimgui_version, "\n")
end

output:close()
