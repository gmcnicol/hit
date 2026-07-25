local codec = {}

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

  for _, current in ipairs(state.ideas) do
    assert(type(current) == "table", "state idea must be table")
    assert(type(current.id) == "string" and current.id ~= "", "state idea id must be non-empty string")
    assert(type(current.name) == "string" and current.name ~= "", "state idea name must be non-empty string")
    assert(
      type(current.source_item_guid) == "string" and current.source_item_guid ~= "",
      "state source_item_guid must be non-empty string"
    )
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
  if type(value) ~= "string" or value == "1|" or value:sub(1, 2) ~= "1|" or value:sub(-1) == "|" then
    if value == "1" then
      return { version = 1, ideas = {} }
    end
    return nil, "state_invalid"
  end

  local ideas = {}
  local ids = {}
  local sources = {}
  for record in (value:sub(3) .. "|"):gmatch("(.-)|") do
    local encoded_id, encoded_name, encoded_source = record:match("^([^;]*);([^;]*);([^;]*)$")
    if not encoded_id then
      return nil, "state_invalid"
    end

    local id = unescape(encoded_id)
    local name = unescape(encoded_name)
    local source_item_guid = unescape(encoded_source)
    if
      not id
      or id == ""
      or not name
      or name == ""
      or not source_item_guid
      or source_item_guid == ""
      or ids[id]
      or sources[source_item_guid]
    then
      return nil, "state_invalid"
    end

    ids[id] = true
    sources[source_item_guid] = true
    ideas[#ideas + 1] = {
      id = id,
      name = name,
      source_item_guid = source_item_guid,
    }
  end

  return { version = 1, ideas = ideas }
end

return codec
