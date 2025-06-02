If you haven't downloaded the project files yet, take a look at the **Setting up the project** section of the [`README`](../README.md).

# Contributing
Contributions to Tinybox are appreciated! This is a hobby project, so pull requests will generally be reviewed whenever I get the chance - sorry if it takes a while!

### Game vision
If you just want to contribute a bugfix or optimization, then the following section isn't particularily relevant, but if you're considering a new feature and want an idea of the game vision:

Tinybox *('tiny + sandbox')* is a sandbox game focused on creativity, experimentation, and destroying your friends with rockets in casual gamemodes. Bricks allow players to create destructible platforms, bridges, houses, vehicles, etc. The world editor allows players to delve a bit deeper and create their own worlds with custom contraptions. The main goal of feature updates in the project is to expand on this with more items, brick types, environments, gamemodes, player interactions, online features, etc - and of course, optimizations, bug fixes, and improvements along the way.

What Tinybox isn't trying to be is a survival game, a ranked competitive game, an MMO, etc. While some features such as custom world events or gamemodes might eventually make their way into the game, in general, the vision mentioned above is the extent of the scope of the core game code. With that in mind...


## Guidelines for PRs
### What's accepted?
Please submit pull requests for bug fixes, code quality improvements, and optimizations of any kind! New features are also welcome, but please note you can also create an issue under the 'feature request' tag to discuss, if you wish to make a new feature PR to the main repo - this way you know whether it aligns with the goals of the game.

### Styling
Be sure to add the GNU AGPLv3 license details to the top of your .gd files, if you make any new ones (you can copy this from another file like `/Main.gd`). When making new .gd files, there is a template called 'Tb default' that contains this already. Add yourself to the copyright notice (or 'and contributors' if you would rather not have your name in the notice.)

#### Code formatting
- Please indent with tabs, not spaces.
- Prefix a '_' on variables or functions that are 'private' (should only be used within the script file)
- Define the return type in the function declaration when returning a single type (see below).

#### Functions
Public functions should be formatted as:<br>
`func public_function(arg_1 : Type) -> ReturnType:`

'Private' functions should be:<br>
`func _private_function(arg_1 : Type) -> ReturnType:`

#### Variables

Variables should be defined with their type:

`var public_var : String = "hi, how are you?"`<br>
`var _private_var : String = "private variable"`

#### Naming convention

**Scene files** and **scripts** are generally named WithCapsLikeThis<br>
everything else is lowercase_with_underscores.

#### File structure

```
- /
  - .export_exclude - any assets that are not part of the game
                      (like images used in /docs files)
  - addons - External Godot addons
  - docs - Miscellanious documentation (faq, manual, etc...)
  - data - Resources (textures, audio, models, scene files, etc...)
  - src - All script files (except Main.gd, which is in root folder)
```

### Credits
If you wish to be listed as a contributor, add your name (or GitHub username) to the [`/contributors.txt`](../contributors.txt) on a new line as part of your PR.
