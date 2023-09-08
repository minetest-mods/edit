local function delete_schematics_dialog(player)
	local path = minetest.get_worldpath() .. "/schems"
	local dir_list = minetest.get_dir_list(path)
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	local formspec = "formspec_version[4]size[10,10]" ..
		"label[0.5,1;Delete Schematics from:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[8.8,0.2;1,1;quit;X]" ..
		"textlist[0.5,2;9,7;schems;" .. table.concat(dir_list, ",") .. "]"

	edit.reliable_show_formspec(player, "edit:delete_schem", formspec)
end

local function open_on_place(itemstack, player, pointed_thing)
	if not edit.on_place_checks(player) then return end

	local path = minetest.get_worldpath() .. "/schems"
	local dir_list = minetest.get_dir_list(path)
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	local formspec = "formspec_version[4]size[10,11]" ..
		"label[0.5,1;Load a schematic from:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[8.8,0.2;1,1;quit;X]" ..
		"textlist[0.5,2;9,7;schems;" .. table.concat(dir_list, ",") .. "]" ..
		"button_exit[2,9.5;6,1;delete;Delete schematics...]"

	minetest.show_formspec(player:get_player_name(), "edit:open", formspec)
end

minetest.register_tool("edit:open",{
	description = "Edit Open",
	inventory_image = "edit_open.png",
	range = 10,
	on_place = open_on_place,
	on_secondary_use = open_on_place
})

local function read_minetest_schematic(file_path)
	local schematic = minetest.read_schematic(file_path, {})
	if schematic then
		schematic._meta = {}
		schematic._timers = {}
		schematic._rotation = 0
	end
	return schematic
end

local function read_world_edit_schematic(file_path)
	local f = io.open(file_path)
	if not f then return false end
	local data = f:read("*all")
	f:close()
	if not data then return false end

	data = data:gsub("^[^:]*:", "")
	data = minetest.deserialize(data)
	if not data then return false end

	-- Get the schematic size
	local x_max, y_max, z_max = 0, 0, 0
	for i, node in pairs(data) do
		local x, y, z = node.x, node.y, node.z
		if x > x_max then x_max = x end
		if y > y_max then y_max = y end
		if z > z_max then z_max = z end
	end

	local schem_data = {}
	local meta = {}
	local timers = {}
	local size = vector.new(x_max + 1, y_max + 1, z_max + 1)

	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = size})

	for i, node in pairs(data) do
		local x, y, z = node.x + 1, node.y + 1, node.z + 1
		local index = voxel_area:index(x, y, z)

		schem_data[index] = {}
		schem_data[index].name = node.name
		schem_data[index].param2 = node.param2
		if node.meta then
			local key = minetest.hash_node_position(vector.new(x, y, z))
			meta[key] = node.meta
		end

		if node.timer then
			local key = minetest.hash_node_position(vector.new(x, y, z))
			timers[key] = node.timer
		end
	end

	-- Replace empty space with air nodes
	for i in voxel_area:iterp(start, size) do
		if not schem_data[i] then
			schem_data[i] = { name = "air" }
		end
	end

	return {
		size = size,
		data = schem_data,
		_meta = meta,
		_timers = timers,
		_rotation = 0,
	}
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "edit:open" then
		minetest.close_formspec(player:get_player_name(), "edit:open")

		if
			fields.cancel
			or not edit.has_privilege(player)
		then return true end

		if fields.delete then
			delete_schematics_dialog(player)
			return true
		end

		if not fields.schems then return end

		local index = tonumber(fields.schems:sub(5, #(fields.schems)))
		if not index then return true end
		index = math.floor(index)

		local path = minetest.get_worldpath() .. "/schems"
		local dir_list = minetest.get_dir_list(path)
		if index > 0 and index <= #dir_list then
			local file_path = path .. "/" .. dir_list[index]
			local schematic

			if file_path:sub(-4, -1) == ".mts" then
				schematic = read_minetest_schematic(file_path)
			elseif file_path:sub(-3, -1) == ".we" then
				schematic = read_world_edit_schematic(file_path)
			end

			if not schematic then
				minetest.chat_send_player(player:get_player_name(),
					"\"" .. dir_list[index] .. "\" failed to load" )
				return true
			end
			edit.player_data[player].schematic = schematic
			minetest.chat_send_player(player:get_player_name(),
				"\"" .. dir_list[index] .. "\" loaded." )
			edit.delete_paste_preview(player)
		end
		return true
	elseif formname == "edit:delete_schem" then
		if
			fields.cancel
			or not edit.has_privilege(player)
		then return true end

		if not fields.schems then return end

		local index = tonumber(fields.schems:sub(5, #(fields.schems)))
		if not index then return true end
		index = math.floor(index)

		local path = minetest.get_worldpath() .. "/schems"
		local dir_list = minetest.get_dir_list(path)
		if index > 0 and index <= #dir_list then
			edit.player_data[player].schem_for_delete = path .. "/" .. dir_list[index]
			formspec = "formspec_version[4]size[8,3.5]label[0.6,1;Confirm delete \"" ..
				dir_list[index] .. "\"]" ..
				"button_exit[0.5,2;3,1;delete;Delete]" ..
				"button_exit[4.5,2;3,1;quit;Cancel]"

			edit.reliable_show_formspec(player, "edit:confirm_delete_schem", formspec)
		end
		return true
	elseif formname == "edit:confirm_delete_schem" then
		if not edit.has_privilege(player) then return end

		if fields.delete then
			os.remove(edit.player_data[player].schem_for_delete)
		end
		edit.player_data[player].schem_for_delete = nil
		delete_schematics_dialog(player)
		return true
	end
	return false
end)
