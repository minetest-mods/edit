local function get_item_list(itemstack)
	local meta = itemstack:get_meta()
	local str = meta:get("edit_bag")
	local item_list = {}
	if str then item_list = minetest.deserialize(str) end
	for i, str in pairs(item_list) do
		item_list[i] = ItemStack(str)
	end
	return item_list
end

local function put_item_list(itemstack, item_list)
	local meta = itemstack:get_meta()
	local str_list = {}
	local description = ""
	local description_len = 0
	for i, item in pairs(item_list) do
		str_list[i] = item:to_string()
		if str_list[i] ~= "" then
			if description_len < 3 then
				description = description ..
					"\n" .. item:get_count() ..
					" " .. item:get_short_description()
				description_len = description_len + 1
			elseif description_len == 3 then
				description = description .. "\n..."
				description_len = description_len + 1
			end
		end
	end
	description = minetest.registered_items["edit:bag"].short_description ..
		minetest.colorize("yellow", description)
	local str = minetest.serialize(str_list)
	meta:set_string("edit_bag", str)
	meta:set_string("description", description)
end

local function on_inv_change(player)
	local bag = player:get_wielded_item()
	if bag:get_name() ~= "edit:bag" then return end
	if not bag then return end
	local name = player:get_player_name()
	local inv_ref = minetest.get_inventory({type = "detached", name = "edit_bag_" .. name})
	put_item_list(bag, inv_ref:get_list("main"))
	player:set_wielded_item(bag)
end

minetest.register_on_joinplayer(function(player)
	local inv_ref = minetest.create_detached_inventory("edit_bag_" .. player:get_player_name(), {
		on_move = function(inv, from_list, from_index, to_list, to_index, count, player) on_inv_change(player) end,
		on_put = function(inv, listname, index, stack, player) on_inv_change(player) end,
		on_take = function(inv, listname, index, stack, player) on_inv_change(player) end,
	})
	inv_ref:set_size("main", 16)
end)

minetest.register_on_leaveplayer(function(player)
	minetest.remove_detached_inventory("edit_bag_" .. player:get_player_name())
end)

local function on_place(itemstack, player, pointed_thing)
	if pointed_thing.type ~= "node" then return end
	local item_list = get_item_list(itemstack)
	local total_count = 0
	for i, item_stack in ipairs(item_list) do
		total_count = total_count + item_stack:get_count()
	end
	local selected_index = math.round((total_count - 1) * math.random()) + 1
	local selected_item

	local current_index = 0
	for i, item_stack in ipairs(item_list) do
		local count = item_stack:get_count()
		if count > 0 then
			current_index = current_index + count
			if current_index >= selected_index then
				selected_item = item_stack
				break
			end
		end
	end

	if selected_item then
		local pos = edit.pointed_thing_to_pos(pointed_thing)
		edit.place_item_like_player(player, {name = selected_item}, pos)
	end
end

local function on_use(itemstack, user, pointed_thing)
	local meta = itemstack:get_meta()
	local str = meta:get("edit_bag")
	local name = user:get_player_name()
	local item_list = {}
	if str then item_list = minetest.deserialize(str) end
	for i, str in pairs(item_list) do
		item_list[i] = ItemStack(str)
	end
	local inv_ref = minetest.get_inventory({type = "detached", name = "edit_bag_" .. name})
	inv_ref:set_list("main", item_list)
	local formspec = "formspec_version[4]size[10.2,10]" ..
		"label[0.2,0.9;Bag contents:]" ..
		"button_exit[9,0.2;1,1;quit;X]" ..
		"list[detached:edit_bag_" .. name .. ";main;0.2,1.4;8,2;]" ..
		"label[0.2,4.5;Inventory:]" ..
		"list[current_player;main;0.2,5;8,4;]"
	minetest.show_formspec(name, "edit:bag", formspec)
end

minetest.register_tool("edit:bag", {
	description = "Edit Bag",
	short_description = "Edit Bag",
	tiles = {"edit_bag.png"},
	inventory_image = "edit_bag.png",
	range = 10,
	on_place = on_place,
	on_secondary_use = on_place,
	on_use = on_use,
})
