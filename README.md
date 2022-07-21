# Minetest Edit Mod


[![ContentDB](https://content.minetest.net/packages/Mr.%20Rar/edit/shields/downloads/)](https://content.minetest.net/packages/Mr.%20Rar/edit/)


## Overview


This mod named `edit` allows copying, pasting, filling, deleting, opening and saving 3D areas.
Schematics are loaded and saved from .mts files located in the world subfolder `schems`.

This mod was inspired by the Fill Start and Fill End blocks in Manic Digger.

![screenshot](screenshot.png)

## Items

| Name   | Node ID     | Image                         |
| ------ | ----------- | ----------------------------- |
| Copy   | edit:copy   | ![](textures/edit_copy.png)   |
| Paste  | edit:paste  | ![](textures/edit_paste.png)  |
| Fill   | edit:fill   | ![](textures/edit_fill.png)   |
| Delete | edit:delete | ![](textures/edit_delete.png) |
| Open   | edit:open   | ![](textures/edit_open.png)   |
| Save   | edit:save   | ![](textures/edit_save.png)   |
| Undo   | edit:undo   | ![](textures/edit_undo.png)   |


## Dependences

None


## Usage

### Copy Node

![figure1.png](figure1.png)

When two copy nodes are placed at opposite corners of an area, they select the area as show in figure 1. When an area is selected, it is copied and the two copy nodes are deleted.


### Paste Node

The paste node is used for pasting the area copied by the copy node or a schematic loaded with the open node. When a paste node is placed, the copied area or schematic is placed at the corner of the paste node. In the case of a copied area, area is pasted relative to the position of the first placed copy node when it was copied. The copied area can be rotated when the paste preview is visable by pressing the sneak key and an arrow key.


### Delete Node

Delete nodes are used to delete an area. When two delete nodes are placed at opposite corners of an area, they select the area as show in figure 1. When an area is selected, it is deleted and the two delete nodes are removed as well.


### Fill Node

![figure1.png](figure2.png)

Fill nodes are used to fill a 3D area with a certain item. Start by placing two fill nodes at opposite corners of the desired area. The selected area includes the positions of the fill nodes themselves as shown in figure 2.

Once a second fill node is placed, a dialog appears listing all items in the players inventory. Clicking an item will cause it to be used used for filling the selected area. Clicking on a blank slot will cause the selected area to be filled with air. To cancel the fill, press the "X".


### Open Tool

Right click with this tool to load a .mts schematic for pasting from the the world subfolder `schems`.


### Save Tool

Right click with this tool to save copied area as a .mts schematic in the the world subfolder `schems`.


### Undo Tool

Right click with this tool to undo a world modification like filling or pasting.
Use a second time to redo the undo.
Only the most resent world modification can be undone.


### License

CC0 by MrRar check [License](LICENSE) file, this mod was started by MrRar, 
minetest-mods community.

