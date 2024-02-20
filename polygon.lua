-- https://en.wikipedia.org/wiki/M%C3%B6ller%E2%80%93Trumbore_intersection_algorithm#C++_implementation
-- Converted from C++ to Lua
-- License: CC BY-SA https://creativecommons.org/licenses/by-sa/4.0/
local function ray_intersects_triangle(ray_origin, ray_vector, vertex_a, vertex_b, vertex_c)
	local epsilon = 0.0000001

	local edge1 = vector.subtract(vertex_b, vertex_a)
	local edge2 = vector.subtract(vertex_c, vertex_a)
	local ray_cross_e2 = vector.cross(ray_vector, edge2)
	local det = vector.dot(edge1, ray_cross_e2)

	if det > -epsilon and det < epsilon then
		return -- This ray is parallel to this triangle.
	end
	local inv_det = 1.0 / det
	local s = vector.subtract(ray_origin, vertex_a)
	local u = inv_det * vector.dot(s, ray_cross_e2)

	if u < 0 or u > 1 then return end

	local s_cross_e1 = vector.cross(s, edge1)
	local v = inv_det * vector.dot(ray_vector, s_cross_e1)

	if v < 0 or u + v > 1 then return end

	-- At this stage we can compute t to find out where the intersection point is on the line.
	local t = inv_det * vector.dot(edge2, s_cross_e1)

	if t > epsilon then -- ray intersection
		return vector.add(ray_origin, vector.multiply(ray_vector, t))
	else -- This means that there is a line intersection but not a ray intersection.
		return
	end
end

function edit.calculate_triangle_points(a, b, c)
	local bounding_box_min = vector.copy(a)
	local bounding_box_max = vector.copy(a)
	for index, axis in pairs({"x", "y", "z"}) do
		bounding_box_min[axis] = math.min(a[axis], b[axis], c[axis])
		bounding_box_max[axis] = math.max(a[axis], b[axis], c[axis])
	end

	-- Calculate normal
	local u = vector.subtract(b, a)
	local v = vector.subtract(c, a)
	local normal = vector.new(
		u.y * v.z - u.z * v.y,
		u.z * v.x - u.x * v.z,
		u.x * v.y - u.y * v.x
	)

	local selected_axis = "y"
	local longest_length = 0
	for axis, length in pairs(normal) do
		length = math.abs(length)
		if length > longest_length then
			longest_length = length
			selected_axis = axis
		end
	end

	-- Switch from local to global coordinate system.
	-- Also works the same to convert local to global coordinate system.
	local function swap_coord_sys(v)
		v = vector.copy(v)
		local old_selected = v[selected_axis]
		v[selected_axis] = v.y
		v.y = old_selected
		return v
	end

	local bounding_box_min_local = swap_coord_sys(bounding_box_min)
	local bounding_box_max_local = swap_coord_sys(bounding_box_max)
	local a_local = swap_coord_sys(a)
	local b_local = swap_coord_sys(b)
	local c_local = swap_coord_sys(c)

	local results = {}
	for x = bounding_box_min_local.x, bounding_box_max_local.x do
		for z = bounding_box_min_local.z, bounding_box_max_local.z do
			local intersection = ray_intersects_triangle(vector.new(x, 30928, z), vector.new(0, -1, 0), a_local, b_local, c_local)
			if intersection then
				table.insert(results, vector.round(swap_coord_sys(intersection)))
			end
		end
	end
	return results
end

local function place_polygon(player, item_name)
	local player_data = edit.player_data[player]
	if not player_data then return end
	if not item_name or #player_data.polygon_markers < 2 then
		player_data.polygon_markers.object:remove()
		return
	end

	local markers = player_data.polygon_markers

	local inf = 1 / 0
	local bounding_box_min = vector.new(inf, inf, inf)
	local bounding_box_max = vector.new(-inf, -inf, -inf)
	for index, axis in pairs({"x", "y", "z"}) do
		for i, marker in ipairs(markers) do
			bounding_box_min[axis] = math.min(bounding_box_min[axis], marker._pos[axis])
			bounding_box_max[axis] = math.max(bounding_box_max[axis], marker._pos[axis])
		end
	end
	local volume = vector.add(vector.subtract(bounding_box_max, bounding_box_min), vector.new(1, 1, 1))
	if volume.x * volume.y * volume.z > edit.max_operation_volume then
		edit.display_size_error(player)
		player_data.polygon_markers.object:remove()
		return
	end
	player_data.undo_schematic = edit.schematic_from_map(bounding_box_min, volume)

	local points = {}
	for i = 3, #markers do
		table.insert_all(
			points,
			edit.calculate_triangle_points(
				markers[i]._pos,
				markers[i - 1]._pos,
				markers[1]._pos
			)
		)
	end

	local item = {name = item_name}
	edit.place_item_like_player(player, item, markers[1]._pos)
	item.param2 = minetest.get_node(markers[1]._pos).param2
	for i, pos in pairs(points) do
		edit.place_item_like_player(player, item, pos)
	end
	player_data.polygon_markers.object:remove()
end

minetest.register_entity("edit:polygon", {
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
			"edit_polygon.png",
			"edit_polygon.png",
			"edit_polygon.png",
			"edit_polygon.png",
			"edit_polygon.png",
			"edit_polygon.png",
		},
	},
	on_deactivate = function(self)
		local player_data = edit.player_data[self._placer]
		if player_data then
			local index = table.indexof(player_data.polygon_markers, self)
			table.remove(player_data.polygon_markers, index)

			local marker = player_data.polygon_markers[1]
			if index == 1 and marker then
				local textures = marker.object:get_properties().textures
				for i, texture in pairs(textures) do
					textures[i] = texture .. "^[multiply:green"
				end
				marker.object:set_properties({textures = textures})
			end
		end
		player_data.old_pointed_pos = nil
	end,
})

local function polygon_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = edit.get_pointed_thing_node(player)
	end

	local pos = edit.pointed_thing_to_pos(pointed_thing)
	if not pos then return end

	local player_data = edit.player_data[player]

	if not player_data.polygon_markers then
		player_data.polygon_markers = {}
		player_data.polygon_markers.object = player_data.polygon_markers
		player_data.polygon_markers.object.remove = function(self)
			for i, luaentity in ipairs(table.copy(self)) do
				luaentity.object:remove()
			end
		end
	end

	if player_data.polygon_markers[1] and vector.equals(player_data.polygon_markers[1]._pos, pos) then
		edit.player_select_item(player, "Select item to fill the polygon", place_polygon)
		return
	end

	local marker = edit.add_marker("edit:polygon", pos, player)
	if not marker then return end
	table.insert(player_data.polygon_markers, marker)

	if marker == player_data.polygon_markers[1] then
		local textures = marker.object:get_properties().textures
		for i, texture in pairs(textures) do
			textures[i] = texture .. "^[multiply:green"
		end
		marker.object:set_properties({textures = textures})
	end
end

minetest.register_tool("edit:polygon", {
	description = "Edit Polygon",
	tiles = {"edit_polygon.png"},
	inventory_image = "edit_polygon.png",
	range = 10,
	groups = {edit_place_preview = 1,},
	on_place = polygon_on_place,
	on_secondary_use = polygon_on_place,
})
