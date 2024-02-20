# Minetest Edit Mod


[![ContentDB](https://content.minetest.net/packages/Mr.%20Rar/edit/shields/downloads/)](https://content.minetest.net/packages/Mr.%20Rar/edit/)


## Overview


This mod named `edit` allows copying, pasting, filling, deleting, opening and saving 3D areas.
Schematics are loaded and saved from .mts files located in the world sub folder `schems`.

This mod was inspired by the Fill Start and Fill End blocks in Manic Digger.

![screenshot](screenshot.png)

## Items

| Name        | Item ID          | Image                              |
| ----------- | ---------------- | ---------------------------------- |
| Copy        | edit:copy        | ![](textures/edit_copy.png)        |
| Paste       | edit:paste       | ![](textures/edit_paste.png)       |
| Fill        | edit:fill        | ![](textures/edit_fill.png)        |
| Replace     | edit:replace     | ![](textures/edit_replace.png)     |
| Open        | edit:open        | ![](textures/edit_open.png)        |
| Save        | edit:save        | ![](textures/edit_save.png)        |
| Undo        | edit:undo        | ![](textures/edit_undo.png)        |
| Circle      | edit:circle      | ![](textures/edit_circle.png)      |
| Mirror      | edit:mirror      | ![](textures/edit_mirror.png)      |
| Screwdriver | edit:screwdriver | ![](textures/edit_screwdriver.png) |
| Polygon     | edit:polygon     | ![](textures/edit_polygon.png)     |
| Bag         | edit:bag         | ![](textures/edit_bag.png)         |


## Dependencies

None


## Usage

### Copy Tool

When the copy tool is placed at opposite corners of an area, the area is copied. When the copy tool is placed for the first time, a marker entity is placed. To cancel the copy operation, punch the marker. When a copy tool is placed a second time, the selected area is copied and the markers are removed.


### Paste Tool

The paste tool is used for pasting the area copied by the copy tool or a schematic loaded with the open tool. When a paste tool is placed, the copied area or schematic is placed at the corner of the paste tool. The copied area can be rotated by punching while holding the paste tool.


### Fill Tool

The fill tool is used to fill a 3D area with a certain item. Start by placing the fill tool two times at opposite corners of the desired area.

Once a second fill marker is placed, a dialog appears listing all items in the players inventory. A search field is also available to search all items. Clicking an item will cause it to be used used for filling the selected area. Clicking on a blank inventory slot will cause the selected area to be filled with air. To cancel the fill, press the "X".


### Replace Tool

The replace tool is used to replace certain nodes in a 3D area with a selected item. Start by placing the replace tool two times at opposite corners of the desired area.

Once a second replace marker is placed, a dialog appears listing all node types in the selected area. Check the nodes that should be replaced and then press the "OK" button to proceed with the next step. Next a dialog will pop up showing all the items in the players inventory. A search field is also available to search all items. Clicking an item will cause it to be used used to replace the nodes that were checked earlier. Clicking on a blank inventory slot will cause the checked nodes to be replaced with air. To cancel the replace, press the "X".


### Open Tool

Right click with this tool to load .we or .mts schematics from the world subfolder `schems` for pasting.
Large .we files may fail to load.


### Save Tool

Right click with this tool to save copied area as a .we or .mts schematic in the the world subfolder `schems`.
.mts is the native schematic for Minetest. However it does not support node meta data so some nodes will not be properly saved.
For example, the contents of a chest will be missing.
.we is the WorldEdit format. It supports node meta data but it produces much larger files than .mts.
Large .we files may fail to load.


### Undo Tool

Right click with this tool to undo a world modification like filling or pasting.
Use a second time to redo the undo.
Only the most resent edit operation can be undone.


### Circle Tool

This tool is used to create round structures. Place the tool to activate circle mode. A center point marker is placed wherever the circle tool is placed. In circle mode, any node that is placed will be repeated in a circle around the center point. Node digging is also repeated in the same way. To place or dig a node without it repeating it in a circle, press the aux1 key (E) while placing or digging. To exit circle mode, punch the circle center marker.


### Mirror Tool

This tool is used to mirror the placement or digging of nodes. Place the tool to activate mirror mode. A center point marker is placed wherever the mirror tool is placed. In mirror mode all placed or dig nodes are mirrored. To place or dig a node without mirroring, press the aux1 key (E) while placing or digging. The mirror tool supports four modes, X, Z, X and Z, and eighths. To switch modes, right click the center marker. To exit mirror mode, punch the center marker.


### Screwdriver

This tool is used for rotating nodes that support rotation. Right clicking a node with the screwdriver rotates the node around the X or Z axis depending on the player's position. Left clicking a node with the screwdriver rotates the node clockwise around the Y axis. Param2 types `wallmounted`, `facedir`, and `degrotate` are supported. The node is rotated 90 degrees for all param2 types except `degrotate` where the node is rotated by either 1.5 or 15 degrees. If the aux1 key (E) is held while rotating a `degrotate` node, the rotation angle will be increased by 4x.


### Polygon Tool

This tool is used to create non-concave polygons in 3D space. Place the polygon tool to create markers. Each marker will create a triangle between itself, the last marker placed, and the first marker placed. The first marker placed will be green. To finish the polygon, place a marker on top of the green marker. After doing so, a dialog will appear to select a node or item to fill the polygon.


### Bag

The bag tool is used to place random items from a list of items. Dig (left click) with the bag to open the bag's inventory. Any item from the player inventory can be moved into the bag. The bag has 16 item slots. When placing the bag an item from the bag is randomly chosen to be placed. If a stack of several items is present in the bag, the item will be more likely to be placed than a single item. The probability of being placed is proportional to the item's count divided by the total count of items in the bag. For example, the probability of getting wood would be 75% for a bag with 3 wood and 1 dirt. Bags can be combined with other edit tools, for example, to fill an area with random kinds of dirt.


## Settings

### edit_paste_preview_max_entities

If the copied area has a larger number of nodes, some nodes will be randomly excluded from the preview.


### edit_max_operation_volume

The maximum volume of any edit operation. Increase to allow larger operations.


### edit_fast_node_fill_threshold

When the fill operation has a larger volume then the specified number, fast node fill will be used. To disable fast node placement, set the threshold to be equal to the max operation volume. To disable slow node placement, set the threshold to 0. With fast node placement, callbacks are not called so some nodes might be broken.


### edit_polygon_preview_wire_frame_threshold

If one side of the polygon preview is greater than this setting, a wire frame is used instead of the full preview. The full preview fills the entire polygon with preview entites. If the polygon gets big, the full preview will quickly crash a server. The wire frame preview outlines the triangle componants of the polygon. This setting only affects the preview. The polygon is always completely filled regardless of this setting.


## Privileges

Edit tools and nodes can only be used by players with `edit` privilege.


## License

MIT by MrRar check [License](LICENSE.txt) file, this mod was started by MrRar, 
minetest-mods community.

