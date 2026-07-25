local lifecycle = {}

function lifecycle.host_support(app_version, has_imgui)
  assert(type(app_version) == "string", "app_version must be string")
  assert(type(has_imgui) == "boolean", "has_imgui must be boolean")

  local major = tonumber(app_version:match("^(%d+)"))
  assert(major, "app_version must start with a major version")

  if major < 7 then
    return { ok = false, error = "reaper_version" }
  end

  if not has_imgui then
    return { ok = false, error = "reaimgui_missing" }
  end

  return { ok = true }
end

function lifecycle.project_access(bound_valid, bound_active)
  assert(type(bound_valid) == "boolean", "bound_valid must be boolean")
  assert(type(bound_active) == "boolean", "bound_active must be boolean")

  if not bound_valid then
    return { should_close = true, can_mutate = false }
  end

  if not bound_active then
    return { should_close = false, can_mutate = false }
  end

  return { should_close = false, can_mutate = true }
end

return lifecycle
