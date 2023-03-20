local function fill_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = edit.get_pointed_thing_node(player)
	end

	local itemstack, pos = minetest.item_place_node(itemstack, player, pointed_thing)

	local player_data = edit.player_data
	if player_data[player].fill1_pos and pos then
		local diff = vector.subtract(player_data[player].fill1_pos, pos)
		local size = vector.add(vector.apply(diff, math.abs), 1)
		if size.x * size.y * size.z > edit.max_operation_volume then
			edit.display_size_error(player)
			minetest.remove_node(player_data[player].fill1_pos)
			player_data[player].fill1_pos = nil
			minetest.remove_node(pos)
			return
		end

		player_data[player].fill2_pos = pos
		player_data[player].fill_pointed_thing = pointed_thing

		local inv = minetest.get_inventory({type = "player", name = player:get_player_name()})
		local formspec = "size[8,6]label[2,0.5;Select item for filling]button_exit[7,0;1,1;quit;X]"
		for y = 1, 4 do
			for x = 1, 8 do
				local name = inv:get_stack("main", ((y - 1) * 8) + x):get_name()
				formspec =
					formspec ..
					"item_image_button[" ..
					(x - 1) .. "," ..
					(y + 1) .. ";1,1;" ..
					name .. ";" ..
					name .. ";]"
			end
		end
		minetest.show_formspec(player:get_player_name(), "edit:fill", formspec)
	elseif pos then
		player_data[player].fill1_pos = pos
	end
end

minetest.register_node("edit:fill",{
	description = "Edit Fill",
	tiles = {"edit_fill.png"},
	inventory_image = "edit_fill.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3, dig_immediate = 3},
	range = 10,
	on_place = fill_on_place,
	on_secondary_use = fill_on_place,
	on_destruct = function(pos)
		for player, data in pairs(edit.player_data) do
			local p1 = data.fill1_pos
			local p2 = data.fill2_pos
			if p1 and vector.equals(p1, pos) then
				data.fill1_pos = nil
				data.fill2_pos = nil
				data.fill_pointed_thing = nil
				minetest.remove_node(p1)
				return
			end
			if p2 and vector.equals(p2, pos) then
				data.fill1_pos = nil
				data.fill2_pos = nil
				data.fill_pointed_thing = nil
				minetest.remove_node(p2)
				return
			end
		end
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "edit:fill" then return false end

	minetest.close_formspec(player:get_player_name(), "edit:fill")

	local d = edit.player_data[player]
	local p1 = d.fill1_pos
	local p2 = d.fill2_pos
	local pointed_thing = d.fill_pointed_thing

	if
		not p1 or not p2 or
		not pointed_thing or
		not edit.has_privilege(player)
	then return true end

	d.fill1_pos = nil
	d.fill2_pos = nil
	d.fill_pointed_thing = nil
	minetest.remove_node(p1)
	minetest.remove_node(p2)

	local name
	local def
	for key, val in pairs(fields) do
		if key == "quit" then return true end
		if key == "" then key = "air" end

		name = key
		def = minetest.registered_items[name]

		if def then break end
	end

	if not def then return true end

	local is_node = minetest.registered_nodes[name]

	local param2
	if def.paramtype2 == "facedir" or def.paramtype2 == "colorfacedir" then
		param2 = minetest.dir_to_facedir(player:get_look_dir())
	elseif def.paramtype2 == "wallmounted" or def.paramtype2 == "colorwallmounted" then
		param2 = minetest.dir_to_wallmounted(player:get_look_dir(), true)
	end

	local on_place = def.on_place

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

	local volume = size.x * size.y * size.z
	if is_node and volume >= edit.fast_node_fill_threshold then
		local voxel_manip = VoxelManip()
		local vm_start, vm_end = voxel_manip:read_from_map(start, _end)
		local param2s = voxel_manip:get_param2_data()
		local content_ids = voxel_manip:get_data()
		local content_id = minetest.get_content_id(name)

		local ones = vector.new(1, 1, 1)
		local vm_size = vector.add(vector.subtract(vm_end, vm_start), ones)
		local voxel_area = VoxelArea:new({MinEdge = ones, MaxEdge = vm_size})
		local va_start = vector.add(vector.subtract(start, vm_start), ones)
		local va_end = vector.subtract(vector.add(va_start, size), ones)
		for i in voxel_area:iterp(va_start, va_end) do
			content_ids[i] = content_id
			param2s[i] = param2
		end
		voxel_manip:set_data(content_ids)
		voxel_manip:set_param2_data(param2s)
		voxel_manip:write_to_map(true)
		voxel_manip:update_liquids()
	else
		-- Work top to bottom so we can remove falling nodes
		for x = _end.x, start.x, -1 do
			for y = _end.y, start.y, -1 do
				for z = _end.z, start.z, -1 do
					local pos = vector.new(x, y, z)

					if is_node then
						minetest.set_node(pos, {name = name, param2 = param2})
					else
						minetest.remove_node(pos)
					end

					if on_place then
						local itemstack = ItemStack(name)
						pointed_thing.intersection_point = vector.new(x + 0.5, y, z + 0.5)
						pointed_thing.above = pos
						pointed_thing.under = pos
						on_place(itemstack, player, pointed_thing)
					end
				end
			end
		end
	end
	return true
end)