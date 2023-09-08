local function fill_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = edit.get_pointed_thing_node(player)
	end

	local pos = edit.pointed_thing_to_pos(pointed_thing)

	local player_data = edit.player_data[player]
	if player_data.fill1 and pos then
		player_data.fill2 = edit.add_marker("edit:fill", pos, player)
		if not player_data.fill2 then return end

		local diff = vector.subtract(player_data.fill1._pos, pos)
		local size = vector.add(vector.apply(diff, math.abs), 1)
		if size.x * size.y * size.z > edit.max_operation_volume then
			edit.display_size_error(player)
			player_data.fill1.object:remove()
			return
		end

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
		player_data.fill1 = edit.add_marker("edit:fill", pos, player)
	end
end

minetest.register_tool("edit:fill", {
	description = "Edit Fill",
	tiles = {"edit_fill.png"},
	inventory_image = "edit_fill.png",
	range = 10,
	on_place = fill_on_place,
	on_secondary_use = fill_on_place,
})

minetest.register_entity("edit:fill", {
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
			"edit_fill.png",
			"edit_fill.png",
			"edit_fill.png",
			"edit_fill.png",
			"edit_fill.png",
			"edit_fill.png",
		},
	},
	on_deactivate = function(self)
		local player_data = edit.player_data[self._placer]
		self.remove_called = true
		if player_data then
			if player_data.fill1 and not player_data.fill1.remove_called then
				player_data.fill1.object:remove()
			end
			if player_data.fill2 and not player_data.fill2.remove_called then
				player_data.fill2.object:remove()
			end
			player_data.fill1 = nil
			player_data.fill2 = nil
		end
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "edit:fill" then return false end

	minetest.close_formspec(player:get_player_name(), "edit:fill")

	local d = edit.player_data[player]

	if
		not d.fill1 or not d.fill2 or
		not edit.has_privilege(player)
	then return true end

	local p1 = d.fill1._pos
	local p2 = d.fill2._pos

	d.fill1.object:remove()

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

	local on_place = def.on_place or function() end

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
		local node = {name = name, param2 = param2}
		-- Work top to bottom so we can remove falling nodes
		for x = _end.x, start.x, -1 do
			for y = _end.y, start.y, -1 do
				for z = _end.z, start.z, -1 do
					local pos = vector.new(x, y, z)
					edit.place_node_like_player(player, node, pos)
				end
			end
		end
	end
	return true
end)
