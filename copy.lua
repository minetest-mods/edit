local function copy_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end
	if not pointed_thing.under then
		pointed_thing = edit.get_pointed_thing_node(player)
	end
	local pos = pointed_thing.under
	local d = edit.player_data[player]

	if d.copy_luaentity1 and pos then
		local p1 = d.copy_luaentity1._pos
		local p2 = pos

		d.copy_luaentity1.object:remove()
		d.copy_luaentity1 = nil

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

		local size = vector.add(vector.subtract(_end, start), vector.new(1, 1, 1))
		if size.x * size.y * size.z > edit.max_operation_volume then
			edit.display_size_error(player)
			return
		end

		d.schematic = edit.schematic_from_map(start, size)
		edit.delete_paste_preview(player)
		local function vector_to_string(v) return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")" end
		minetest.chat_send_player(
			player:get_player_name(),
			vector_to_string(start) .. " to " .. vector_to_string(_end) .. " copied." )
	else
		d.copy_luaentity1 = edit.add_marker("edit:copy", pos, player)
	end
end

minetest.register_tool("edit:copy",{
	description = "Edit Copy",
	tiles = {"edit_copy.png"},
	inventory_image = "edit_copy.png",
	range = 10,
	groups = {edit_place_preview = 1,},
	on_place = copy_on_place,
	on_secondary_use = copy_on_place,
	_edit_get_selection_points = function(player)
		local d = edit.player_data[player]
		return d.copy_luaentity1 and d.copy_luaentity1._pos
	end,
	_edit_get_pointed_pos = function(player)
		return edit.get_pointed_thing_node(player).under
	end,
})

minetest.register_entity("edit:copy", {
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
			"edit_copy.png",
			"edit_copy.png",
			"edit_copy.png",
			"edit_copy.png",
			"edit_copy.png",
			"edit_copy.png",
		},
	},
	on_death = function(self, killer)
		if edit.player_data[self._placer] then
			edit.player_data[self._placer].copy_luaentity1 = nil
		end
	end,
})
