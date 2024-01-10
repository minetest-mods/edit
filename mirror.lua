local function do_mirror(player, pos, node)
	local d = edit.player_data[player]

	if
		player:get_player_control().aux1 or
		not d or
		not d.mirror_luaentity
		or d.ignore_node_placement
	then return end

	d.ignore_node_placement = true -- Stop infinite recursion

	local center = d.mirror_luaentity._pos
	local offset = vector.subtract(pos, center)

	-- Undo
	local length = math.max(math.abs(offset.x), math.abs(offset.z))
	local start = vector.subtract(center, vector.new(length, -offset.y, length))
	local size = vector.new(length * 2 + 1, 1, length * 2 + 1)
	d.undo_schematic = edit.schematic_from_map(start, size)

	if d.mirror_mode == "x" then
		offset.x = -offset.x
		edit.place_node_like_player(player, node, vector.add(center, offset))
	elseif d.mirror_mode == "z" then
		offset.z = -offset.z
		edit.place_node_like_player(player, node, vector.add(center, offset))
	elseif d.mirror_mode == "xz" then
		for i = 1, 4 do
			local axis = "x"
			if i % 2 == 0 then
				axis = "z"
			end
			offset[axis] = -offset[axis]
			edit.place_node_like_player(player, node, vector.add(center, offset))
		end
	elseif d.mirror_mode == "eighths" then
		for i = 1, 8 do
			local axis = "x"
			if i % 2 == 0 then
				axis = "z"
			end
			if i == 5 then
				offset = vector.new(offset.z, offset.y, offset.x)
			end
			offset[axis] = -offset[axis]
			edit.place_node_like_player(player, node, vector.add(center, offset))
		end
	end

	d.ignore_node_placement = nil
end

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then return end
	return do_mirror(digger, pos, {name = "air"})
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not placer or not placer:is_player() then return end
	return do_mirror(placer, pos, newnode)
end)

local function mirror_tool_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) or pointed_thing.type == "object" then return end

	local d = edit.player_data[player]
	if d.mirror_luaentity then
		d.mirror_luaentity.object:remove()
	end

	local pos = edit.get_half_node_pointed_pos(player)

	d.mirror_luaentity = edit.add_marker("edit:mirror", pos, player)
	d.mirror_luaentity:_update_borders()

	d.mirror_hud = player:hud_add({
		hud_elem_type = "text",
		text = "MIRROR MODE\n\nPunch center indicator to exit.\n" ..
			"Right click the center indicator to switch modes.\n" ..
			"Press the aux1 key (E) while placing to bypass.",
		position = {x = 0.5, y = 0.8},
		z_index = 100,
		number = 0xffffff
	})
end

minetest.register_tool("edit:mirror", {
	description = "Edit Mirror",
	tiles = {"edit_mirror.png"},
	inventory_image = "edit_mirror.png",
	range = 10,
	groups = {edit_place_preview = 1,},
	on_place = mirror_tool_on_place,
	on_secondary_use = mirror_tool_on_place,
	_edit_get_pointed_pos = function(player)
		return edit.get_half_node_pointed_pos(player)
	end,
})

minetest.register_entity("edit:mirror_border", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 16, y = 16, z = 0},
		physical = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		hp_max = 1,
		pointable = false,
		backface_culling = true,
		textures = {
			"edit_mirror_border.png",
			"edit_mirror_border.png",
			"edit_mirror_border.png",
			"edit_mirror_border.png",
			"edit_mirror_border.png",
			"edit_mirror_border.png",
		},
	},
})

minetest.register_entity("edit:mirror", {
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
			"edit_mirror.png",
			"edit_mirror.png",
			"edit_mirror.png",
			"edit_mirror.png",
			"edit_mirror.png",
			"edit_mirror.png",
		},
	},
	on_deactivate = function(self)
		local player_data = edit.player_data[self._placer]
		if player_data then
			player_data.mirror_luaentity = nil
			self._placer:hud_remove(player_data.mirror_hud)
			player_data.mirror_hud = nil
		end
		for i, luaentity in pairs(self._borders) do
			luaentity.object:remove()
		end
		self._borders = {}
	end,
	on_rightclick = function(self, clicker)
		local player_data = edit.player_data[self._placer]
		if player_data.mirror_mode == "x" then
			player_data.mirror_mode = "z"
		elseif player_data.mirror_mode == "z" then
			player_data.mirror_mode = "xz"
		elseif player_data.mirror_mode == "xz" then
			player_data.mirror_mode = "eighths"
		elseif player_data.mirror_mode == "eighths" then
			player_data.mirror_mode = "x"
		end
		self:_update_borders()
	end,
	_borders = {},
	_update_borders = function(self)
		local function invert_tex(luaentity)
			local texs = luaentity.object:get_properties().textures
			for i, tex in pairs(texs) do
				texs[i] = tex .. "^[invert:rgb"
			end
			luaentity.object:set_properties({textures = texs})
		end
		local player_data = edit.player_data[self._placer]

		for i, luaentity in pairs(self._borders) do
			luaentity.object:remove()
		end
		self._borders = {}

		if player_data.mirror_mode:find("x") then
			local obj_ref = minetest.add_entity(self._pos, "edit:mirror_border")
			if not obj_ref then return end
			obj_ref:set_rotation(vector.new(0, math.pi / 2, 0))
			local luaentity = obj_ref:get_luaentity()
			table.insert(self._borders, luaentity)
		end
		if player_data.mirror_mode:find("z") then
			local obj_ref = minetest.add_entity(self._pos, "edit:mirror_border")
			if not obj_ref then return end
			local luaentity = obj_ref:get_luaentity()
			invert_tex(luaentity)
			table.insert(self._borders, luaentity)
		end
		if player_data.mirror_mode == "eighths" then
			for i = 0, 7 do
				local obj_ref = minetest.add_entity(self._pos, "edit:mirror_border")
				if not obj_ref then return end
				obj_ref:set_rotation(vector.new(0, math.pi / 4 * i, 0))
				local luaentity = obj_ref:get_luaentity()
				if i % 2 == 1 then invert_tex(luaentity) end
				table.insert(self._borders, luaentity)
			end
		end
	end
})
