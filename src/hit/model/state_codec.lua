local idea = require("hit.model.idea")
local codec = {}

local function name_is_valid(name)
  return name ~= ""
    and name == name:match("^%s*(.-)%s*$")
    and not name:find("[%z\1-\31\127]")
end

local function escape(value)
  return (value:gsub("([^A-Za-z0-9%-%._~])", function(character)
    return string.format("%%%02X", string.byte(character))
  end))
end

local function unescape(value)
  local position = 1
  while true do
    local percent = value:find("%", position, true)
    if not percent then
      break
    end
    if not value:sub(percent + 1, percent + 2):match("^%x%x$") then
      return nil
    end
    position = percent + 3
  end

  local plain = value:gsub("%%(%x%x)", "")
  if plain:find("[^A-Za-z0-9%-%._~]") then
    return nil
  end

  return (value:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

function codec.encode(state)
  assert(type(state) == "table", "state must be table")
  assert(state.version == 1, "state version must be 1")
  assert(type(state.ideas) == "table", "state ideas must be table")

  local records = { "1" }
  local count = 0
  for key in pairs(state.ideas) do
    assert(type(key) == "number" and key >= 1 and key % 1 == 0, "state ideas must be array")
    count = count + 1
  end
  assert(count == #state.ideas, "state ideas must be contiguous")

  local ids = {}
  for _, current in ipairs(state.ideas) do
    assert(type(current) == "table", "state idea must be table")
    assert(idea.guid_is_valid(current.id), "state idea id must be GUID")
    assert(not ids[current.id], "state idea id must be unique")
    assert(type(current.name) == "string" and name_is_valid(current.name), "state idea name must be valid string")
    assert(
      idea.guid_is_valid(current.source_item_guid),
      "state source_item_guid must be GUID"
    )
    ids[current.id] = true
    records[#records + 1] = table.concat({
      escape(current.id),
      escape(current.name),
      escape(current.source_item_guid),
    }, ";")
  end

  return table.concat(records, "|")
end

function codec.decode(value)
  if value == nil or value == "" then
    return { version = 1, ideas = {} }
  end
  if type(value) == "string" then
    local version = value:match("^(%d+)$") or value:match("^(%d+)|")
    if version and version ~= "1" then
      return nil, "state_version_unsupported"
    end
  end
  if type(value) ~= "string" or value == "1|" or value:sub(1, 2) ~= "1|" or value:sub(-1) == "|" then
    if value == "1" then
      return { version = 1, ideas = {} }
    end
    return nil, "state_invalid"
  end

  local ideas = {}
  local ids = {}
  for record in (value:sub(3) .. "|"):gmatch("(.-)|") do
    local encoded_id, encoded_name, encoded_source = record:match("^([^;]*);([^;]*);([^;]*)$")
    if not encoded_id then
      return nil, "state_invalid"
    end

    local id = unescape(encoded_id)
    local name = unescape(encoded_name)
    local source_item_guid = unescape(encoded_source)
    if
      not idea.guid_is_valid(id)
      or not name
      or not name_is_valid(name)
      or not idea.guid_is_valid(source_item_guid)
      or ids[id]
    then
      return nil, "state_invalid"
    end

    ids[id] = true
    ideas[#ideas + 1] = {
      id = id,
      name = name,
      source_item_guid = source_item_guid,
    }
  end

  return { version = 1, ideas = ideas }
end

return codec
