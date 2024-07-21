# Exports all three versions into the ../tinybox_latest folder.

read -p 'Enter version name (ex. b9.10, b10.11pre): ' VERNAME

rm -rf ../tinybox_latest/*

mkdir ../tinybox_latest
mkdir ../tinybox_latest/binaries
mkdir ../tinybox_latest/binaries/Tinybox-linux
mkdir ../tinybox_latest/binaries/Tinybox-mac
mkdir ../tinybox_latest/binaries/Tinybox-win


godot --headless --export-release "linux" ../tinybox_latest/binaries/Tinybox-linux/Tinybox.x86_64
godot --headless --export-release "mac" ../tinybox_latest/binaries/Tinybox-mac/Tinybox.app
godot --headless --export-release "win" ../tinybox_latest/binaries/Tinybox-win/Tinybox.exe

echo '\n\nCompressing builds, please wait.'

# Finder compress tool
ditto -c -k --sequesterRsrc --keepParent ../tinybox_latest/binaries/Tinybox-linux ../tinybox_latest/Tinybox-$VERNAME-linux.zip
ditto -c -k --sequesterRsrc --keepParent ../tinybox_latest/binaries/Tinybox-mac ../tinybox_latest/Tinybox-$VERNAME-mac.zip
ditto -c -k --sequesterRsrc --keepParent ../tinybox_latest/binaries/Tinybox-win ../tinybox_latest/Tinybox-$VERNAME-win.zip