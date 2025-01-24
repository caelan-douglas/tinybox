<br>
<img align="left" style="padding: 40px" src=title.png width="250px"></p>
Free and open source sandbox game with peer-to-peer multiplayer, world editor, PvP, and a physics-based building system you can use to make worlds, contraptions, vehicles and more. Made with Godot 4 using GDScript.<br><br>

[<img alt="Download link" height="24px" src="https://img.shields.io/badge/Link%3A%20Get%20the%20latest%20beta!%20-%20%2F?color=teal&link=https%3A%2F%2Fgithub.com%2Fcaelan-douglas%2Ftinybox%2Freleases%2Flatest">](https://github.com/caelan-douglas/tinybox/releases/latest)<br>

### License

Tinybox is free software licensed under the GNU Affero General Public License v3 (GNU AGPLv3), located in [`COPYING.txt`](COPYING.txt).

Some assets (textures, audio, music, etc.) are under different licensing. These licenses include, but are not necessarily limited to:

- GNU AGPLv3
- Creative Commons CC0
- Creative Commons CC-BY-SA 4.0
- MIT License

Files with different licenses are denoted in the various `licenses.txt` files located in the respective data folders, which point to the file's source and their license.

The Godot Engine is under its own license, the details of which are noted at https://godotengine.org/license/.

## About

### Screenshots
<img src=.export_exclude/screenshot_4.png width="800px">
<img src=.export_exclude/screenshot_1.png width="800px">
<img src=.export_exclude/screenshot_3.png width="800px">
<img src=.export_exclude/screenshot_2.png width="800px">

### Game vision
Tinybox *('tiny + sandbox')* is a sandbox game focused on creativity, experimentation, and destroying your friends with rockets. Bricks allow players to create destructible platforms, bridges, houses, vehicles, etc. The world editor allows players to delve a bit deeper and create their own worlds with custom events and features. As of now, the main goal of feature updates in the project is to expand on this with more included worlds; new features, events, and objects in the editor; and new item types.

In order to keep PvP aligned with the physics-based sandbox nature of the game, weapons generally interact with the world in some way.

## Setting up the project
[![Godot](https://img.shields.io/badge/Project%20Godot%20version:-4.2.2-purple?logo=godotengine&logoColor=white&style=plastic)](https://godotengine.org/)<br>
Like any other Godot project, working on a copy of Tinybox is mostly just a matter of opening it in the Godot editor. The project's current Godot version is linked above.<br>
An additional step you will have to take is linking a Blender 3.0+ executeable in your Godot Editor settings. **I recommend you do this before loading the project to avoid import errors.**<br>
`Editor > Editor Settings > FileSystem > Import > Blender 3 Path`<br>
If done correctly, you should be able to see the .blend files in the /data/models directory within the Editor filesystem. On macOS, you will have to link the actual executeable within the Blender.app Contents, not Blender.app binary itself. For example, on my macOS install the path I have set is:
`/Applications/Blender.app/Contents/MacOS`

If you're working on this (or any multiplayer project) and running Windows, I recommend using the app [`clumsy`](https://github.com/jagt/clumsy), which is very helpful for simulating bad network conditions (latency, dropped packets, throttled connection, etc.) when testing.

Tinybox enforces statically typed GDScript - see the static typing guide [`here.`](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)

## World Database API documentation

There is a feature in the game that contacts a remote API. Using this API, the user can upload their own worlds and fetch worlds made by other users.

By default it links to https://tinybox-worlds.caelan-douglas.workers.dev/. You can change the world repo in-game in Settings -> World Database Repo. If you wish to make your own repo, you can implement this API however you like, but these are the guidelines on the data that the game expects to recieve & what it sends.

The functionality of the repo is as follows (where `/` is the root of the API web page):

---

### `GET` requests

#### `/`
 Returns an array containing all the worlds in the database. Each entry has a dictionary with the following:
- `id` (int): world ID in the database
- `name` (string)
- `featured` (int): 1 for featured, 0 for not featured
- `date` (string): format YYYY-MM-DD
- `downloads` (int): download count (updated via a `POST` request defined later)
- `version` (string): internal server version of map (ie. 12020)
- `author` (string): author name
- `image` (string): base64 image preview

#### `/?id=X`
Returns TBW file of map, where X is the map ID; used for downloading. No other data is returned.

- `tbw` (string): full TBW world file plaintext

Internally, this also increments the `downloads` member of the world in the database.

#### `/?report=X`
Reports a map, where X is its ID. Internally this increments the `reports` member of the world in the database.


---
### `POST` requests

#### `/`
Uploads a map to the database. The `Content-Type` header should be `application/json`. The body should contain the following values:

- `name` (string): name of the map
- `tbw` (string): full plaintext tbw file. Information like the preview image, author name, and version can be parsed from this file and then stored in the database.

Returns body with `OK` if the upload was successful. If the body does not return `OK`, then the game will consider the upload failed.

This is ratelimited by the server on a per-user basis.