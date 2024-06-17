# Tinybox<img src=icon.png align="left" width="128px" style="padding: 20px">

Free and open source sandbox game with peer-to-peer multiplayer, gamemodes, world editor (in progress), PvP and a physics-based building system. It is made with Godot 4 using GDScript.

[![Tinybox](https://img.shields.io/badge/Get%20latest-beta%209.9-teal?style=plastic)](https://github.com/caelan-douglas/tinybox/releases/latest)<br>
[![Godot](https://img.shields.io/badge/Godot%20version-4.2.2-purple?logo=godotengine&logoColor=white&style=plastic)](https://godotengine.org/)
<br>
### License

Tinybox is free software licensed under the GNU Affero General Public License v3 (GNU AGPLv3), located in [`COPYING.txt`](COPYING.txt).

Some assets (textures, audio, music, etc.) are under different licensing. These licenses include, but are not necessarily limited to:

- GNU AGPLv3
- Creative Commons CC0
- Creative Commons CC-BY-SA 4.0

Files with different licenses are denoted in the various `licenses.txt` files located in the respective data folders, which point to the file's source and their license.

The Godot Engine is under its own license, the details of which are noted at https://godotengine.org/license/.

## About & technical stuff

<img src=screenshot_1.png width="512px" style="padding: 8px; background-color: white; box-shadow: 0px 10px 20px 4px rgba(0, 0, 0, 0.3);">

### Game vision
Tinybox ('tiny sandbox') is designed to be a sandbox-first game that promotes creativity and experimentation. To expand on this, the project's primary goals as of now are to add new building features, a more open way for players to create their own levels and gamemodes, and the ability for players to create more complex multiplayer interactions, such as with a basic visual scripting language.

### Blender imports

In order to build the game from source you must have Blender 3.0+ installed and located in Godot:<br>
`Editor > Editor Settings > FileSystem > Import > Blender 3 Path`

### Code formatting

Prefix a '_' on variables or functions that are 'private' (should only be used within the script file)

#### Functions

Public functions should be formatted as:

`func public_function(arg_1 : Type) -> ReturnType:`

"Private" functions should be:

`func _private_function(arg_1 : Type) -> ReturnType:`

#### Variables

Variables should be defined with their type:

`var public_var : String = "hi"`<br>
`var _private_var : String = "private variable"`

### Styling

Scene files and scripts are generally named WithCapsLikeThis<br>
RigidPlayer.gd<br>
SomeSceneFile.tscn

everything else is lowercase_with_underscores.tres

### File structure

```
- /
  - addons - External Godot addons
  - doc - Miscellanious documentation (faq, manual, etc...)
  - data - Resources (textures, audio, models, scene files, etc...)
  - src - All script files
```

### Versioning

Versioning is as follows:

beta A.B.C

where:
- A - major release (big new feature)
- B - minor release (smaller changes or additions that are visible to the player, or significant backend change like a large refactor)
- C - hotfix release (small changes or fixes that are not visible to the player).

For .0 releases, omit the .0 in the display version (for example, beta 11.0.0 would simply be beta 11; beta 11.5.0 would be beta 11.5)

The `server_version` (located in Main.gd) is the version without periods (beta 11 would be 1100.)
