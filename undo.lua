local function undo_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	local schem = edit.player_data[player].undo_schematic
	if schem then
		edit.player_data[player].undo_schematic = edit.schematic_from_map(schem._pos, schem.size)
		minetest.place_schematic(schem._pos, schem, nil, nil, true)
	else
		minetest.chat_send_player(player:get_player_name(), "Nothing to undo.")
	end
end

minetest.register_tool("edit:undo", {
	description = "Edit Undo",
	inventory_image = "edit_undo.png",
	range = 10,
	on_place = undo_on_place,
	on_secondary_use = undo_on_place
})
