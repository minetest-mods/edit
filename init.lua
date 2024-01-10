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
	for key, value in pairs(edit.player_data[player]) do
		if type(value) == "table" and value.object then
			value.object:remove()
		end
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
	return old_register_on_dignode(func)
end

local old_register_on_placenode = minetest.register_on_placenode
local registered_on_placenode = {}
minetest.register_on_placenode = function(func)
	table.insert(registered_on_placenode, func)
	return old_register_on_placenode(func)
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

local function player_select_node_formspec(player)
	local d = edit.player_data[player]
	local search_value = d.player_select_node_search_value
	local doing_search = #search_value > 0
	local inv = minetest.get_inventory({type = "player", name = player:get_player_name()})
	local size = doing_search and 12 * 8 or inv:get_size("main")
	local width = doing_search and 12 or inv:get_width("main")
	if width <= 0 then width = 8 end

	local formspec_width = math.max(width, 8) + 0.4
	local formspec_height = math.ceil(size / width) + 3.4

	local search_results = {}
	if doing_search then
		local search_words = {}
		for word in search_value:gmatch("([^%s]+)") do
			table.insert(search_words, word:lower())
		end

		local search_results_done = false
		for id, def in pairs(minetest.registered_items) do
			if minetest.get_item_group(id, "not_in_creative_inventory") == 0 then
				local add_node_to_results = true
				for i, word in pairs(search_words) do
					local description = def.description:lower() or ""
					if not description:find(word) and not id:find(word) then
						add_node_to_results = false
						break
					end
				end
				if add_node_to_results then
					table.insert(search_results, id)
					if #search_results > size then
						search_results_done = true
						break
					end
				end
			end
			if search_results_done then
				break
			end
		end
	end

	local title = doing_search and "Search Results:" or "Inventory:"

	if #search_results > size then title = title .. " (some omited)" end

	local formspec = "formspec_version[4]size[" .. formspec_width .. "," .. formspec_height .. "]" ..
		"button[0,0;0,0;minetest_sucks;" .. math.random() .. "]" .. -- Force Minetest to show this formspec
		"label[0.5,0.7;" .. d.player_select_node_message .. "]" ..
		"button_exit[" .. formspec_width - 1.2 .. ",0.2;1,1;quit;X]" ..
		"field_close_on_enter[search_field;false]" ..
		"label[0.2,1.7;Search all items]" ..
		"field[0.2,2;3.5,0.8;search_field;;" .. search_value .. "]" ..
		"image_button[3.7,2;0.8,0.8;search.png^[resize:48x48;search_button;]" ..
		"button[4.5,2;0.8,0.8;cancel_search;X]" ..
		"label[5.6,2.8;" .. title .. "]"

	for i = 1, size do
		local name
		if doing_search then
			name = search_results[i]
		else
			name = inv:get_stack("main", i):get_name()
		end

		if not name then break end

		if name == "" then name = "air" end

		local index = i - 1
		local x = 0.2 + index % width
		local y = 3.2 + math.floor(index / width)
		formspec =
			formspec ..
			"item_image_button[" ..
			x .. "," ..
			y .. ";1,1;" ..
			name .. ";" ..
			name .. ";]"
	end
	edit.reliable_show_formspec(player, "edit:player_select_node", formspec)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "edit:player_select_node" then return false end
	local d = edit.player_data[player]

	for key, val in pairs(fields) do
		if key:find(":") or key == "air" then
			if d.player_select_node_callback then
				d.player_select_node_callback(player, key)
				d.player_select_node_callback = nil
				minetest.close_formspec(player:get_player_name(), "edit:player_select_node")
			end
			return true
		end
	end

	if fields.quit then
		if d.player_select_node_callback then
			d.player_select_node_callback(player, nil)
			d.player_select_node_callback = nil
		end
		return true
	elseif fields.cancel_search then
		fields.search_field = ""
	end

	if
		fields.search_field and 
		fields.search_field ~= d.player_select_node_search_value
	then
		d.player_select_node_search_value = fields.search_field
		player_select_node_formspec(player)
		return true
	end
	return true
end)

function edit.player_select_node(player, message, callback)
	local d = edit.player_data[player]
	if d.player_select_node_callback then
		d.player_select_node_callback(player, nil)
	end
	d.player_select_node_callback = callback
	d.player_select_node_search_value = d.player_select_node_search_value or ""
	d.player_select_node_message = message
	player_select_node_formspec(player)
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
dofile(edit.modpath .. "/replace.lua")
