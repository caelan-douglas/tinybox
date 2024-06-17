# Contributing
Contributions to Tinybox are appreciated. This is a hobby project, so pull requests will generally be reviewed whenever I get the chance - sorry if it takes a while!

## Setting up the project
Like any other Godot project, working on a copy of Tinybox is mostly just a matter of opening it in the Godot editor. The project's current Godot version can be found in the README in the root folder.<br>
An additional step you will have to take is linking a Blender 3.0+ executeable in your Godot Editor settings:
`Editor > Editor Settings > FileSystem > Import > Blender 3 Path`<br>
If done correctly, you should be able to see the .blend files in the /data/models directory within the Editor filesystem. On macOS, you will have to link the actual executeable within the Blender.app Contents, not Blender.app binary itself.

## Guidelines
### What's accepted?
Please submit pull requests for bug fixes, code quality improvements, and optimizations of any kind. For new features, please see the **Game vision** section in the [`README.md`](../README.md) file to get an idea of the type of features that are planned for the game. If you're not sure about whether or not your feature idea aligns with the game's goals, you can always feel free to create a feature request in the Issues before making a PR to discuss it.

### What's not accepted?
Pull requests for the following may be rejected:
- **🚫 Formatting changes or rewording**
    - Changing tabs to spaces, removing excess whitespace, simply changing variable names, etc. Unless these are supportive changes as part of a bigger PR with code changes, formatting changes will most likely be rejected. Additionally, rewording of strings and other files such as the README will likely not be accepted.
-  **🚫 Refactoring and file structure changes**
    - Unless done so for performance gain, PRs for refactors of the code or changes to the file structure alone will probably be rejected.

### Please check your changes
Please run the game and do some basic testing to make sure your changes are functional before submitting the PR.

## Styling
Be sure to add the GNU AGPLv3 copyright comment to the top of your .gd files (you can copy this from another file like `Main.gd`). Add yourself to the copyright notice (or 'and contributors' if you would rather not have your name in the notice.)

#### Code formatting
- Please indent with tabs, not spaces.
- Prefix a '_' on variables or functions that are 'private' (should only be used within the script file)
- Define the return type in the function declaration (see below).

#### Functions
Public functions should be formatted as:<br>
`func public_function(arg_1 : Type) -> ReturnType:`

'Private' functions should be:<br>
`func _private_function(arg_1 : Type) -> ReturnType:`

#### Variables

Variables should be defined with their type:

`var public_var : String = "hi"`<br>
`var _private_var : String = "private variable"`

#### File names

Scene files and scripts are generally named WithCapsLikeThis<br>
RigidPlayer.gd<br>
SomeSceneFile.tscn

everything else is lowercase_with_underscores.

#### File structure

```
- /
  - addons - External Godot addons
  - doc - Miscellanious documentation (faq, manual, etc...)
  - data - Resources (textures, audio, models, scene files, etc...)
  - src - All script files
```

### Credits
If you wish to be in the game's credits, add your name (or GitHub username) to the [`/contributors.txt`](../contributors.txt) on a new line as part of your PR.