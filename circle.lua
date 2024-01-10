local function place_circle(player, pos, node)
	local player_data = edit.player_data[player]
	if
		player:get_player_control().aux1 or
		not player_data or
		not player_data.circle_luaentity
		or player_data.ignore_node_placement
	then return end

	local center = player_data.circle_luaentity._pos
	center.y = pos.y
	local radius = vector.distance(center, pos)

	if radius < 1 then
		minetest.set_node(pos, node)
		return
	else
		minetest.remove_node(pos)
	end

	local radius_rounded = math.ceil(radius) + 1
	local size = vector.new(radius_rounded * 2, 1, radius_rounded * 2)
	if size.x * size.y * size.z > edit.max_operation_volume then
		edit.display_size_error(player)
		return
	end
	player_data.undo_schematic = edit.schematic_from_map(
		vector.subtract(vector.round(center), vector.new(radius_rounded, 0, radius_rounded)),
		size
	)

	player_data.ignore_node_placement = true -- Stop infinite recursion

	-- Midpoint circle algorithm
	local x = radius
	local z = 0
	if center.z % 1 ~= 0 then -- Is the marker in the middle of a node?
		z = z + 0.5
	end
	while x >= z do
		for factor_x = -1, 1, 2 do
			for factor_z = -1, 1, 2 do
				local factor = vector.new(factor_x, 1, factor_z)
				local offset1 = vector.new(x, 0, z)
				offset1 = vector.new(
					offset1.x * factor.x,
					offset1.y * factor.y,
					offset1.z * factor.z )
				local pos1 = vector.add(center, offset1)
				edit.place_node_like_player(player, node, pos1)

				local offset2 = vector.new(
					offset1.z,
					offset1.y,
					offset1.x
				)
				local pos2 = vector.add(center, offset2)
				edit.place_node_like_player(player, node, pos2)
			end
		end

		z = z + 1
		while z * z + x * x > radius * radius do
			x = x - 1
		end
	end
	player_data.ignore_node_placement = false
end

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then return end
	return place_circle(digger, pos, {name = "air"}) or true
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not placer then return end
	return place_circle(placer, pos, newnode)
end)

local function circle_tool_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	local d = edit.player_data[player]
	if d.circle_luaentity then
		d.circle_luaentity.object:remove()
	end

	local pos = edit.get_half_node_pointed_pos(player)

	d.circle_luaentity = edit.add_marker("edit:circle", pos, player)

	d.circle_hud = player:hud_add({
		hud_elem_type = "text",
		text = "CIRCLE MODE\n\nPunch the circle center to exit.\nPress the aux1 key (E) while placing to bypass.",
		position = {x = 0.5, y = 0.8},
		z_index = 100,
		number = 0xffffff
	})
end

minetest.register_tool("edit:circle",{
	description = "Edit Circle",
	tiles = {"edit_circle.png"},
	inventory_image = "edit_circle.png",
	range = 10,
	groups = {edit_place_preview = 1,},
	on_place = circle_tool_on_place,
	on_secondary_use = circle_tool_on_place,
	_edit_get_pointed_pos = function(player)
		return edit.get_half_node_pointed_pos(player)
	end,
})

minetest.register_entity("edit:circle", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 1.1, y = 1.1},
		physical = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		backface_culling = false,
		hp_max = 1,
		textures = {
			"edit_circle.png",
			"edit_circle.png",
			"edit_circle.png",
			"edit_circle.png",
			"edit_circle.png",
			"edit_circle.png",
		},
	},
	on_deactivate = function(self)
		local player_data = edit.player_data[self._placer]
		if player_data then
			player_data.circle_luaentity = nil
			self._placer:hud_remove(player_data.circle_hud)
			player_data.circle_hud = nil
		end
	end,
})
