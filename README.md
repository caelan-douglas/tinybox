<br>
<p align="center"><img src=title.png width="450px"></p>
Free and open source sandbox game with peer-to-peer multiplayer, world editor, PvP and a physics-based building system. It is made with Godot 4 using GDScript.<br><br>

Download the latest beta release:<br>
[![Tinybox](https://img.shields.io/badge/Get%20latest-beta%20version-teal?style=plastic)](https://github.com/caelan-douglas/tinybox/releases/latest)<br>
### License

Tinybox is free software licensed under the GNU Affero General Public License v3 (GNU AGPLv3), located in [`COPYING.txt`](COPYING.txt).

Some assets (textures, audio, music, etc.) are under different licensing. These licenses include, but are not necessarily limited to:

- GNU AGPLv3
- Creative Commons CC0
- Creative Commons CC-BY-SA 4.0

Files with different licenses are denoted in the various `licenses.txt` files located in the respective data folders, which point to the file's source and their license.

The Godot Engine is under its own license, the details of which are noted at https://godotengine.org/license/.

## About

### Screenshots
<img src=.export_exclude/screenshot_1.png width="600px">
<img src=.export_exclude/screenshot_2.png width="600px">
<img src=.export_exclude/screenshot_3.png width="600px">

### Game vision
Tinybox *('tiny + sandbox')* is a sandbox game focused on creativity, experimentation, and destroying your friends with rockets. Bricks allow players to create destructible platforms, bridges, houses, vehicles, etc. The world editor allows players to delve a bit deeper and create their own worlds with custom events and features. As of now, the main goal of feature updates in the project is to expand on this with more included worlds; new features, events, and objects in the editor; and new item types.

In order to keep PvP aligned with the physics-based sandbox nature of the game, weapons generally interact with the world in some way (ex. bombs and rockets for ranged weapons, rather than hitscan weapons.)

## Setting up the project
[![Godot](https://img.shields.io/badge/Project%20Godot%20version:-4.2.2-purple?logo=godotengine&logoColor=white&style=plastic)](https://godotengine.org/)<br>
Like any other Godot project, working on a copy of Tinybox is mostly just a matter of opening it in the Godot editor. The project's current Godot version is linked above.<br>
An additional step you will have to take is linking a Blender 3.0+ executeable in your Godot Editor settings. **I recommend you do this before loading the project to avoid import errors.**<br>
`Editor > Editor Settings > FileSystem > Import > Blender 3 Path`<br>
If done correctly, you should be able to see the .blend files in the /data/models directory within the Editor filesystem. On macOS, you will have to link the actual executeable within the Blender.app Contents, not Blender.app binary itself. For example, on my macOS install the path I have set is:
`/Applications/Blender.app/Contents/MacOS`

If you're working on this (or any multiplayer project) and running Windows, I recommend using the app [`clumsy`](https://github.com/jagt/clumsy), which is very helpful for simulating bad network conditions (latency, dropped packets, throttled connection, etc.) when testing.

Tinybox enforces statically typed GDScript - see the static typing guide [`here.`](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)