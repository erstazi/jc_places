-- ============================================================================
-- jc_places for teleport commands with /set + /get support + xban2 jail check
-- ============================================================================

local mod_storage = core.get_mod_storage()
local mod_name = core.get_current_modname()
local S = core.get_translator(core.get_current_modname())
local xban_available = core.get_modpath("xban2") ~= nil
local prison_pos = core.settings:get_pos("prison_pos") or { x = -53, y = -7, z = 59 }

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------
-- Change this to wherever you want the places.json to be written.
-------------------------------------------------------------------------------
local PLACES_JSON = core.get_worldpath() .. "/places.json"

jc_places = {
  pos_not_set = false,
  prison_pos = prison_pos,
  places = {
    { name = "spawn", setting = "static_spawnpoint", label = S("Spawn"), web_label = "Spawn", },
    { name = "apt", setting = "apartment_pos", label = S("Apartment"),  web_label = "Apartment", },
    { name = "condos", setting = "spawncondo_pos", label = S("Condos"),  web_label = "Condos", },
    { name = "mine", setting = "mine_pos", label = S("Public Mine"), web_label = "Public Mine", },
    { name = "mall", setting = "mall_pos", label = S("Shopping Mall"), web_label = "Shopping Mall", },
    { name = "stadium", setting = "stadium_pos", label = S("Stadium"), web_label = "Stadium", },
    { name = "farm", setting = "farm_pos", label = S("Public Farm"), web_label = "Public Farm", },
    { name = "city", setting = "city_pos", label = S("City"), web_label = "City Hall", },
    { name = "horses", setting = "horses_pos", label = S("Horse Track"), web_label = "Horse Track", },
    { name = "archery", setting = "archery_pos", label = S("Archery Range"), web_label = "Archery Range", },
    { name = "church", setting = "church_pos", label = S("Church of Just-Craft"), web_label = "Church of Just-Craft", },
    { name = "prison", setting = "prison_visitor_pos", label = S("Prison Visitation"), web_label = "Prison", },
  },
}

-- ========================
-- Helper functions
-- ========================

function jc_places.get_pos(place)
  -- Try mod_storage first
  local str = mod_storage:get_string("pos_" .. place.name)

  if str and str ~= "" then
    return core.string_to_pos(str)
  end

  -- Fallback to old settings
  if place.setting then
    return core.setting_get_pos(place.setting)
  end

  return nil
end

local function set_pos(place, pos)
  mod_storage:set_string("pos_" .. place.name, core.pos_to_string(pos) )
end

-- ========================
-- Reusable registration
-- ========================
local function jc_places_register_place(place)
  core.register_chatcommand(place.name, {
    params = "[set|get]",
    description = S("Teleport to @1", place.label),
    func = function(player_name, params)
      local player = core.get_player_by_name(player_name)
      if not player then
        return false, S("Player not found")
      end

      -- ==========================================
      -- XBAN JAIL CHECK
      -- ==========================================
      if xban_available and xban and xban.get_property(player_name, "jailed") then
        player:set_pos(jc_places.prison_pos)
        return true, S("Nice try! You can't escape!")
      end

      -- ==========================================
      -- /place set
      -- ==========================================
      if params:match("^set$") then
        if core.check_player_privs(player_name, {server = true}) then
          local pos = vector.floor(player:get_pos())
          set_pos(place, pos)
          return true, core.colorize("lightgreen", "-!- " .. S("@1 position updated!", place.label) )
        else
          return true, core.colorize( "#FF7C7C", "-!- " .. S("No permission to set position!") )
        end

      -- ==========================================
      -- /place get
      -- ==========================================
      elseif params:match("^get$") then
        local target_pos = jc_places.get_pos(place)
        if target_pos then
          local coordinates = string.format("(%d,%d,%d)", target_pos.x, target_pos.y, target_pos.z )
          return true, core.colorize("yellow", place.label .. ": " .. coordinates )
        else
          return true, core.colorize("#FF7C7C", "-!- " .. S("Position for @1 is not set!", place.label) )
        end

      -- ==========================================
      -- /place
      -- ==========================================
      else
        local target_pos = jc_places.get_pos(place)
        if target_pos and target_pos.x ~= 0 then
          local safe_pos = { x = target_pos.x, y = target_pos.y + 1, z = target_pos.z }
          player:set_pos(safe_pos)
          core.log("action", string.format("[" .. mod_name .. "] %s teleported to %s at %s", player_name, place.web_label, core.pos_to_string(safe_pos, 0) ) )
          return true, S("Teleported to @1...", place.label)
        else
          return true, core.colorize("#FF7C7C", "-!- " .. S("Position for @1 is not set!", place.label) )
        end
      end
    end,
  })
end


-- ========================
-- Register Places
-- ========================
for _, place in ipairs(jc_places.places) do
  jc_places_register_place(place)
end


function jc_places.show_places(name)
  local player = core.get_player_by_name(name)

  if not player then
    return false, S("Player not found")
  end

  local row_height = 0.9
  local scroll_height = 6.2
  -- local scroll_max = math.max(0, (#jc_places.places * row_height) - scroll_height)
  local scroll_max = math.max(0, math.ceil((#jc_places.places * row_height) - scroll_height))

  local formspec =
      "formspec_version[4]"
    .. "size[11,9]"
    .. default.gui_bg
    .. default.gui_bg_img
    -- .. "label[0.5,0.4;" .. core.formspec_escape(S("Available Teleports")) .. "]"
    .. "label[0.5,0.4;" .. core.formspec_escape(S("Available Teleports")) .. "  " .. core.formspec_escape(core.colorize("#FFFF00", "/places")) .. "]"
    .. "box[0.4,1.0;9.9,6.6;#111111]"
    .. "scroll_container[0.6,1.2;9.5,6.2;jc_places_scroll;vertical;1]"

  for i, place in ipairs(jc_places.places) do
    local y = 0.2 + ((i - 1) * row_height)
    formspec = formspec
      .. "label[0.2," .. y .. ";5.8,0.8;" .. core.colorize("yellow", "/" .. place.name) .. " - " .. core.formspec_escape(place.label) .. "]"
      .. "button[6.7," .. (y - 0.08) .. ";3.0,0.6;teleport_" .. place.name .. ";" .. core.formspec_escape(S("Teleport")) .. "]"
  end

  formspec = formspec
    .. "scroll_container_end[]"
    .. "scrollbaroptions[min=0;max=" .. scroll_max .. ";smallstep=1;largestep=3]"
    .. "scrollbar[10.3,1.05;0.4,6.6;vertical;jc_places_scroll;0]"
    .. "button_exit[3.5,7.9;3,0.8;close;" .. core.formspec_escape(S("Close")) .. "]"

  core.show_formspec(name, "jc_places:places", formspec)
  return true
end

-- ========================
-- /places formspec
-- ========================
core.register_chatcommand("places", {
  params = "",
  description = S("List all available teleport locations"),
  func = function(name, param)
    return jc_places.show_places(name)
  end,
})


-- ========================
-- /places button handling
-- ========================

core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "jc_places:places" then
    return false
  end

  local player_name = player:get_player_name()
  local selected_place = nil

  for _, place in ipairs(jc_places.places) do
    if fields["teleport_" .. place.name] then
      selected_place = place
      break
    end
  end

  if selected_place then
    local target_pos = jc_places.get_pos(selected_place)

    if target_pos and target_pos.x ~= 0 then
      local safe_pos = {
        x = target_pos.x,
        y = target_pos.y + 1,
        z = target_pos.z
      }

      -- ==========================================
      -- xban JAIL CHECK
      -- ==========================================
      if xban_available and xban and xban.get_property(player_name, "jailed") then
        player:set_pos(jc_places.prison_pos)
        core.close_formspec(player_name, "jc_places:places")
        core.chat_send_player(player_name, S("Nice try! You can't escape!") )
        return true
      end
      player:set_pos(safe_pos)
      core.close_formspec(player_name, "jc_places:places")
      core.log("action", string.format("[" .. mod_name .. "] %s teleported to %s at %s", player_name, selected_place.web_label, core.pos_to_string(safe_pos, 0) ) )
      core.chat_send_player(player_name, S("Teleported to @1...", selected_place.label) )
      return true
    else
      core.chat_send_player(player_name, core.colorize("#FF7C7C", "-!- " .. S("Position for @1 is not set!", selected_place.label) ) )
      return true
    end
  end

  return false
end)

-------------------------------------------------------------------------------
-- JSON encoder and Helper Functions
-------------------------------------------------------------------------------
local function json_escape(str)
  str = tostring(str)

  str = str:gsub("\\", "\\\\")
  str = str:gsub("\"", "\\\"")
  str = str:gsub("\b", "\\b")
  str = str:gsub("\f", "\\f")
  str = str:gsub("\n", "\\n")
  str = str:gsub("\r", "\\r")
  str = str:gsub("\t", "\\t")

  return str
end

local function json_encode(value)
  local value_type = type(value)

  -- ------------------------------------------------------------
  -- String
  -- ------------------------------------------------------------
  if value_type == "string" then
    return "\"" .. json_escape(value) .. "\""

  -- ------------------------------------------------------------
  -- Number
  -- ------------------------------------------------------------
  elseif value_type == "number" then
    if value ~= value then
      return "null"
    end

    if value == math.huge or value == -math.huge then
      return "null"
    end

    return tostring(value)

  -- ------------------------------------------------------------
  -- Boolean
  -- ------------------------------------------------------------
  elseif value_type == "boolean" then
    return value and "true" or "false"

  -- ------------------------------------------------------------
  -- Nil
  -- ------------------------------------------------------------
  elseif value_type == "nil" then
    return "null"

  -- ------------------------------------------------------------
  -- Table
  -- ------------------------------------------------------------
  elseif value_type == "table" then
    local parts = {}
    local is_array = true
    local count = 0

    -- Determine whether this is an array.
    for key, _ in pairs(value) do
      count = count + 1

      if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
        is_array = false
        break
      end
    end

    -- ----------------------------------------------------------
    -- JSON array
    -- ----------------------------------------------------------
    if is_array then
      for i = 1, count do
        parts[#parts + 1] = json_encode(value[i])
      end

      return "[" .. table.concat(parts, ",") .. "]"

    -- ----------------------------------------------------------
    -- JSON object
    -- ----------------------------------------------------------
    else
      for key, item in pairs(value) do
        parts[#parts + 1] =
          "\"" .. json_escape(key) .. "\":" .. json_encode(item)
      end

      table.sort(parts)

      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  return "null"
end

-------------------------------------------------------------------------------
-- Get /places information
-------------------------------------------------------------------------------
local function get_places_data()
  local places = {}

  -- Make sure jc_places is loaded.
  if not jc_places or not jc_places.places then
    return places
  end

  for _, place in ipairs(jc_places.places) do
    local pos = jc_places.get_pos(place)

    if pos then
      places[#places + 1] = {
        name = place.name,
        label = place.web_label or place.name,
        x = math.floor(pos.x),
        y = math.floor(pos.y),
        z = math.floor(pos.z),
      }
    end
  end

  local data = {
    places = places,
    updated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  return data
end

-------------------------------------------------------------------------------
-- Write places JSON file
-------------------------------------------------------------------------------
local function write_places_json()
  local data = get_places_data()
  local json = json_encode(data)

  -- This prevents the website from ever seeing a partially-written JSON file.
  local temp_file = PLACES_JSON .. ".tmp"

  local file, err = io.open(temp_file, "w")

  if not file then
    core.log("error", "[" .. mod_name .. "] Could not open places JSON for writing: " .. tostring(err) )
    return false
  end

  file:write(json)
  file:write("\n")
  file:close()

  -- Replace the old JSON with the newly generated one.
  local success, rename_err = os.rename(temp_file, PLACES_JSON)

  if not success then
    core.log("error", "[" .. mod_name .. "] Could not replace places JSON: " .. tostring(rename_err) )

    os.remove(temp_file)

    return false
  end

  core.log("action", "[" .. mod_name .. "] places JSON updated: " .. PLACES_JSON )

  return true
end

-------------------------------------------------------------------------------
-- Initial update
-------------------------------------------------------------------------------
write_places_json()