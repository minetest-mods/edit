-- param2 rotation table from:
-- https://forum.minetest.net/viewtopic.php?p=73195&sid=1d2d2e4e76ce2ef9c84646481a4b84bc#p73195
-- Axis * 4 + Rotation = Facedir
-- First in pair is axis
-- Second in pair is rotation
local raw_facedir = {
	x = {
		{{3, 0}, {3, 1}, {3, 2}, {3, 3}},
		{{4, 0}, {4, 3}, {4, 2}, {4, 1}},
		{{0, 0}, {1, 0}, {5, 2}, {2, 0}},
		{{0, 1}, {1, 1}, {5, 3}, {2, 1}},
		{{0, 2}, {1, 2}, {5, 0}, {2, 2}},
		{{0, 3}, {1, 3}, {5, 1}, {2, 3}}
	},
	y = {
		{{0, 0}, {0, 1}, {0, 2}, {0, 3}},
		{{5, 0}, {5, 3}, {5, 2}, {5, 1}},
		{{1, 0}, {3, 1}, {2, 2}, {4, 3}},
		{{2, 0}, {4, 1}, {1, 2}, {3, 3}},
		{{3, 0}, {2, 1}, {4, 2}, {1, 3}},
		{{4, 0}, {1, 1}, {3, 2}, {2, 3}}
	},
	z = {
		{{1, 0}, {1, 1}, {1, 2}, {1, 3}},
		{{2, 0}, {2, 3}, {2, 2}, {2, 1}},
		{{0, 0}, {4, 0}, {5, 0}, {3, 0}},
		{{0, 1}, {4, 1}, {5, 1}, {3, 1}},
		{{0, 2}, {4, 2}, {5, 2}, {3, 2}},
		{{0, 3}, {4, 3}, {5, 3}, {3, 3}}
	}
}

local facedir_rot = {}

local function pair_to_param2(pair)
	return pair[1] * 4 + pair[2]
end

for axis, raw_rot in pairs(raw_facedir) do
	facedir_rot[axis] = {}
	for j, pair_list in pairs(raw_rot) do
		for i = 1, 4 do
			local back_index = i - 1
			if back_index == 0 then
				back_index = 4
			end
			local next_index = i + 1
			if next_index == 5 then
				next_index = 1
			end
			local back = pair_to_param2(pair_list[back_index])
			local next = pair_to_param2(pair_list[next_index])
			local current = pair_to_param2(pair_list[i])
			facedir_rot[axis][current] = {next, back}
		end
	end
end

local raw_wallmounted = {
	x = {4, 0, 5, 1},
	y = {2, 4, 3, 5},
	z = {3, 0, 2, 1},
}

local wallmounted_rot = {}

for axis, rots in pairs(raw_wallmounted) do
	wallmounted_rot[axis] = {}
	local param2s_unused = {
		[0] = true, [1] = true, [2] = true,
		[3] = true, [4] = true, [5] = true}
	for i = 1, 4 do
		local back_index = i - 1
		if back_index == 0 then
			back_index = 4
		end
		local next_index = i + 1
		if next_index == 5 then
			next_index = 1
		end
		local current = rots[i]
		local back = rots[back_index]
		local next = rots[next_index]
		wallmounted_rot[axis][current] = {back, next}
		param2s_unused[current] = nil
	end

	for param2, bool in pairs(param2s_unused) do
		wallmounted_rot[axis][param2] = {param2, param2}
	end
end

function edit.rotate_param2(node, rot_vect)
	local def = minetest.registered_items[node.name]
	if not node.param2 or not def then return end
	local paramtype2 = def.paramtype2
	local is_wallmounted = paramtype2 == "wallmounted" or paramtype2 == "colorwallmounted"
	local is_facedir = paramtype2 == "facedir" or paramtype2 == "colorfacedir"
	local rot_table = is_facedir and facedir_rot or wallmounted_rot
	if is_facedir or is_wallmounted then
		local param2_rot = node.param2 % 32 -- Get first 5 bits
		if is_wallmounted then
			param2_rot = node.param2 % 8 -- Get first 3 bits
		end
		local param2_other = node.param2 - param2_rot
		for axis, target_rot in pairs(rot_vect) do
			if target_rot ~= 0 then
				local direction = math.sign(target_rot)
				for rot = direction, target_rot / (math.pi / 2), direction do
					if target_rot > 0 then
						param2_rot = rot_table[axis][param2_rot][1]
					else
						param2_rot = rot_table[axis][param2_rot][2]
					end
				end
			end
		end
		node.param2 = param2_other + param2_rot
	elseif paramtype2 == "degrotate" or paramtype2 == "colordegrotate" then
		local param2_rot
		local deg_per_unit
		if paramtype2 == "degrotate" then
			param2_rot = node.param2
			deg_per_unit = 1.5
		else
			param2_rot = node.param2 % 32 -- Get first 5 bits
			deg_per_unit = 15
		end
		local param2_other = node.param2 - param2_rot
		local rot = param2_rot * deg_per_unit / 180 * math.pi
	
		rot = rot + rot_vect.y
		rot = rot % (math.pi * 2)
		if rot < 0 then
			rot = rot + math.pi * 2
		end

		param2_rot = math.round(rot / math.pi * 180 / deg_per_unit)
		node.param2 = param2_other + param2_rot
	end
end

local function screwdriver_run(player, pointed_thing, rotate_y)
	if not edit.on_place_checks(player) then return end
	if pointed_thing.type ~= "node" then return end
	local pos = pointed_thing.under
	local node = minetest.get_node(pos)
	local def = minetest.registered_items[node.name]
	if not def then return end
	local rot = vector.new(0, 0, 0)
	local paramtype2 = def.paramtype2
	if paramtype2 == "degrotate" or paramtype2 == "colordegrotate" then
		if rotate_y then
			local deg = paramtype2 == "degrotate" and 1.5 or 15
			rot.y = deg / 180 * math.pi
			if player:get_player_control().aux1 then
				rot.y = rot.y * 4
			end
		end
	else
		if rotate_y then
			rot = vector.new(0, math.pi / 2, 0)
		else
			local player_pos = player:get_pos()
			local diff = vector.subtract(player_pos, pos)
			local abs_diff = vector.apply(diff, math.abs)
			if abs_diff.x > abs_diff.z then
				local sign = (diff.x > 0) and 1 or -1
				rot = vector.new(0, 0, math.pi / 2 * sign)
			else
				local sign = (diff.z < 0) and 1 or -1
				rot = vector.new(math.pi / 2 * sign, 0, 0)
			end
		end
	end
	local old_node = table.copy(node)
	edit.rotate_param2(node, rot)
	if def.on_rotate then
		def.on_rotate(pos, old_node, player, 1, node.param2)
	end
	minetest.swap_node(pos, node)
end

minetest.register_tool("edit:screwdriver", {
	description = "Edit Screwdriver",
	inventory_image = "edit_screwdriver.png",
	on_use = function(itemstack, user, pointed_thing)
		screwdriver_run(user, pointed_thing, true)
		return itemstack
	end,
	on_place = function(itemstack, user, pointed_thing)
		screwdriver_run(user, pointed_thing, false)
		return itemstack
	end,
})
