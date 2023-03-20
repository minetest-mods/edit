local function paste_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = edit.get_pointed_thing_node(player)
	end

	if not edit.player_data[player].schematic then
		minetest.chat_send_player(player:get_player_name(), "Nothing to paste.")
		return
	end

	local d = edit.player_data[player]
	local schematic = d.schematic
	local pos = edit.pointed_thing_to_pos(pointed_thing)
	if not pos then return end
	local pos = vector.add(pos, d.schematic_offset)
	local size = schematic.size
	if schematic._rotation == 90 or schematic._rotation == 270 then
		size = vector.new(size.z, size.y, size.x)
	end
	edit.player_data[player].undo_schematic = edit.schematic_from_map(pos, size)
	edit.schematic_to_map(pos, schematic)
end

minetest.register_tool("edit:paste", {
	description = "Edit Paste",
	tiles = {"edit_paste.png"},
	inventory_image = "edit_paste.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	range = 10,
	on_place = paste_on_place,
	on_secondary_use = paste_on_place,
	on_use = function(itemstack, player, pointed_thing)
		local d = edit.player_data[player]
		if not d.schematic then return end
		edit.set_schematic_rotation(d.schematic, 90)
		edit.rotate_paste_preview(player)
	end
})
