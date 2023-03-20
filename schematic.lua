function edit.schematic_from_map(pos, size)
	local schematic = {data = {}}
	schematic.size = size
	schematic._pos = pos
	schematic._meta = {}

	local start = vector.new(1, 1, 1)
	local voxel_area = VoxelArea:new({MinEdge = start, MaxEdge = size})

	for i in voxel_area:iterp(start, size) do
		local offset = voxel_area:position(i)
		local node_pos = vector.subtract(vector.add(pos, offset), start)
		local node = minetest.get_node(node_pos)
		node.param1 = nil
		schematic.data[i] = node

		local meta = minetest.get_meta(node_pos):to_table()

		local has_meta = false
		-- Convert metadata item stacks to item strings
		for name, inventory in pairs(meta.inventory) do
			for i, stack in ipairs(inventory) do
				has_meta = true
				if stack.to_string then
					inventory[i] = stack:to_string()
				end
			end
		end

		if meta.fields and next(meta.fields) ~= nil then
			has_meta = true
		end

		if not has_meta then
			for k in pairs(meta) do
				if k ~= "inventory" and k ~= "fields" then
					has_meta = true
					break
				end
			end
		end

		if has_meta then
			local key = minetest.hash_node_position(offset)
			schematic._meta[key] = meta
		end
	end

	return schematic
end

function edit.set_schematic_rotation(schematic, angle)
	if not schematic._rotation then schematic._rotation = 0 end
	schematic._rotation = schematic._rotation + angle
	if schematic._rotation < 0 then
		schematic._rotation = schematic._rotation + 360
	elseif schematic._rotation > 270 then
		schematic._rotation = schematic._rotation - 360
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

function edit.schematic_to_map(pos, schematic)
	minetest.place_schematic(pos, schematic, tostring(schematic._rotation), nil, true)
	local size = schematic.size
	for hash, metadata in pairs(schematic._meta) do
		local offset = minetest.get_position_from_hash(hash)
		offset = vector.subtract(offset, 1)
		if schematic._rotation == 90 then
			offset = vector.new(offset.z, offset.y, size.x - offset.x - 1)
		elseif schematic._rotation == 180 then
			offset = vector.new(size.x - offset.x - 1, offset.y, size.z - offset.z - 1)
		elseif schematic._rotation == 270 then
			offset = vector.new(size.z - offset.z - 1, offset.y, offset.x)
		end
		local node_pos = vector.add(pos, offset)
		local meta = minetest.get_meta(node_pos)
		meta:from_table(metadata)
	end
end
