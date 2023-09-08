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
		schematic_offset = vector.new(0, 0, 0),
		mirror_mode = "x",
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
	if d.circle_luaentity then
		d.circle_luaentity.object:remove()
	end
	if d.fill1 then
		d.fill1.object:remove()
	end
	if d.fill2 then
		d.fill2.object:remove()
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
	return { type = "node", under = pos, above = pos, intersection_point = pos}
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

function edit.get_half_node_pointed_pos(player)
	local intersection_point = edit.get_pointed_thing_node(player).intersection_point

	local pos = vector.round(intersection_point)
	local pos_list = {
		pos,
		vector.add(pos, vector.new(0.5, 0, 0.5)),
		vector.add(pos, vector.new(-0.5, 0, -0.5)),
		vector.add(pos, vector.new(0.5, 0, -0.5)),
		vector.add(pos, vector.new(-0.5, 0, 0.5))
	}

	local shortest_length = 1
	local pos
	for i, p in pairs(pos_list) do
		local length = vector.length(vector.subtract(intersection_point, p))
		if length < shortest_length then
			shortest_length = length
			pos = p
		end
	end
	return pos
end

local old_register_on_dignode = minetest.register_on_dignode
local registered_on_dignode = {}
minetest.register_on_dignode = function(func)
	table.insert(registered_on_dignode, func)
	old_register_on_dignode(func)
end

local old_register_on_placenode = minetest.register_on_placenode
local registered_on_placenode = {}
minetest.register_on_placenode = function(func)
	table.insert(registered_on_placenode, func)
	old_register_on_placenode(func)
end

function edit.place_node_like_player(player, node, pos)
	local def = minetest.registered_items[node.name]
	local is_node = minetest.registered_nodes[node.name] ~= nil
	local itemstack = ItemStack(node.name)
	local pointed_thing = {
		type = "node",
		above = pos,
		under = pos,
	}
	minetest.remove_node(pos)
	def.on_place(itemstack, player, pointed_thing)

	local new_node = minetest.get_node(pos)
	if
		is_node and new_node.name == "air"
		and minetest.get_item_group(node.name, "falling_node") == 0
	then
		new_node.name = node.name
	end

	new_node.param2 = node.param2 or new_node.param2
	minetest.swap_node(pos, new_node)

	if node.name == "air" then
		local oldnode = {name = "air"}
		for i, func in pairs(registered_on_dignode) do
			func(pos, oldnode, player)
		end
	elseif is_node then
		local oldnode = {name = "air"}
		for i, func in pairs(registered_on_placenode) do
			func(pos, node, player, oldnode, itemstack, pointed_thing)
		end
	end
end

function edit.add_marker(id, pos, player)
	local obj_ref = minetest.add_entity(pos, id)
	if not obj_ref then return end
	local luaentity = obj_ref:get_luaentity()
	luaentity._pos = pos
	luaentity._placer = player
	return luaentity
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
dofile(edit.modpath .. "/circle.lua")
dofile(edit.modpath .. "/mirror.lua")
dofile(edit.modpath .. "/screwdriver.lua")
