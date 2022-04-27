--[[
	Edit Mod v0.3
]]

--Add priv
minetest.register_privilege("edit", {
	description = "Lets you use edit, copy, paste, delete blocks",
	give_to_singleplayer= true,
	give_to_admin = true,
})

--end add priv 

-- add in priv check
local function check_privilege(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name, {edit = true}) then
		return true
	else
		minetest.chat_send_player(name, "You can't use an edit block without the edit privilege.")
		return false
	end
end
--end priv check

local function sign(x) -- different from math.sign never returns 0.
	if x > 0 then
		return 1
	elseif x < -0 then
		return -1
	end
	return 1
end

-- Delete Block
minetest.register_node("edit:delete", {
	description = "Delete",
	inventory_image = "edit_delete.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	tiles = {"edit_delete.png"},
	on_place = function(itemstack, placer, pointed_thing)
		if not placer then return itemstack end
		
		if not check_privilege(placer) then return itemstack end
		
		if clipboard[placer:get_player_name()].delete_block1_pos then
			local p1 = clipboard[placer:get_player_name()].delete_block1_pos
			local p2 = pointed_thing.above
			
			minetest.remove_node(p1)
			
			p1.x = p1.x + math.sign(p2.x - p1.x)
			p1.y = p1.y + math.sign(p2.y - p1.y)
			p1.z = p1.z + math.sign(p2.z - p1.z)
			p2.x = p2.x + math.sign(p1.x - p2.x)
			p2.y = p2.y + math.sign(p1.y - p2.y)
			p2.z = p2.z + math.sign(p1.z - p2.z)
			
			for x = p1.x, p2.x, sign(p2.x - p1.x) do
				for y = p1.y, p2.y, sign(p2.y - p1.y) do
					for z = p1.z, p2.z, sign(p2.z - p1.z) do
						minetest.remove_node(vector.new(x, y, z));
					end
				end
			end
			clipboard[placer:get_player_name()].delete_block1_pos = nil
		else
			minetest.set_node(pointed_thing.above, {name = "edit:delete"})
			clipboard[placer:get_player_name()].delete_block1_pos = pointed_thing.above
		end
	end,
	on_dig = function(pos, node, digger)
		for name, value in pairs(clipboard) do
			minetest.remove_node(pos);
			if
				clipboard[name].delete_block1_pos
				and clipboard[name].delete_block1_pos.x == pos.x
				and clipboard[name].delete_block1_pos.y == pos.y
				and clipboard[name].delete_block1_pos.z == pos.z
			then
				clipboard[name].delete_block1_pos = nil
				break
			end
		end
	end
})

-- Copy Block
minetest.register_node("edit:copy",{
	description = "Copy",
	tiles = {"edit_copy.png"},
	inventory_image = "edit_copy.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	on_place = function(itemstack, placer, pointed_thing)
		if not placer then return itemstack end
		
		if not check_privilege(placer) then return itemstack end
		
		local name = placer:get_player_name()
		if clipboard[name].copy_block1_pos then
			clipboard[name].copy_data = {} -- clear out old copy data
			local copy_data = clipboard[name].copy_data
			local p1 = clipboard[name].copy_block1_pos
			local p2 = pointed_thing.above
			
			minetest.remove_node(p1); -- remove copy block 1.
			-- We don't have to remove copy block 2 because we never placed!
			
			local offsetX = math.sign(p2.x - p1.x)
			local offsetY = math.sign(p2.y - p1.y)
			local offsetZ = math.sign(p2.z - p1.z)
			
			p1.x = p1.x + math.sign(p2.x - p1.x)
			p1.y = p1.y + math.sign(p2.y - p1.y)
			p1.z = p1.z + math.sign(p2.z - p1.z)

			p2.x = p2.x + math.sign(p1.x - p2.x)
			p2.y = p2.y + math.sign(p1.y - p2.y)
			p2.z = p2.z + math.sign(p1.z - p2.z)
			
			for x = p1.x, p2.x, sign(p2.x - p1.x) do
				local xDif = offsetX + x - p1.x
				copy_data[xDif] = {}
				for y = p1.y, p2.y, sign(p2.y - p1.y) do
					local yDif = offsetY + y - p1.y
					copy_data[xDif][yDif] = {}
					for z = p1.z, p2.z, sign(p2.z - p1.z) do
						local zDif = offsetZ + z - p1.z
						copy_data[xDif][yDif][zDif] = minetest.get_node(
							vector.new(x, y, z)
						)
					end
				end
			end
			clipboard[placer:get_player_name()].copy_block1_pos = nil
		else
			minetest.set_node(pointed_thing.above, {name = "edit:copy"})
			clipboard[placer:get_player_name()].copy_block1_pos = pointed_thing.above
		end
	end,
	on_dig = function(pos, node, digger)
		for name, value in pairs(clipboard) do
			minetest.remove_node(pos);
			if
				clipboard[name].copy_block1_pos
				and clipboard[name].copy_block1_pos.x == pos.x
				and clipboard[name].copy_block1_pos.y == pos.y
				and clipboard[name].copy_block1_pos.z == pos.z
			then
				clipboard[name].copy_block1_pos = nil
				break
			end
		end
	end
})

-- Paste Block
minetest.register_node("edit:paste", {
	description = "Paste",
	tiles = {"edit_paste.png"},
	inventory_image = "edit_paste.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	on_place = function(itemstack, placer, pointed_thing)
		if not placer then return itemstack end
		
		if not check_privilege(placer) then return itemstack end
		
		local copy_data = clipboard[placer:get_player_name()].copy_data
		local pos = pointed_thing.above
		for x, yTable in pairs(copy_data) do
			for y, zTable in pairs(yTable) do
				for z, node in pairs(zTable) do
					minetest.set_node(vector.new(
						pos.x + x,
						pos.y + y,
						pos.z + z
					), node)
				end
			end
		end
	end
})

-- Fill Block
minetest.register_node("edit:fill",{
	description = "Fill",
	tiles = {"edit_fill.png"},
	inventory_image = "edit_fill.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	on_place = function(itemstack, placer, pointed_thing)
		if not placer then return itemstack end
		
		if not check_privilege(placer) then return itemstack end
		
		if clipboard[placer:get_player_name()].fill_block1 then
			minetest.set_node(pointed_thing.above, {name = "edit:fill"})
			clipboard[placer:get_player_name()].fill_block2 = pointed_thing
				
			local inv = minetest.get_inventory({type = "player", name = placer:get_player_name()})
			local formSpec = "size[8,6]label[0.5,0.5;Select the material you would like to use]button_exit[7,0;1,1;quit;X]"
			for y = 1, 4 do
				for x = 1, 8 do
					local name = inv:get_stack("main", ((y - 1) * 8) + x):get_name()
					formSpec =
						formSpec
						.. "item_image_button["
						.. (x - 1) .. ","
						.. (y + 1) .. ";1,1;"
						.. name .. ";"
						.. name .. ";]"
				end
			end
			minetest.show_formspec(placer:get_player_name(), "edit:select_fill_type", formSpec)
		else
			minetest.set_node(pointed_thing.above, {name = "edit:fill"})
			clipboard[placer:get_player_name()].fill_block1 = pointed_thing
		end
	end,
	on_dig = function(pos, node, digger)
		minetest.remove_node(pos);
		for name, fills in pairs(clipboard) do
			local block1 = fills.fill_block1
			local block2 = fills.fill_block2
			if block1 and vector.equals(block1.above, pos) then
				fills.fill_block1 = nil
				fills.fill_block2 = nil
				minetest.remove_node(block1.above)
				return
			end
			if block2 and vector.equals(block2.above, pos) then
				fills.fill_block1 = nil
				fills.fill_block2 = nil
				minetest.remove_node(block2.above)
				return
			end
		end
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not player then return false end
	if formname ~= "edit:select_fill_type" then return false end
	
	minetest.close_formspec(player:get_player_name(), "edit:select_fill_type")
	
	if
		not clipboard[player:get_player_name()].fill_block1
		or not clipboard[player:get_player_name()].fill_block2
	then return true end
	
	local p1 = clipboard[player:get_player_name()].fill_block1.above
	local p2 = clipboard[player:get_player_name()].fill_block2.above
	local pointed_thing = clipboard[player:get_player_name()].fill_block1
	clipboard[player:get_player_name()].fill_block1 = nil
	clipboard[player:get_player_name()].fill_block2 = nil
	minetest.remove_node(p1)
	minetest.remove_node(p2)
	
	local item = next(fields)
	if item == "quit" then return true end
	if item == "" then item = "air" end

	local def = minetest.registered_nodes[item]
		or minetest.registered_craftitems[item]
		or minetest.registered_tools[item]
		or minetest.registered_items[item]
				
	if not def then return true end
		
	local is_node = minetest.registered_nodes[item]
		
	local param2
	if def.paramtype2 == "facedir" then
		param2 = minetest.dir_to_facedir(player:get_look_dir())
	elseif def.paramtype2 == "wallmounted" then
		param2 = minetest.dir_to_wallmounted(player:get_look_dir(), true)
	end
	
	for x = p1.x, p2.x, sign(p2.x - p1.x) do
		for y = p1.y, p2.y, sign(p2.y - p1.y) do
			for z = p1.z, p2.z, sign(p2.z - p1.z) do
				if is_node then
					minetest.set_node(vector.new(x, y, z), {name = item, param2 = param2})
				else
					minetest.remove_node(vector.new(x, y, z))
				end
				if def.on_place then
					local itemstack = ItemStack(item)
					pointed_thing.intersection_point = vector.new(x + 0.5, y, z + 0.5)
					pointed_thing.above = vector.new(x, y, z)
					pointed_thing.below = vector.new(x, y - 1, z)
					def.on_place(itemstack, player, pointed_thing)
				end
			end
		end
	end
	return true
end)

clipboard = {};
minetest.register_on_joinplayer(function(player)
	if player then
		clipboard[player:get_player_name()] = {
			fill_block1 = nil,
			fill_block2 = nil,
			copy_block1_pos = nil,
			delete_block1_pos = nil,
			copy_data = {},
		};
	end
end);
minetest.register_on_leaveplayer(function(player)
	if player then
		clipboard[player:get_player_name()] = nil
	end
end);
