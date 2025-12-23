<br>
<img style="padding-bottom: 30px" src=title.png width="250px"></p>
<img src=.export_exclude/promo-gif.gif width="500px">
<br><br>
Free and open source sandbox game with online multiplayer, world editor, gamemodes, and a physics-based building system you can use to make worlds, contraptions, vehicles and more. Made with Godot 4 using GDScript.<br><br>

### Links
[<img alt="Download link" height="24px" src="https://img.shields.io/badge/Download%20the%20latest%20beta%20-%20%2F?color=teal">](https://github.com/caelan-douglas/tinybox/releases/latest)<br><br>
[<img alt="Contrib guidelines link" height="24px" src="https://img.shields.io/badge/Contribute!%20-%20%2F?color=grey">](docs/CONTRIBUTING.md)<br>
[<img alt="Hosting a server link" height="24px" src="https://img.shields.io/badge/Hosting%20a%20server%20-%20%2F?color=grey">](docs/SERVERS.md)<br>
[<img alt="Promo video link" height="24px" src="https://img.shields.io/badge/Short%20promo%20video%20(youtube)%20-%20%2F?color=darkred">](https://www.youtube.com/watch?v=_35vkHCguak)<br>

## License

Tinybox is free software licensed under the GNU Affero General Public License v3 (GNU AGPLv3), located in [`COPYING.txt`](COPYING.txt).

Some assets (textures, audio, music, etc.) are under different licensing. These licenses include, but are not necessarily limited to:

- GNU AGPLv3
- Creative Commons CC0
- Creative Commons CC-BY-SA 4.0
- MIT License

Files with different licenses are denoted in the various `licenses.txt` files located in the respective data folders, which point to the file's source and their license.

The Godot Engine is under its own license, the details of which are noted at https://godotengine.org/license/.

## Setting up the project for development
[![Godot](https://img.shields.io/badge/Project%20Godot%20version:-4.5-purple?logo=godotengine&logoColor=white&style=plastic)](https://godotengine.org/)<br>
Like any other Godot project, working on a copy of Tinybox is mostly just a matter of opening it in the Godot editor. Note that active development sometimes happens on the main branch, so pre-release versions of the game may be unstable. The project's current Godot version is linked above.<br>
An additional step you will have to take is linking a Blender 4.4.0+ executable in your Godot Editor settings. **I recommend you do this before loading the project to avoid import errors.**<br>
`Editor > Editor Settings > FileSystem > Import > Blender 3 Path`<br>
If done correctly, you should be able to see the .blend files in the /data/models directory within the Editor filesystem. On macOS, you will have to link the actual executeable within the Blender.app Contents, not Blender.app binary itself. For example, on my macOS install the path I have set is:
`/Applications/Blender.app/Contents/MacOS`

If you're working on this (or any multiplayer project) and running Windows, I recommend using the app [`clumsy`](https://github.com/jagt/clumsy), which is very helpful for simulating bad network conditions (latency, dropped packets, throttled connection, etc.) when testing. On macOS there is a similar terminal utility called [`throttle`](https://www.sitespeed.io/documentation/throttle/).

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
- `downloads` (int): download count (updated via a method defined later)
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
