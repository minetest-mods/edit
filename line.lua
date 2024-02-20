-- https://www.geeksforgeeks.org/bresenhams-algorithm-for-3-d-line-drawing/
-- This Site is affiliated under CCBY-SA https://www.geeksforgeeks.org/legal/copyright-information/
-- JS code for generating points on a 3-D line 
-- using Bresenham's Algorithm
-- Converted from the original to Lua
function edit.calculate_line_points(p1, p2)
	p1 = vector.copy(p1)
	p2 = vector.copy(p2)
	local output = {vector.copy(p1)}
	local d = vector.apply(vector.subtract(p1, p2), math.abs)
	local s = vector.new(
		p2.x > p1.x and 1 or -1,
		p2.y > p1.y and 1 or -1,
		p2.z > p1.z and 1 or -1
	)

	-- Driving axis is X-axis
	if d.x >= d.y and d.x >= d.z then
		local n1 = 2 * d.y - d.x
		local n2 = 2 * d.z - d.x
		while p1.x ~= p2.x do
			p1.x = p1.x + s.x
			if n1 >= 0 then
				p1.y = p1.y + s.y
				n1 = n1 - 2 * d.x
			end
			if n2 >= 0 then
				p1.z = p1.z + s.z
				n2 = n2 - 2 * d.x
			end
			n1 = n1 + 2 * d.y
			n2 = n2 + 2 * d.z
			table.insert(output, vector.copy(p1))
		end

	-- Driving axis is Y-axis
	elseif d.y >= d.x and d.y >= d.z then
		local n1 = 2 * d.x - d.y
		local n2 = 2 * d.z - d.y
		while p1.y ~= p2.y do
			p1.y = p1.y + s.y
			if n1 >= 0 then
				p1.x = p1.x + s.x
				n1 = n1 - 2 * d.y
			end
			if n2 >= 0 then
				p1.z = p1.z + s.z
				n2 = n2 - 2 * d.y
			end
			n1 = n1 + 2 * d.x
			n2 = n2 + 2 * d.z
			table.insert(output, vector.copy(p1))
		end

	-- Driving axis is Z-axis
	else
		local n1 = 2 * d.y - d.z
		local n2 = 2 * d.x - d.z
		while p1.z ~= p2.z do
			p1.z = p1.z + s.z
			if n1 >= 0 then
				p1.y = p1.y + s.y
				n1 = n1 - 2 * d.z
			end
			if n2 >= 0 then
				p1.x = p1.x + s.x
				n2 = n2 - 2 * d.z
			end
			n1 = n1 + 2 * d.y
			n2 = n2 + 2 * d.x
			table.insert(output, vector.copy(p1))
		end
	end
	return output
end

minetest.register_entity("edit:line", {
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
			"edit_line.png",
			"edit_line.png",
			"edit_line.png",
			"edit_line.png",
			"edit_line.png",
			"edit_line.png",
		},
	},
	on_deactivate = function(self)
		local player_data = edit.player_data[self._placer]
		self.remove_called = true
		if player_data then
			local line1 = player_data.line1
			if line1 and not line1.remove_called then
				line1.object:remove()
			end
			player_data.line1 = nil

			local line2 = player_data.line2
			if line2 and not line2.remove_called then
				line2.object:remove()
			end
			player_data.line2 = nil

			player_data.old_pointed_pos = nil
		end
	end,
})

local function place_line(player, item_name)
	local player_data = edit.player_data[player]
	if not player_data.line1 then return end

	if not item_name then
		player_data.line1.object:remove()
		return
	end

	local pos1 = player_data.line1._pos
	local pos2 = player_data.line2._pos

	local size = vector.add(vector.apply(vector.subtract(pos1, pos2), math.abs), vector.new(1, 1, 1))
	local pos = vector.new(
		math.min(pos1.x, pos2.x),
		math.min(pos1.y, pos2.y),
		math.min(pos1.z, pos2.z)
	)
	player_data.undo_schematic = edit.schematic_from_map(pos, size)

	local line_points = edit.calculate_line_points(pos1, pos2)
	local item = {name = item_name}
	for i, pos in pairs(line_points) do
		edit.place_item_like_player(player, item, pos)
	end
	player_data.line1.object:remove()
end

local function line_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = edit.get_pointed_thing_node(player)
	end

	local pos = edit.pointed_thing_to_pos(pointed_thing)
	if not pos then return end

	local player_data = edit.player_data[player]

	if not player_data.line1 then
		player_data.line1 = edit.add_marker("edit:line", pos, player)
		if not player_data.line1 then return end
	else
		player_data.line2 = edit.add_marker("edit:line", pos, player)
		if not player_data.line2 then return end

		local diff = vector.subtract(player_data.line1._pos, pos)
		local volume = vector.add(vector.apply(diff, math.abs), 1)
		if volume.x * volume.y * volume.z > edit.max_operation_volume then
			edit.display_size_error(player)
			player_data.line1.object:remove()
			return
		end

		edit.player_select_item(player, "Select item to fill the line", place_line)
	end
	edit.old_pointed_pos = nil
end

minetest.register_tool("edit:line", {
	description = "Edit Line",
	tiles = {"edit_line.png"},
	inventory_image = "edit_line.png",
	range = 10,
	groups = {edit_place_preview = 1,},
	on_place = line_on_place,
	on_secondary_use = line_on_place,
	_edit_get_selection_points = function(player)
		local d = edit.player_data[player]
		return d.line1 and d.line1._pos, d.line2 and d.line2._pos
	end
})
