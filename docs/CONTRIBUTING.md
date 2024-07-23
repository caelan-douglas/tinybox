Before forking or contributing, take a look at the **Setting up the project** section of the [`README`](../README.md).

# Contributing
Contributions to Tinybox are appreciated! This is a hobby project, so pull requests will generally be reviewed whenever I get the chance - sorry if it takes a while!


## Guidelines for PRs
### What's accepted?
Please submit pull requests for bug fixes, code quality improvements, and optimizations of any kind. For new features, please see the **Game vision** section in the [`README.md`](../README.md) file to get an idea of the type of features that are planned for the game. I recommend that you create an issue under the 'feature request' tag to discuss, if you wish to make a new feature PR to the main repo - this way you know for sure whether it aligns with the goals of the game.

### What's not accepted?
Pull requests for the following may be rejected:
- **🚫 Formatting changes or rewording**
    - Changing tabs to spaces, removing excess whitespace, simply changing variable names, etc. Unless these are supportive changes as part of a bigger PR with code changes, formatting changes will most likely be rejected. Additionally, rewording of strings and other files such as the README will likely not be accepted.
-  **🚫 Refactoring and file structure changes**
    - Unless done so for performance gain or improving code quality, PRs for refactors of the code or changes to the file structure alone will probably be rejected.

### Please check your changes
Please run the game and do some basic testing to make sure your changes are functional before submitting the PR.

### Styling
Be sure to add the GNU AGPLv3 license details to the top of your .gd files (you can copy this from another file like `/Main.gd`). Add yourself to the copyright notice (or 'and contributors' if you would rather not have your name in the notice.)

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
  - doc - Miscellanious documentation (faq, manual, etc...)
  - data - Resources (textures, audio, models, scene files, etc...)
  - src - All script files
```

### Credits
If you wish to be listed as a contributor, add your name (or GitHub username) to the [`/contributors.txt`](../contributors.txt) on a new line as part of your PR.