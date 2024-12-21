local param2_to_rotation = dofile(edit.modpath .. "/object_rotations.lua").facedir

minetest.register_entity("edit:place_preview", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 1.1, y = 1.1 },
		physical = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		backface_culling = false,
		pointable = false,
	}
})

function edit.rotate_paste_preview(player)
	local d = edit.player_data[player]
	local rot = d.schematic._rotation
	local offset
	d.paste_preview.object:set_yaw(-math.rad(rot))
	local size = d.schematic.size
	if rot == 90 or rot == 270 then
		size = vector.new(size.z, size.y, size.x)
	end
	if rot == 0 then
		offset = vector.new(-1, -1, -1)
	elseif rot == 90 then
		offset = vector.new(-1, -1, size.z)
	elseif rot == 180 then
		offset = vector.new(size.x, -1, size.z)
	elseif rot == 270 then
		offset = vector.new(size.x, -1, -1)
	end
	d.paste_preview_offset = offset
end

local function create_paste_preview(player)
	local player_pos = player:get_pos()
	local base_objref = minetest.add_entity(player_pos, "edit:paste_preview_base")
	local schematic = edit.player_data[player].schematic
	local vector_1 = vector.new(1, 1, 1)
	local size = schematic.size
	local voxel_area = VoxelArea:new({MinEdge = vector_1, MaxEdge = size})
	local schem_data = schematic.data
	local count = size.x * size.y * size.z
	local node_black_list = {}

	-- Remove air from the schematic preview
	for i, map_node in pairs(schem_data) do
		if map_node.name == "air" then
			count = count - 1
			node_black_list[i] = true
		end
	end

	-- Hollow out sold areas in the schematic preview
	local strides = {
		1, -1,
		voxel_area.ystride, -voxel_area.ystride,
		voxel_area.zstride, -voxel_area.zstride,
	}
	if math.min(size.x, size.y, size.z) > 2 then
		local start = vector.new(2, 2, 2)
		local _end = vector.subtract(size, 1)
		for i in voxel_area:iterp(start, _end) do
			if not node_black_list[i] then
				local include_node = false
				for _, n in pairs(strides) do
					if schem_data[i + n].name == "air" then
						include_node = true
						break
					end
				end

				if not include_node then
					count = count - 1
					node_black_list[i] = true
				end
			end
		end
	end

	local probability = edit.paste_preview_max_entities / count
	for i in voxel_area:iterp(vector_1, size) do
		local pos = voxel_area:position(i)
		local name = schematic.data[i].name
		if not node_black_list[i] and math.random() < probability then
			local attach_pos = vector.multiply(pos, 10)
			local attach_rot
			local objref = minetest.add_entity(player_pos, "edit:preview_node")
			objref:set_properties({wield_item = name})
			local node_def = minetest.registered_nodes[name]
			if node_def and node_def.paramtype2 == "facedir" then
				local param2 = schematic.data[i].param2
				attach_rot = param2_to_rotation[param2]
			end
			objref:set_attach(base_objref, "", attach_pos, attach_rot)
		end
	end
	edit.player_data[player].paste_preview = base_objref:get_luaentity()
	edit.player_data[player].schematic._rotation = 0
	edit.rotate_paste_preview(player)
end

minetest.register_entity("edit:polygon_preview", {
	initial_properties = {
		visual = "cube",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		use_texture_alpha = true,
		glow = -1,
		backface_culling = false,
		visual_size = { x = 1.05, y = 1.05 },
		textures = {
			"edit_select_preview.png^[sheet:8x8:1,1",
			"edit_select_preview.png^[sheet:8x8:1,1",
			"edit_select_preview.png^[sheet:8x8:1,1",
			"edit_select_preview.png^[sheet:8x8:1,1",
			"edit_select_preview.png^[sheet:8x8:1,1",
			"edit_select_preview.png^[sheet:8x8:1,1",
		},
	}
})

local function hide_polygon_preview(player)
	local player_data = edit.player_data[player]
	local previews = player_data.polygon_previews
	for i, obj_ref in ipairs(previews) do
		obj_ref:set_properties({is_visible = false})
	end

	if player_data.polygon_preview_hud then
		player:hud_remove(player_data.polygon_preview_hud)
		player_data.polygon_preview_hud = nil
	end

	player_data.polygon_preview_shown = false
end

local function show_polygon_preview(player, show_polygon_hud)
	local player_data = edit.player_data[player]

	if not player_data.polygon_previews then
		player_data.polygon_previews = {}
		player_data.polygon_previews.object = player_data.polygon_previews
		player_data.polygon_previews.object.remove = function(self)
			for i, luaentity in ipairs(table.copy(self)) do
				luaentity:remove()
			end
		end
	end

	for i, obj_ref in ipairs(player_data.polygon_previews) do
		obj_ref:set_properties({is_visible = true})
	end

	player_data.polygon_preview_shown = true
end

local function update_polygon_preview(player, marker_pos_list, show_polygon_hud)
	local player_pos = player:get_pos()
	local player_data = edit.player_data[player]

	local show_full_preview = true
	local bounding_box_min = table.copy(marker_pos_list[1])
	local bounding_box_max = table.copy(marker_pos_list[1])
	for index, axis in pairs({"x", "y", "z"}) do
		for i, pos in ipairs(marker_pos_list) do
			bounding_box_min[axis] = math.min(bounding_box_min[axis], pos[axis])
			bounding_box_max[axis] = math.max(bounding_box_max[axis], pos[axis])
		end
		if
			bounding_box_max[axis] - bounding_box_min[axis] + 1 >
			edit.polygon_preview_wire_frame_threshold
		then
			show_full_preview = false
		end
	end

	local pos_list = {}

	local volume = vector.add(vector.subtract(bounding_box_max, bounding_box_min), vector.new(1, 1, 1))
	if volume.x * volume.y * volume.z <= edit.max_operation_volume then
		if #marker_pos_list == 2 or not show_full_preview then
			table.insert_all(
				pos_list,
				edit.calculate_line_points(marker_pos_list[1], marker_pos_list[2])
			)
		end

		for i = 3, #marker_pos_list do
			if show_full_preview then
				table.insert_all(
					pos_list,
					edit.calculate_triangle_points(
						marker_pos_list[i],
						marker_pos_list[i - 1],
						marker_pos_list[1]
					)
				)
			else
				table.insert_all(
					pos_list,
					edit.calculate_line_points(marker_pos_list[i], marker_pos_list[i - 1])
				)
				table.insert_all(
					pos_list,
					edit.calculate_line_points(marker_pos_list[i], marker_pos_list[1])
				)
			end
		end
	end

	local preview_objs = player_data.polygon_previews
	if #preview_objs > #pos_list then
		for i = #pos_list + 1, #preview_objs do
			preview_objs[#pos_list + 1]:remove()
			table.remove(preview_objs, #pos_list + 1)
		end
	elseif #preview_objs < #pos_list then
		for i = #preview_objs + 1, #pos_list do
			local obj_ref = minetest.add_entity(player_pos, "edit:polygon_preview")
			table.insert(preview_objs, obj_ref)
		end
	end

	for i, pos in pairs(pos_list) do
		preview_objs[i]:set_pos(pos)
	end
end

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

minetest.register_entity("edit:paste_preview_base", {
	initial_properties = {
		visual = "cube",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		visual_size  = {x = 1, y = 1},
		textures = { "blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png" },
	},
	on_deactivate = function(self)
		local objrefs = self.object:get_children()
		for i, objref in pairs(objrefs) do
			objref:remove()
		end
	end
})

minetest.register_entity("edit:preview_node", {
	initial_properties = {
		visual = "item",
		physical = false,
		pointable = false,
		collide_with_objects = false,
		static_save = false,
		visual_size  = { x = 0.68, y = 0.68 },
		glow = -1,
	}
})

local function hide_paste_preview(player)
	local d = edit.player_data[player]

	player:hud_remove(d.paste_preview_hud)
	d.paste_preview_hud = nil

	if not d.paste_preview.object:get_pos() then
		edit.delete_paste_preview(player)
		return
	end

	--d.paste_preview:set_properties({is_visible = false})
	-- This does not work right.
	-- Some child entities do not become visable when you set is_visable back to true

	for _, objref in pairs(d.paste_preview.object:get_children()) do
		objref:set_properties({is_visible = false})
	end
	d.paste_preview.object:set_attach(player)
end

local function show_paste_preview(player)
	local d = edit.player_data[player]
	for _, objref in pairs(d.paste_preview.object:get_children()) do
		objref:set_properties({is_visible = true})
	end
	d.paste_preview.object:set_detach()
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
		d.paste_preview.object
	)
end

function edit.delete_paste_preview(player)
	local d = edit.player_data[player]
	if d.paste_preview then
		d.paste_preview.object:remove()
		d.paste_preview = nil
	end
end

local function hide_select_preview(player)
	local d = edit.player_data[player]
	d.select_preview_shown = false
	d.select_preview.object:set_properties({ is_visible = false })
	d.select_preview.object:set_attach(player)
	player:hud_remove(d.select_preview_hud)
	d.select_preview_hud = nil
end

local function update_select_preview(player, pos, size)
	local d = edit.player_data[player]

	if not d.select_preview or not d.select_preview.object:get_pos() then
		local obj_ref = minetest.add_entity(player:get_pos(), "edit:select_preview")
		if not obj_ref then return end
		d.select_preview = obj_ref:get_luaentity()
		d.select_preview_shown = true
	elseif not d.select_preview_shown then
		d.select_preview.object:set_detach()
		d.select_preview.object:set_properties({is_visible = true})
		d.select_preview_shown = true
	end

	local preview = d.select_preview.object
	if vector.equals(pos, preview:get_pos()) then
		return
	end

	preview:set_pos(pos)
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

	if not d.select_preview_hud then
		d.select_preview_hud = player:hud_add({
			hud_elem_type = "text",
			position = {x = 0.5, y = 0.7},
			z_index = 100,
			number = 0xffffff
		})
	end
	player:hud_change(
		d.select_preview_hud,
		"text", "X: " .. size.x .. ", Y: " .. size.y .. ", Z: " .. size.z )
end

local function set_schematic_offset(player)
	local d = edit.player_data[player]
	local yaw = player:get_look_horizontal()
	local offset = vector.new(0, 0, 0)

	local rot = d.schematic._rotation
	local x_max, z_max
	if rot == 90 or rot == 270 then
		x_max = -d.schematic.size.z + 1
		z_max = -d.schematic.size.x + 1
	else
		x_max = -d.schematic.size.x + 1
		z_max = -d.schematic.size.z + 1
	end

	if yaw < math.pi then
		offset.x = x_max
	end

	if yaw < math.pi * 1.5 and yaw > math.pi * 0.5 then
		offset.z = z_max
	end
	d.schematic_offset = offset
end

local function show_place_preview(player, pos, item)
	local d = edit.player_data[player]

	if not d.place_preview or not d.place_preview.object:get_pos() then
		local obj_ref = minetest.add_entity(player:get_pos(), "edit:place_preview")
		if not obj_ref then return end
		d.place_preview = obj_ref:get_luaentity()
		d.place_preview_shown = true
		d.place_preview_item = nil
	elseif not d.place_preview_shown then
		d.place_preview.object:set_properties({ is_visible = true })
		d.place_preview.object:set_detach()
		d.place_preview_shown = true
	end

	if not vector.equals(d.place_preview.object:get_pos(), pos) then
		d.place_preview.object:set_pos(pos)
	end

	if d.place_preview_item ~= item then
		local tex = minetest.registered_items[item].tiles[1] ..
			"^[opacity:150"

		d.place_preview_item = item
		d.place_preview.object:set_properties({
			textures = { tex, tex, tex, tex, tex, tex }
		})
	end
end

minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local item = player:get_wielded_item():get_name()
		local d = edit.player_data[player]

		-- Paste preview
		if item == "edit:paste" and d.schematic then
			local pos = edit.pointed_thing_to_pos(edit.get_pointed_thing_node(player))
			if pos then
				if not d.paste_preview or not d.paste_preview.object:get_pos() then
					create_paste_preview(player)
				end

				if not d.paste_preview_hud then show_paste_preview(player) end

				local old_pos = d.paste_preview.object:get_pos()
				pos = vector.add(pos, d.paste_preview_offset)
				set_schematic_offset(player)
				pos = vector.add(pos, d.schematic_offset)
				if not vector.equals(old_pos, pos) then
					d.paste_preview.object:set_pos(pos)
				end
			elseif d.paste_preview_hud then hide_paste_preview(player) end
		elseif d.paste_preview_hud then hide_paste_preview(player) end

		-- Stuff for Place preview and box select preview
		local marker1_pos
		local marker2_pos
		local should_show_place_preview = minetest.get_item_group(item, "edit_place_preview") ~= 0
		local should_use_box_select_preview = minetest.get_item_group(item, "edit_box_select_preview") ~= 0

		if should_show_place_preview or should_use_box_select_preview then
			local tool_def = minetest.registered_items[item]
			if tool_def._edit_get_selection_points then
				marker1_pos, marker2_pos = tool_def._edit_get_selection_points(player)
			end
			if not marker2_pos then
				if tool_def._edit_get_pointed_pos then
					marker2_pos = tool_def._edit_get_pointed_pos(player)
				else
					local pointed_thing = edit.get_pointed_thing_node(player)
					marker2_pos = edit.pointed_thing_to_pos(pointed_thing)
				end
			else should_show_place_preview = false end
		end

		-- Box select preview
		if should_use_box_select_preview and marker1_pos and marker2_pos then
			local diff = vector.subtract(marker1_pos, marker2_pos)
			local size = vector.apply(diff, math.abs)
			size = vector.add(size, vector.new(1, 1, 1))
			local size_too_big = size.x * size.y * size.z > edit.max_operation_volume
			if not size_too_big then
				local preview_pos = vector.add(marker2_pos, vector.multiply(diff, 0.5))
				update_select_preview(player, preview_pos, size)
			elseif d.select_preview_shown then hide_select_preview(player) end
		elseif d.select_preview_shown then hide_select_preview(player) end

		-- Place preview
		if should_show_place_preview and marker2_pos then
			show_place_preview(player, marker2_pos, item)
		elseif d.place_preview_shown then
			d.place_preview.object:set_properties({ is_visible = false })
			d.place_preview.object:set_attach(player)
			d.place_preview_shown = false
		end

		-- Polygon preview
		if item == "edit:polygon" or item == "edit:line" then
			if marker2_pos then
				if not d.polygon_preview_shown then
					show_polygon_preview(player)
				end

				if not d.old_pointed_pos then d.old_pointed_pos = vector.new(0.5, 0.5, 0.5) end

				if
					d.old_polygon_item ~= item or
					not vector.equals(d.old_pointed_pos, marker2_pos)
				then
					if item == "edit:polygon" then
						local markers = d.polygon_markers or {}
						local marker_pos_list = {}
						for i, marker in ipairs(markers) do
							table.insert(marker_pos_list, marker._pos)
						end
						table.insert(marker_pos_list, marker2_pos)
						update_polygon_preview(player, marker_pos_list)
					else
						local marker_pos_list = {}
						if marker1_pos then table.insert(marker_pos_list, marker1_pos) end
						table.insert(marker_pos_list, marker2_pos)
						update_polygon_preview(player, marker_pos_list)
					end
					d.old_pointed_pos = marker2_pos
					d.old_polygon_item = item
				end
			end
		elseif d.polygon_preview_shown then
			hide_polygon_preview(player)
		end

		if item == "edit:polygon" then
			if not d.polygon_preview_hud then
				d.polygon_preview_hud = player:hud_add({
					hud_elem_type = "text",
					text = "Finish the polygon by placing a marker on the green marker",
					position = {x = 0.5, y = 0.8},
					z_index = 100,
					number = 0xffffff
				})
			end
		elseif d.polygon_preview_hud then
			player:hud_remove(d.polygon_preview_hud)
			d.polygon_preview_hud = nil
		end
	end
end)
