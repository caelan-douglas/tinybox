If you haven't downloaded the project files yet, take a look at the **Setting up the project** section of the [`README`](../README.md).

# Contributing

Community involvement is at the heart of open-source projects, so please feel free to fork and make a PR anytime.

That said, my vision for the game has followed a few core principles:
- A big focus on experimentation and creativity.
- Gamemodes should be casual and let players have fun and relax.
- Online features are decentralized, meaning community-hosted servers and repositores are very much encouraged.


## A few guidelines

Don't fret too much on code styling, naming convention, etc. I certainly haven't been very consistent myself in this project (cleanup/optimization PRs are very much appreciated!) Either way, here's some guidelines:

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

Because static typing is enforced in the project, variables should be defined with their type:

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
