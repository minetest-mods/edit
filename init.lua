-------------------
-- Edit Mod v1.1 --
-------------------

local player_data = {}

local paste_preview_max_entities = tonumber(minetest.settings:get("edit_paste_preview_max_entities") or 2000)
local max_operation_volume = tonumber(minetest.settings:get("edit_max_operation_volume") or 20000)
local use_fast_node_fill = minetest.settings:get_bool("edit_use_fast_node_fill", false)

local function create_paste_preview(player)
	local player_pos = player:get_pos()
	local base_objref = minetest.add_entity(player_pos, "edit:preview_base")
	local schematic = player_data[player].schematic

	local count = 0
	for i, map_node in pairs(schematic.data) do
		if map_node.name ~= "air" then count = count + 1 end
	end
	local probability = paste_preview_max_entities / count
	
	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = schematic.size})
	local size = schematic.size
	for i in voxel_area:iterp(start, size) do
		local pos = voxel_area:position(i)
		
		if schematic._rotation == 90 then
			pos = vector.new(pos.z, pos.y, size.x - pos.x + 1)
		elseif schematic._rotation == 180 then
			pos = vector.new(size.x - pos.x + 1, pos.y, size.z - pos.z + 1)
		elseif schematic._rotation == 270 then
			pos = vector.new(size.z - pos.z + 1, pos.y, pos.x)
		end
		
		local name = schematic.data[i].name
		if name ~= "air" and math.random() < probability then
			local attach_pos = vector.multiply(vector.subtract(vector.add(pos, schematic._offset), 1), 10)
			local objref = minetest.add_entity(player_pos, "edit:preview_node")
			objref:set_properties({wield_item = name})
			objref:set_attach(base_objref, "", attach_pos)
		end
	end
	player_data[player].paste_preview = base_objref
	player_data[player].paste_preview_yaw = 0
end

local function delete_paste_preview(player)
	local paste_preview = player_data[player].paste_preview
	if not paste_preview or not paste_preview:get_pos() then return end
	
	local objrefs = paste_preview:get_children()
	for i, objref in pairs(objrefs) do
		objref:remove()
	end
	player_data[player].paste_preview:remove()
	player_data[player].paste_preview_visable = false
	player_data[player].paste_preview = nil
end

local function set_schematic_rotation(schematic, angle)
	if not schematic._rotation then schematic._rotation = 0 end
	schematic._rotation = schematic._rotation + angle
	if schematic._rotation < 0 then
		schematic._rotation = schematic._rotation + 360
	elseif schematic._rotation > 270 then
		schematic._rotation = schematic._rotation - 360
	end
	
	local size = schematic.size
	if schematic._rotation == 90 or schematic._rotation == 270 then
		size = vector.new(size.z, size.y, size.x)
	end
	--[[local old_schematic = player_data[player].schematic
	local new_schematic = {data = {}}
	player_data[player].schematic = new_schematic
	
	local old_size = old_schematic.size
	local new_size
	if direction == "L" or direction == "R" then
		new_size = vector.new(old_size.z, old_size.y, old_size.x)
	elseif direction == "U" or direction == "D" then
		new_size = vector.new(old_size.y, old_size.x, old_size.z)
	end
	new_schematic.size = new_size
	
	local sign = vector.apply(old_schematic._offset, math.sign)
	new_schematic._offset = vector.apply(
		vector.multiply(new_size, sign),
		function(n) return n < 0 and n or 1 end
	)

	local start = vector.new(1, 1, 1)
	local old_voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = old_size})
	local new_voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = new_size})
	for old_index in old_voxel_area:iterp(start, old_schematic.size) do
		local old_pos = old_voxel_area:position(old_index)
		local new_pos
		local node = old_schematic.data[old_index]
		
		if direction == "L" then
			new_pos = vector.new(old_pos.z, old_pos.y, old_size.x - old_pos.x + 1)
		elseif direction == "R" then
			new_pos = vector.new(old_size.z - old_pos.z + 1, old_pos.y, old_pos.x)
		elseif direction == "U" then
			new_pos = vector.new(old_pos.y, old_size.x - old_pos.x + 1, old_pos.z)
		elseif direction == "D" then
			new_pos = vector.new(old_size.y - old_pos.y + 1, old_pos.x, old_pos.z)
		end
		
		local new_index = new_voxel_area:indexp(new_pos)
		new_schematic.data[new_index] = node
	end
	delete_paste_preview(player)]]
end

minetest.register_privilege("edit", {
	description = "Allows usage of edit mod nodes",
	give_to_singleplayer = true,
	give_to_admin = true,
})

local function has_privilege(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name, {edit = true}) then
		return true
	else
		minetest.chat_send_player(name, "Using edit nodes requires the edit privilege.")
		return false
	end
end

local function display_size_error(player)
	local msg = "Operation too large. The maximum operation volume can be changed in Minetest settings."
	minetest.chat_send_player(player:get_player_name(), msg)
end

local function on_place_checks(player)
	return player and
		player:is_player() and
		has_privilege(player)
end

local function schematic_from_map(pos, size)
	local schematic = {data = {}}
	schematic.size = size
	schematic._pos = pos
			
	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = size})
	
	for i in voxel_area:iterp(start, size) do
		local offset = voxel_area:position(i)
		local node_pos = vector.subtract(vector.add(pos, offset), start)
		local node = minetest.get_node(node_pos)
		node.param1 = nil
		schematic.data[i] = node
	end
	
	return schematic
end

local function get_pointed_thing_node(player)
	local look_dir = player:get_look_dir()
	local pos1 = player:get_pos()
	local eye_height = player:get_properties().eye_height
	pos1.y = pos1.y + eye_height
	local pos2 = vector.add(pos1, vector.multiply(look_dir, 10))
	local ray = minetest.raycast(pos1, pos2, false, false)
	for pointed_thing in ray do
		if pointed_thing.under then
			return pointed_thing
		end
	end
	local pos = vector.round(pos2)
	return { type = "node", under = pos, above = pos }
end

local function copy_on_place(itemstack, player, pointed_thing)
	if not on_place_checks(player) then return end
	if not pointed_thing.under then
		pointed_thing = get_pointed_thing_node(player)
	end
	local pos = pointed_thing.under

	if player_data[player].copy_luaentity1 and pos then
		local p1 = player_data[player].copy_luaentity1._pos
		local p2 = pos

		player_data[player].copy_luaentity1.object:remove()
		player_data[player].copy_luaentity1 = nil

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
		if size.x * size.y * size.z > max_operation_volume then
			display_size_error(player)
			return
		end
		
		player_data[player].schematic = schematic_from_map(start, size)
		player_data[player].schematic._offset = vector.new(0, 0, 0)
		delete_paste_preview(player)
		local function vector_to_string(v) return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")" end
		minetest.chat_send_player(
			player:get_player_name(),
			vector_to_string(start) .. " to " .. vector_to_string(_end) .. " copied." )
	else
		local obj_ref = minetest.add_entity(pos, "edit:copy")
		if not obj_ref then return end
		local luaentity = obj_ref:get_luaentity()
		luaentity._pos = pos
		luaentity._placer = player
		player_data[player].copy_luaentity1 = luaentity
	end
end

minetest.register_tool("edit:copy",{
	description = "Edit Copy",
	tiles = {"edit_copy.png"},
	inventory_image = "edit_copy.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	range = 10,
	on_place = copy_on_place,
	on_secondary_use = copy_on_place,
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
		player_data[self._placer].copy_luaentity1 = nil
	end,
})

local function pointed_thing_to_pos(pointed_thing)
	local pos = pointed_thing.under
	local node = minetest.get_node_or_nil(pos)
	local def = node and minetest.registered_nodes[node.name]
	if def and def.buildable_to then
		return pos
	end
	
	pos = pointed_thing.above
	node = minetest.get_node_or_nil(pos)
	def = node and minetest.registered_nodes[node.name]
	if def and def.buildable_to then
		return pos
	end
end

local function paste_on_place(itemstack, player, pointed_thing)
	if not on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = get_pointed_thing_node(player)
	end
	
	if not player_data[player].schematic then
		minetest.chat_send_player(player:get_player_name(), "Nothing to paste.")
		return
	end
	
	local schematic = player_data[player].schematic
	local pos = pointed_thing_to_pos(pointed_thing)
	if not pos then return end
	local pos = vector.add(pos, schematic._offset)
	local size = schematic.size
	if schematic._rotation == 90 or schematic._rotation == 270 then
		size = vector.new(size.z, size.y, size.x)
	end
	player_data[player].undo_schematic = schematic_from_map(pos, size)
	minetest.place_schematic(pos, schematic, tostring(schematic._rotation or 0), nil, true)
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
		local d = player_data[player]
		if not d.schematic then return end
		set_schematic_rotation(d.schematic, 90)
		delete_paste_preview(player)
	end
})

local function reliable_show_formspec(player, name, formspec)
	-- We need to do this nonsense because there is bug in Minetest
	-- Sometimes no formspec is shown if you call minetest.show_formspec
	-- from minetest.register_on_player_receive_fields
	minetest.after(0.1, function()
		if not player or not player:is_player() then return end
		minetest.show_formspec(player:get_player_name(), name, formspec)
	end)
end

local function delete_schematics_dialog(player)
	local path = minetest.get_worldpath() .. "/schems"
	local dir_list = minetest.get_dir_list(path)
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	local formspec = "size[10,10]label[0.5,0.5;Delete Schematics from:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[9,0;1,1;quit;X]" ..
		"textlist[0.5,2;9,7;schems;" .. table.concat(dir_list, ",") .. "]"
		
	reliable_show_formspec(player, "edit:delete_schem", formspec)
end

local function open_on_place(itemstack, player, pointed_thing)
	if not on_place_checks(player) then return end
	
	local path = minetest.get_worldpath() .. "/schems"
	local dir_list = minetest.get_dir_list(path)
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	local formspec = "size[10,10]label[0.5,0.5;Load a schematic into copy buffer from:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[9,0;1,1;quit;X]" ..
		"textlist[0.5,2;9,7;schems;" .. table.concat(dir_list, ",") .. "]" ..
		"button_exit[3,9.25;4,1;delete;Delete schematics...]"
	
	minetest.show_formspec(player:get_player_name(), "edit:open", formspec)
end

minetest.register_tool("edit:open",{
	description = "Edit Open",
	inventory_image = "edit_open.png",
	range = 10,
	on_place = open_on_place,
	on_secondary_use = open_on_place
})

local function undo_on_place(itemstack, player, pointed_thing)
	if not on_place_checks(player) then return end

	local schem = player_data[player].undo_schematic
	if schem then
		player_data[player].undo_schematic = schematic_from_map(schem._pos, schem.size)
		minetest.place_schematic(schem._pos, schem, nil, nil, true)
	else
		minetest.chat_send_player(player:get_player_name(), "Nothing to undo.")
	end
end

minetest.register_tool("edit:undo",{
	description = "Edit Undo",
	inventory_image = "edit_undo.png",
	range = 10,
	on_place = undo_on_place,
	on_secondary_use = undo_on_place
})

local function show_save_dialog(player, filename, save_error)
	if not player_data[player].schematic then
		minetest.chat_send_player(player:get_player_name(), "Nothing to save.")
		return
	end
	
	filename = filename or "untitled"
	
	local path = minetest.get_worldpath() .. "/schems"
	if #path > 40 then path = "..." .. path:sub(#path - 40, #path) end
	
	local formspec = "size[8,3]label[0.5,0.1;Save schematic in:\n" ..
		minetest.formspec_escape(path) .. "]button_exit[7,0;1,1;cancel;X]" ..
		"field[0.5,1.5;5.5,1;schem_filename;;" .. filename .. "]" ..
		"button_exit[5.7,1.2;2,1;save;Save]"
	
	if save_error then
		formspec = formspec ..
			"label[0.5,2.5;" .. save_error .. "]"
	end
	reliable_show_formspec(player, "edit:save", formspec)
end

minetest.register_tool("edit:save",{
	description = "Edit Save",
	inventory_image = "edit_save.png",
	range = 10,
	on_place = function(itemstack, player, pointed_thing)
		if on_place_checks(player) then show_save_dialog(player) end
	end,
	on_secondary_use = function(itemstack, player, pointed_thing)
		if on_place_checks(player) then show_save_dialog(player) end
	end
})

local function fill_on_place(itemstack, player, pointed_thing)
	if not on_place_checks(player) then return end

	if not pointed_thing.above then
		pointed_thing = get_pointed_thing_node(player)
	end
	
	local itemstack, pos = minetest.item_place_node(itemstack, player, pointed_thing)
	
	if player_data[player].fill1_pos and pos then
		local diff = vector.subtract(player_data[player].fill1_pos, pos)
		local size = vector.add(vector.apply(diff, math.abs), 1)
		if size.x * size.y * size.z > max_operation_volume then
			display_size_error(player)
			minetest.remove_node(player_data[player].fill1_pos)
			player_data[player].fill1_pos = nil
			minetest.remove_node(pos)
			return
		end
	
		player_data[player].fill2_pos = pos
		player_data[player].fill_pointed_thing = pointed_thing
			
		local inv = minetest.get_inventory({type = "player", name = player:get_player_name()})
		local formspec = "size[8,6]label[2,0.5;Select item for filling]button_exit[7,0;1,1;quit;X]"
		for y = 1, 4 do
			for x = 1, 8 do
				local name = inv:get_stack("main", ((y - 1) * 8) + x):get_name()
				formspec =
					formspec ..
					"item_image_button[" ..
					(x - 1) .. "," ..
					(y + 1) .. ";1,1;" ..
					name .. ";" ..
					name .. ";]"
			end
		end
		minetest.show_formspec(player:get_player_name(), "edit:fill", formspec)
	elseif pos then
		player_data[player].fill1_pos = pos
	end
end

minetest.register_node("edit:fill",{
	description = "Edit Fill",
	tiles = {"edit_fill.png"},
	inventory_image = "edit_fill.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3, dig_immediate = 3},
	range = 10,
	on_place = fill_on_place,
	on_secondary_use = fill_on_place,
	on_destruct = function(pos)
		for player, data in pairs(player_data) do
			local p1 = data.fill1_pos
			local p2 = data.fill2_pos
			if p1 and vector.equals(p1, pos) then
				data.fill1_pos = nil
				data.fill2_pos = nil
				data.fill_pointed_thing = nil
				minetest.remove_node(p1)
				return
			end
			if p2 and vector.equals(p2, pos) then
				data.fill1_pos = nil
				data.fill2_pos = nil
				data.fill_pointed_thing = nil
				minetest.remove_node(p2)
				return
			end
		end
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "edit:fill" then
		minetest.close_formspec(player:get_player_name(), "edit:fill")
		
		local p1 = player_data[player].fill1_pos
		local p2 = player_data[player].fill2_pos
		local pointed_thing = player_data[player].fill_pointed_thing
		
		if
			not p1 or not p2 or
			not pointed_thing or
			not has_privilege(player)
		then return true end
		
		player_data[player].fill1_pos = nil
		player_data[player].fill2_pos = nil
		player_data[player].fill_pointed_thing = nil
		minetest.remove_node(p1)
		minetest.remove_node(p2)
		
		local name
		local def
		for key, val in pairs(fields) do
			if key == "quit" then return true end
			if key == "" then key = "air" end

			name = key
			def = minetest.registered_items[name]
			
			if def then break end
		end
		
		if not def then return true end
			
		local is_node = minetest.registered_nodes[name]
			
		local param2
		if def.paramtype2 == "facedir" or def.paramtype2 == "colorfacedir" then
			param2 = minetest.dir_to_facedir(player:get_look_dir())
		elseif def.paramtype2 == "wallmounted" or def.paramtype2 == "colorwallmounted" then
			param2 = minetest.dir_to_wallmounted(player:get_look_dir(), true)
		end

		local on_place = def.on_place
		
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
		
		player_data[player].undo_schematic = schematic_from_map(start, size)
		
		if is_node and use_fast_node_fill then
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
			for x = start.x, _end.x, 1 do
				for y = start.y, _end.y, 1 do
					for z = start.z, _end.z, 1 do
						local pos = vector.new(x, y, z)

						if is_node then
							minetest.set_node(pos, {name = name, param2 = param2})
						else
							minetest.remove_node(pos)
						end

						if on_place then
							local itemstack = ItemStack(name)
							pointed_thing.intersection_point = vector.new(x + 0.5, y, z + 0.5)
							pointed_thing.above = pos
							pointed_thing.under = pos
							on_place(itemstack, player, pointed_thing)
						end
					end
				end
			end
		end
		return true
	elseif formname == "edit:open" then
		minetest.close_formspec(player:get_player_name(), "edit:open")
		
		if
			fields.cancel
			or not has_privilege(player)
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
			local schematic = minetest.read_schematic(file_path, {})
			if not schematic then return true end
			player_data[player].schematic = schematic
			player_data[player].schematic._offset = vector.new(0, 0, 0)
			minetest.chat_send_player(player:get_player_name(), "\"" .. dir_list[index] .. "\" loaded.")
			delete_paste_preview(player)
		end
		return true
	elseif formname == "edit:save" then
		minetest.close_formspec(player:get_player_name(), "edit:save")
	
		local schematic = player_data[player].schematic
		local schem_filename = fields.schem_filename
		
		if
			fields.cancel or
			not schem_filename or
			not schematic or
			not has_privilege(player)
		then return end
		
		local path = minetest.get_worldpath() .. "/schems"
		local schem_filename = schem_filename .. ".mts"
		local dir_list = minetest.get_dir_list(path)
		for _, filename in pairs(dir_list) do
			if filename == schem_filename then
				show_save_dialog(player, fields.schem_filename, fields.schem_filename .. " already exists.")
				return true
			end
		end
		
		local mts = minetest.serialize_schematic(schematic, "mts", {})
		if not mts then return true end
		
		minetest.mkdir(path)
		local schem_path = path .. "/" .. schem_filename
		local f = io.open(schem_path, "wb");
		if not f then
			minetest.chat_send_player(player:get_player_name(), "IO error saving schematic.")
			return true
		end
		f:write(mts);
		f:close()
		minetest.chat_send_player(player:get_player_name(), "\"" .. schem_filename .. "\" saved.")
		return true
	elseif formname == "edit:delete_schem" then
		if
			fields.cancel
			or not has_privilege(player)
		then return true end
		
		if not fields.schems then return end
		
		local index = tonumber(fields.schems:sub(5, #(fields.schems)))
		if not index then return true end
		index = math.floor(index)
		
		local path = minetest.get_worldpath() .. "/schems"
		local dir_list = minetest.get_dir_list(path)
		if index > 0 and index <= #dir_list then
			player_data[player].schem_for_delete = path .. "/" .. dir_list[index]
			formspec = "size[8,3]label[0.5,0.5;Confirm delete \"" ..
				dir_list[index] .. "\"]" ..
				"button_exit[1,2;2,1;delete;Delete]" ..
				"button_exit[5,2;2,1;quit;Cancel]"
			
			reliable_show_formspec(player, "edit:confirm_delete_schem", formspec)
		end
		return true
	elseif formname == "edit:confirm_delete_schem" then
		if not has_privilege(player) then return end
	
		if fields.delete then
			os.remove(player_data[player].schem_for_delete)
		end
		player_data[player].schem_for_delete = nil
		delete_schematics_dialog(player)
	end
	return false
end)

minetest.register_entity("edit:select_preview", {
	initial_properties = {
		visual = "cube",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		backface_culling = false,
	}
})

minetest.register_entity("edit:preview_base", {
	initial_properties = {
		visual = "sprite",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		visual_size  = {x = 1, y = 1},
		textures = {"blank.png"},
	}
})

minetest.register_entity("edit:preview_node", {
	initial_properties = {
		visual = "item",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		visual_size  = {x = 0.69, y = 0.69},
		glow = -1,
	}
})

local function hide_paste_preview(player)
	local d = player_data[player]
	--d.paste_preview:set_properties({is_visible = false})
	-- This does not work right.
	-- Some child entities do not become visable when you set is_visable back to true
			
	for _, objref in pairs(d.paste_preview:get_children()) do
		objref:set_properties({is_visible = false})
	end
	d.paste_preview:set_attach(player)
	player:hud_remove(d.paste_preview_hud)
	d.paste_preview_hud = nil
end

local function show_paste_preview(player)
	local d = player_data[player]
	for _, objref in pairs(d.paste_preview:get_children()) do
		objref:set_properties({is_visible = true})
	end
	d.paste_preview:set_detach()
	d.paste_preview_hud = player:hud_add({
		hud_elem_type = "text",
		text = "Punch (left click) to rotate.",
		position = {x = 0.5, y = 0.8},
		z_index = 100,
		number = 0xffffff
	})
	
	-- Minetset bug: set_pos does not get to the client
	-- sometimes after showing a ton of children
	minetest.after(0.3,
		function(objref)
			local pos = objref:get_pos()
			if pos then objref:set_pos(pos) end
		end,
		d.paste_preview
	)
end

local function hide_select_preview(player)
	local d = player_data[player]
	d.select_preview_shown = false
	d.select_preview:set_properties({is_visible = false})
	d.select_preview:set_attach(player)
end

local function set_select_preview_size(preview, size)
	local preview_size = vector.add(size, vector.new(0.01, 0.01, 0.01))

	local function combine(width, height)
		local tex = ""
		for x = 0, math.floor(width / 8) do
			for y = 0, math.floor(height / 8) do
				if #tex > 0 then tex = tex .. ":" end
				tex = tex ..
					(x * 8 * 16) ..
					"," .. (y * 8 * 16) ..
					"=edit_select_preview.png"
			end
		end
		return "[combine:" .. (width * 16) .. "x" .. (height * 16) .. ":" .. tex
	end

	local x_tex = combine(size.z, size.y)
	local y_tex = combine(size.x, size.z)
	local z_tex = combine(size.x, size.y)

	preview:set_properties({
		visual_size = preview_size,
		textures = {
			y_tex, y_tex,
			x_tex, x_tex,
			z_tex, z_tex
		}
	})
end

minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local item = player:get_wielded_item():get_name()
		local d = player_data[player]
		
		-- Paste preview
		if item == "edit:paste" and d.schematic then
			local pos = pointed_thing_to_pos(get_pointed_thing_node(player))
			if pos then
				if not d.paste_preview or not d.paste_preview:get_pos() then
					create_paste_preview(player)
				end
			
				if not d.paste_preview_hud then show_paste_preview(player) end
				
				local old_pos = player_data[player].paste_preview:get_pos()
				if not vector.equals(old_pos, pos) then
					player_data[player].paste_preview:set_pos(pos)
				end
			elseif d.paste_preview_hud then hide_paste_preview(player) end
		elseif d.paste_preview_hud then hide_paste_preview(player) end
		
		-- Select preview
		local node1_pos
		local node2_pos
		local use_under = false
		if item == "edit:fill" and d.fill1_pos then
			node1_pos = d.fill1_pos
			if d.fill2_pos then node2_pos = d.fill2_pos end
		elseif item == "edit:copy" and d.copy_luaentity1 then
			node1_pos = d.copy_luaentity1._pos
			use_under = true
		end
		
		if node1_pos then
			if not node2_pos then
				local pointed_thing = get_pointed_thing_node(player)
				if use_under then
					node2_pos = pointed_thing.under
				else
					node2_pos = pointed_thing_to_pos(pointed_thing)
				end
			end
			
			if node2_pos then
				local diff = vector.subtract(node1_pos, node2_pos)
				local size = vector.apply(diff, math.abs)
				size = vector.add(size, vector.new(1, 1, 1))
				
				local test = vector.apply(diff, math.abs)
				local has_volume = test.x > 1 and test.y > 1 and test.z > 1
				local size_too_big = size.x * size.y * size.z > max_operation_volume
				if not size_too_big then
					if not d.select_preview or not d.select_preview:get_pos() then
						d.select_preview = minetest.add_entity(node2_pos, "edit:select_preview")
						d.select_preview_shown = true
					elseif not d.select_preview_shown then
						d.select_preview:set_detach()
						d.select_preview:set_properties({is_visible = true})
						d.select_preview_shown = true
					end
					local preview_pos = vector.add(node2_pos, vector.multiply(diff, 0.5))
					local preview = d.select_preview
					if not vector.equals(preview_pos, preview:get_pos()) then
						preview:set_pos(preview_pos)
						set_select_preview_size(preview, size)
					end
				elseif d.select_preview_shown then hide_select_preview(player) end
			elseif d.select_preview_shown then hide_select_preview(player) end
		elseif d.select_preview_shown then hide_select_preview(player) end
	end
end)

minetest.register_on_joinplayer(function(player)
	player_data[player] = {}
end)

minetest.register_on_leaveplayer(function(player)
	delete_paste_preview(player)
	if player_data[player].select_preview then
		player_data[player].select_preview:remove()
	end
	player_data[player] = nil
end)
