edit = {}
edit.player_data = {}

edit.paste_preview_max_entities = tonumber(minetest.settings:get("edit_paste_preview_max_entities") or 2000)
edit.max_operation_volume = tonumber(minetest.settings:get("edit_max_operation_volume") or 20000)
edit.fast_node_fill_threshold = tonumber(minetest.settings:get("edit_fast_node_fill_threshold") or 2000)

minetest.register_privilege("edit", {
	description = "Allows usage of edit mod nodes",
	give_to_singleplayer = true,
	give_to_admin = true,
})

function edit.has_privilege(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name, {edit = true}) then
		return true
	else
		minetest.chat_send_player(name, "Using edit nodes requires the edit privilege.")
		return false
	end
end

function edit.display_size_error(player)
	local msg = "Operation too large. The maximum operation volume can be changed in Minetest settings."
	minetest.chat_send_player(player:get_player_name(), msg)
end

function edit.on_place_checks(player)
	return player and
		player:is_player() and
		edit.has_privilege(player)
end

function edit.reliable_show_formspec(player, name, formspec)
	-- We need to do this nonsense because there is bug in Minetest
	-- Sometimes no formspec is shown if you call minetest.show_formspec
	-- from minetest.register_on_player_receive_fields
	minetest.after(0.1, function()
		if not player or not player:is_player() then return end
		minetest.show_formspec(player:get_player_name(), name, formspec)
	end)
end

minetest.register_on_joinplayer(function(player)
	edit.player_data[player] = {
		schematic_offset = vector.new(0, 0, 0)
	}
end)

minetest.register_on_leaveplayer(function(player)
	edit.delete_paste_preview(player)
	local d = edit.player_data[player]
	if d.select_preview then
		d.select_preview:remove()
	end
	if d.place_preview then
		d.place_preview:remove()
	end
	if d.copy_luaentity1 then
		d.copy_luaentity1.object:remove()
	end
	edit.player_data[player] = nil
end)

function edit.get_pointed_thing_node(player)
	local look_dir = player:get_look_dir()
	local pos1 = player:get_pos()
	local eye_height = player:get_properties().eye_height
	pos1.y = pos1.y + eye_height
	local pos2 = vector.add(pos1, vector.multiply(look_dir, 10))
	local ray = minetest.raycast(pos1, pos2, false, false)
	for pointed_thing in ray do
		if pointed_thing.under then
			return pointed_thing
		end
	end
	local pos = vector.round(pos2)
	return { type = "node", under = pos, above = pos }
end

function edit.pointed_thing_to_pos(pointed_thing)
	local pos = pointed_thing.under
	local node = minetest.get_node_or_nil(pos)
	local def = node and minetest.registered_nodes[node.name]
	if def and def.buildable_to then
		return pos
	end

	pos = pointed_thing.above
	node = minetest.get_node_or_nil(pos)
	def = node and minetest.registered_nodes[node.name]
	if def and def.buildable_to then
		return pos
	end
end

edit.modpath = minetest.get_modpath("edit")
dofile(edit.modpath .. "/copy.lua")
dofile(edit.modpath .. "/fill.lua")
dofile(edit.modpath .. "/open.lua")
dofile(edit.modpath .. "/paste.lua")
dofile(edit.modpath .. "/preview.lua")
dofile(edit.modpath .. "/save.lua")
dofile(edit.modpath .. "/schematic.lua")
dofile(edit.modpath .. "/undo.lua")
