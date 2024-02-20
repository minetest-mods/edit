local function show_select_source_nodes_formspec(player)
	local player_data = edit.player_data[player]

		local p1 = player_data.replace1._pos
		local p2 = player_data.replace2._pos

		local start = vector.new(
			math.min(p1.x, p2.x),
			math.min(p1.y, p2.y),
			math.min(p1.z, p2.z)
		)

		local _end = vector.new(
			math.max(p1.x, p2.x),
			math.max(p1.y, p2.y),
			math.max(p1.z, p2.z)
		)

		local size = vector.add(vector.subtract(_end, start), 1)
		if size.x * size.y * size.z > edit.max_operation_volume then
			edit.display_size_error(player)
			player_data.replace1.object:remove()
			return
		end

		local all_nodes = {}
		for x = start.x, _end.x do
			for y = start.y, _end.y do
				for z = start.z, _end.z do
					local name = minetest.get_node(vector.new(x, y, z)).name
					if all_nodes[name] then
						all_nodes[name] = all_nodes[name] + 1
					else
						all_nodes[name] = 1
					end
				end
			end
		end

		if player_data.replace_source_nodes == "all" then
			player_data.replace_source_nodes = all_nodes
		elseif not player_data.replace_source_nodes then
			player_data.replace_source_nodes = {}
		end

		local formspec = "formspec_version[4]size[10.1,10.8]" ..

			-- Formspecs are only sent if the first part of the formspec is different.
			-- I mitigate this by placing an invizible button with a random
			-- label at the beginning of the formspec.
			"button[0,0;0,0;minetest_sucks;" .. math.random() .. "]" ..
			"label[0.5,0.7;Select node types to replace]" ..
			"button_exit[8.9,0.2;1,1;quit;X]" ..
			"scroll_container[0.2,1.4;9,8;scrollbar;vertical]"

		local index = 0
		for name, count in pairs(all_nodes) do
			local x = index % 9
			local y = math.floor(index / 9)
			local def = minetest.registered_nodes[name]
			local description = def and def.description or name
			local selected = player_data.replace_source_nodes[name] and "true" or ""
			formspec = formspec ..
				"item_image[" .. x .. "," .. y .. ";1,1;" .. name .. "]" ..
				"checkbox[" .. x + 0.1 .. "," .. y + 0.3 .. ";" .. name .. ";;" .. selected .. "]" ..
				"tooltip[" .. x .. "," .. y .. ";1,1;" .. description .. "]"
			index = index + 1
		end

		formspec = formspec ..
			"scroll_container_end[]" ..
			"scrollbaroptions[max=" .. (math.ceil(index / 9) - 8) * 10 .. "]" ..
			"scrollbar[9.3,1.4;0.6,8;vertical;scrollbar;0]" ..
			"button[0.2,9.6;3.5,0.8;select_all;Select All]" ..
			"button[3.9,9.6;3.5,0.8;select_none;Select None]" ..
			"button[7.9,9.6;2,1;continue;OK]"

		minetest.show_formspec(player:get_player_name(), "edit:replace_source_nodes", formspec)
end

local function replace_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = edit.get_pointed_thing_node(player)
	end

	local pos = pointed_thing.under

	local player_data = edit.player_data[player]
	if player_data.replace1 and pos then
		player_data.replace2 = edit.add_marker("edit:replace", pos, player)
		if not player_data.replace2 then return end
		show_select_source_nodes_formspec(player)
	elseif pos then
		player_data.replace1 = edit.add_marker("edit:replace", pos, player)
	end
end

minetest.register_tool("edit:replace", {
	description = "Edit Replace",
	tiles = {"edit_replace.png"},
	inventory_image = "edit_replace.png",
	range = 10,
	groups = {edit_place_preview = 1, edit_box_select_preview = 1},
	on_place = replace_on_place,
	on_secondary_use = replace_on_place,
	_edit_get_selection_points = function(player)
		local d = edit.player_data[player]
		return d.replace1 and d.replace1._pos, d.replace2 and d.replace2._pos
	end,
	_edit_get_pointed_pos = function(player)
		return edit.get_pointed_thing_node(player).under
	end,
})

minetest.register_entity("edit:replace", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 1.1, y = 1.1 },
		physical = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		backface_culling = false,
		hp_max = 1,
		textures = {
			"edit_replace.png",
			"edit_replace.png",
			"edit_replace.png",
			"edit_replace.png",
			"edit_replace.png",
			"edit_replace.png",
		},
	},
	on_deactivate = function(self)
		local player_data = edit.player_data[self._placer]
		self.remove_called = true
		if player_data then
			if player_data.replace1 and not player_data.replace1.remove_called then
				player_data.replace1.object:remove()
			end
			if player_data.replace2 and not player_data.replace2.remove_called then
				player_data.replace2.object:remove()
			end
			player_data.replace1 = nil
			player_data.replace2 = nil
		end
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "edit:replace_source_nodes" then return false end

	local d = edit.player_data[player]

	if
		not d.replace1 or not d.replace2 or
		not edit.has_privilege(player)
	then return true end

	if fields.quit then
		d.replace1.object:remove()
		d.replace_source_nodes = nil
		return true
	elseif fields.select_all then
		d.replace_source_nodes = "all"
		show_select_source_nodes_formspec(player)
		return true
	elseif fields.select_none then
		d.replace_source_nodes = nil
		show_select_source_nodes_formspec(player)
		return true
	end

	for key, value in pairs(fields) do
		if key:find(":") or key == "air" then
			if value == "true" then
				d.replace_source_nodes[key] = true
			else
				d.replace_source_nodes[key] = nil
			end
			return true
		end
	end

	if not fields.continue then return true end

	edit.player_select_item(player, "Select item to replace nodes", function(player, name)
		if
			not d.replace1 or not d.replace2 or
			not d.replace_source_nodes or
			not edit.has_privilege(player)
		then return end

		local p1 = d.replace1._pos
		local p2 = d.replace2._pos

		d.replace1.object:remove()
		local replace_source_nodes = d.replace_source_nodes
		d.replace_source_nodes = nil

		if not name then return end

		local def = minetest.registered_items[name]
		if not def then return end

		local is_node = minetest.registered_nodes[name]

		local start = vector.new(
			math.min(p1.x, p2.x),
			math.min(p1.y, p2.y),
			math.min(p1.z, p2.z)
		)
		local _end = vector.new(
			math.max(p1.x, p2.x),
			math.max(p1.y, p2.y),
			math.max(p1.z, p2.z)
		)

		local size = vector.add(vector.subtract(_end, start), 1)
		d.undo_schematic = edit.schematic_from_map(start, size)

		for x = start.x, _end.x do
			for y = start.y, _end.y do
				for z = start.z, _end.z do
					local pos = vector.new(x, y, z)
					local node = minetest.get_node(pos)
					local old_name = node.name
					node.name = name
					if replace_source_nodes[old_name] then
						if is_node then
							minetest.swap_node(pos, node)
						else
							edit.place_item_like_player(player, node, pos)
						end
					end
				end
			end
		end
	end)
	return true
end)
