local function player_select_node_formspec(player)
	edit.player_select_node(player, "Select item to use for fill", function(player, name)
		local d = edit.player_data[player]

		if
			not d.fill1 or not d.fill2 or
			not edit.has_privilege(player)
		then return end

		local p1 = d.fill1._pos
		local p2 = d.fill2._pos

		d.fill1.object:remove()

		if not name then return end

		local def = minetest.registered_items[name]

		if not def then return end

		local is_node = minetest.registered_nodes[name]

		local param2
		if def.paramtype2 == "facedir" or def.paramtype2 == "colorfacedir" then
			param2 = minetest.dir_to_facedir(player:get_look_dir())
		elseif def.paramtype2 == "wallmounted" or def.paramtype2 == "colorwallmounted" then
			param2 = minetest.dir_to_wallmounted(player:get_look_dir(), true)
		end

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
		return
	end)
end

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
		local volume = vector.add(vector.apply(diff, math.abs), 1)
		if volume.x * volume.y * volume.z > edit.max_operation_volume then
			edit.display_size_error(player)
			player_data.fill1.object:remove()
			return
		end

		player_select_node_formspec(player)
	elseif pos then
		player_data.fill1 = edit.add_marker("edit:fill", pos, player)
	end
end

minetest.register_tool("edit:fill", {
	description = "Edit Fill",
	tiles = {"edit_fill.png"},
	inventory_image = "edit_fill.png",
	range = 10,
	groups = {edit_place_preview = 1,},
	on_place = fill_on_place,
	on_secondary_use = fill_on_place,
	_edit_get_selection_points = function(player)
		local d = edit.player_data[player]
		return d.fill1 and d.fill1._pos, d.fill2 and d.fill2._pos
	end,
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
