local function show_save_dialog(player, filename, save_error, file_format_index)
	if not edit.player_data[player].schematic then
		minetest.chat_send_player(player:get_player_name(), "Nothing to save.")
		return
	end

	filename = filename or "untitled"
	file_format_index = file_format_index or 1

	local path = minetest.get_worldpath() .. "/schems"
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end

	local formspec = "formspec_version[4]size[10,6]label[0.5,1;Save schematic in:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[8.8,0.2;1,1;cancel;X]" ..
		"field[0.5,2.5;9,1;schem_filename;;" .. filename .. "]" ..
		"dropdown[0.5,4;4,1;file_format;WorldEdit (.we),Minetest (.mts);" ..
		file_format_index .. ";true]" ..
		"button_exit[5.5,4;4,1;save;Save]"

	if save_error then
		formspec = formspec ..
			"label[3,5.5;" .. save_error .. "]"
	end
	edit.reliable_show_formspec(player, "edit:save", formspec)
end

minetest.register_tool("edit:save", {
	description = "Edit Save",
	inventory_image = "edit_save.png",
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if edit.on_place_checks(player) then show_save_dialog(player) end
	end,
	on_secondary_use = function(itemstack, player, pointed_thing)
		if edit.on_place_checks(player) then show_save_dialog(player) end
	end
})

local function serialize_world_edit_schematic(schematic)
	local we = {}
	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = schematic.size})
	local data = schematic.data
	local meta = schematic._meta
	local timers = schematic._timers

	for i in voxel_area:iterp(start, schematic.size) do
		local pos = voxel_area:position(i)
		local name = data[i].name
		local hash = minetest.hash_node_position(pos)
		if name ~= "air" then
			table.insert(we, {
				x = pos.x - 1,
				y = pos.y - 1,
				z = pos.z - 1,
				name = name,
				param2 = data[i].param2,
				meta = meta[hash],
				timer = timers[hash]
			})
		end
	end
	return "5:" .. minetest.serialize(we)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "edit:save" then return false end

	minetest.close_formspec(player:get_player_name(), "edit:save")

	local schematic = edit.player_data[player].schematic
	local schem_filename = fields.schem_filename

	if
		fields.cancel or
		not schem_filename or
		not schematic or
		not fields.file_format or
		not edit.has_privilege(player)
	then return end

	if not fields.key_enter and not fields.save then
		show_save_dialog(player, fields.schem_filename, nil, fields.file_format)
		return true
	end

	local path = minetest.get_worldpath() .. "/schems"
	local file_ext = fields.file_format == "1" and ".we" or ".mts"
	local schem_filename = schem_filename .. file_ext
	local dir_list = minetest.get_dir_list(path)
	for _, filename in pairs(dir_list) do
		if filename == schem_filename then
			show_save_dialog(player, fields.schem_filename,
			"\"" .. schem_filename .. "\" already exists.", fields.file_format )
			return true
		end
	end

	local data
	if file_ext == ".we" then
		data = serialize_world_edit_schematic(schematic)
	else
		data = minetest.serialize_schematic(schematic, "mts", {})
	end

	if not data then return true end

	minetest.mkdir(path)
	local schem_path = path .. "/" .. schem_filename
	local f = io.open(schem_path, "wb")
	if not f then
		minetest.chat_send_player(player:get_player_name(), "IO error saving schematic.")
		return true
	end
	f:write(data)
	f:close()
	minetest.chat_send_player(player:get_player_name(),
		"\"" .. schem_filename .. "\" saved." )
	return true
end)
