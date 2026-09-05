-- ============================================================================
-- jc_places for teleport commands with /set + /get support + xban2 jail check
-- ============================================================================

local mod_storage = core.get_mod_storage()
local S = core.get_translator(core.get_current_modname())
local xban_available = core.get_modpath("xban2") ~= nil
local prison_pos = core.settings:get_pos("prison_pos") or { x = -53, y = -7, z = 59 }

jc_places = {
  pos_not_set = false,
  prison_pos = prison_pos,
  places = {
    { name = "spawn", setting = "static_spawnpoint", label = S("Spawn"), },
    { name = "apt", setting = "apartment_pos", label = S("Apartment"), },
    { name = "mine", setting = "mine_pos", label = S("Public Mine"), },
    { name = "mall", setting = "mall_pos", label = S("Shopping Mall"), },
    { name = "stadium", setting = "stadium_pos", label = S("Stadium"), },
    { name = "farm", setting = "farm_pos", label = S("Public Farm"), },
    { name = "city", setting = "city_pos", label = S("City"), },
    { name = "horses", setting = "horses_pos", label = S("Horse Track"), },
    { name = "archery", setting = "archery_pos", label = S("Archery Range"), },
    { name = "prison", setting = "prison_visitor_pos", label = S("Prison Visitation"), },
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
      core.chat_send_player(player_name, S("Teleported to @1...", selected_place.label) )
      return true
    else
      core.chat_send_player(player_name, core.colorize("#FF7C7C", "-!- " .. S("Position for @1 is not set!", selected_place.label) ) )
      return true
    end
  end

  return false
end)