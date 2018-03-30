--[[
	Edit Mod v0.1
]]
local function sign(x) -- different from math.sign never returns 0.
	if x > 0 then
		return 1
	elseif x < -0 then
		return -1
	end
	return 1
end

-- Delete Block
minetest.register_node("edit:delete",{
	description = "Delete",
	inventory_image = "edit_delete.png",
	groups = {snappy = 2, oddly_breakable_by_hand = 3},
	tiles = {"edit_delete.png"},
	on_place = function(itemstack, placer, pointed_thing)
		if clipboard[placer:get_player_name()].deleteBlock1Pos then
			local p1 = clipboard[placer:get_player_name()].deleteBlock1Pos
			local p2 = pointed_thing.above
			
			minetest.remove_node(p1);
			
			p1.x = p1.x + math.sign(p2.x - p1.x)
			p1.y = p1.y + math.sign(p2.y - p1.y)
			p1.z = p1.z + math.sign(p2.z - p1.z)
			p2.x = p2.x + math.sign(p1.x - p2.x)
			p2.y = p2.y + math.sign(p1.y - p2.y)
			p2.z = p2.z + math.sign(p1.z - p2.z)
			
			for x = p1.x, p2.x, sign(p2.x - p1.x) do
				for y = p1.y, p2.y, sign(p2.y - p1.y) do
					for z = p1.z, p2.z, sign(p2.z - p1.z) do
						minetest.remove_node({x=x, y=y, z=z});
					end
				end
			end
			clipboard[placer:get_player_name()].deleteBlock1Pos = nil
		else
			minetest.set_node(pointed_thing.above, {name = "edit:delete"})
			clipboard[placer:get_player_name()].deleteBlock1Pos = pointed_thing.above
		end
	end,
	on_dig = function(pos, node, digger)
		for name, value in pairs(clipboard) do
			minetest.remove_node(pos);
			if
				clipboard[name].deleteBlock1Pos
				and clipboard[name].deleteBlock1Pos.x == pos.x
				and clipboard[name].deleteBlock1Pos.y == pos.y
				and clipboard[name].deleteBlock1Pos.z == pos.z
			then
				clipboard[name].deleteBlock1Pos = nil
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
		if clipboard[placer:get_player_name()].copyBlock1Pos then
			clipboard[placer:get_player_name()].copyData = {} -- clear out old copy data
			local copyData = clipboard[placer:get_player_name()].copyData
			local p1 = clipboard[placer:get_player_name()].copyBlock1Pos
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
				copyData[xDif] = {}
				for y = p1.y, p2.y, sign(p2.y - p1.y) do
					local yDif = offsetY + y - p1.y
					copyData[xDif][yDif] = {}
					for z = p1.z, p2.z, sign(p2.z - p1.z) do
						local zDif = offsetZ + z - p1.z
						copyData[xDif][yDif][zDif] = minetest.get_node(
							{x = x, y = y, z = z}
						)
					end
				end
			end
			clipboard[placer:get_player_name()].copyBlock1Pos = nil
		else
			minetest.set_node(pointed_thing.above, {name = "edit:copy"})
			clipboard[placer:get_player_name()].copyBlock1Pos = pointed_thing.above
		end
	end,
	on_dig = function(pos, node, digger)
		for name, value in pairs(clipboard) do
			minetest.remove_node(pos);
			if
				clipboard[name].copyBlock1Pos
				and clipboard[name].copyBlock1Pos.x == pos.x
				and clipboard[name].copyBlock1Pos.y == pos.y
				and clipboard[name].copyBlock1Pos.z == pos.z
			then
				clipboard[name].copyBlock1Pos = nil
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
		local copyData = clipboard[placer:get_player_name()].copyData
		local pos = pointed_thing.above
		for x, yTable in pairs(copyData) do
			for y, zTable in pairs(yTable) do
				for z, node in pairs(zTable) do
					minetest.set_node(
						{
							x = pos.x + x,
							y = pos.y + y,
							z = pos.z + z
						},
						node
					)
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
		if clipboard[placer:get_player_name()].fillBlock1Pos then
			minetest.set_node(pointed_thing.above, {name = "edit:fill"})
			clipboard[placer:get_player_name()].fillBlock2Pos = pointed_thing.above
				
			local inv = minetest.get_inventory({type = "player", name = placer:get_player_name()})
			local formSpec = "size[8,6]label[0.5,0.5;Select the material you would like to use]button_exit[7,0;1,1;quit;X]"
			for y = 1, 4 do
				for x = 1, 8 do
					local name = inv:get_stack("main", ((y - 1) * 8) + x):get_name()
					formSpec
					=
					formSpec
					.. "item_image_button["
					.. (x - 1) .. ","
					.. (y + 1) .. ";1,1;"
					.. name .. ";"
					.. name .. ";]"
				end
			end
			minetest.show_formspec(placer:get_player_name(), "edit:pasteType", formSpec)
		else
			minetest.set_node(pointed_thing.above, {name = "edit:fill"})
			clipboard[placer:get_player_name()].fillBlock1Pos = pointed_thing.above
		end
	end,
	on_dig = function(pos, node, digger)
		minetest.remove_node(pos);
		for name, value in pairs(clipboard) do
			if
				clipboard[name].fillBlock1Pos
				and clipboard[name].fillBlock1Pos.x == pos.x
				and clipboard[name].fillBlock1Pos.y == pos.y
				and clipboard[name].fillBlock1Pos.z == pos.z
			then
				clipboard[name].fillBlock1Pos = nil
				break
			elseif
				clipboard[name].fillBlock2Pos
				and clipboard[name].fillBlock2Pos.x == pos.x
				and clipboard[name].fillBlock2Pos.y == pos.y
				and clipboard[name].fillBlock2Pos.z == pos.z
			then
				clipboard[digger:get_player_name()].fillBlock2Pos = nil
				break
			end
		end
	end
})
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "edit:pasteType" then
		for key, value in pairs(fields) do
			if
				clipboard[player:get_player_name()].fillBlock1Pos
				and clipboard[player:get_player_name()].fillBlock2Pos
			then
				local p1 = clipboard[player:get_player_name()].fillBlock1Pos
				local p2 = clipboard[player:get_player_name()].fillBlock2Pos
				if key == "quit" then
					minetest.remove_node(p1)
					minetest.remove_node(p2)
					clipboard[player:get_player_name()].fillBlock1Pos = nil
					clipboard[player:get_player_name()].fillBlock2Pos = nil
				else
					if key == "" then key = "air" end
					local def = minetest.registered_nodes[key]
					if not def then return end
					local param2
					if def.paramtype2 == "facedir" then
						param2 = minetest.dir_to_facedir(player:get_look_dir())
					elseif def.paramtype2 == "wallmounted" then
						param2 = minetest.dir_to_wallmounted(player:get_look_dir(), true)
					end
					--minetest.chat_send_all("" .. param2)
					for x = p1.x, p2.x, sign(p2.x - p1.x) do
						for y = p1.y, p2.y, sign(p2.y - p1.y) do
							for z = p1.z, p2.z, sign(p2.z - p1.z) do
								minetest.set_node({x = x, y = y, z = z}, {name = key, param2 = param2})
							end
						end
					end
					minetest.close_formspec(player:get_player_name(), "edit:pasteType")
					clipboard[player:get_player_name()].fillBlock1Pos = nil
					clipboard[player:get_player_name()].fillBlock2Pos = nil
				end
			end
		end
		return true
	end
    return false
end)

clipboard = {};
minetest.register_on_joinplayer(function(player)
	clipboard[player:get_player_name()] = {
		["fillBlock1Pos"] = nil,
		["fillBlock2Pos"] = nil,
		["copyBlock1Pos"] = nil,
		["deleteBlock1Pos"] = nil,
		["copyData"] = {},
	};
end);
minetest.register_on_leaveplayer(function(player)
	clipboard[player:get_player_name()] = nil
end);