# Exports all three versions into the ../tinybox_latest folder.

read -p 'Enter version name (ex. b9.10, b10.11pre): ' VERNAME

rm -rf ../tinybox_latest/*

mkdir ../tinybox_latest
mkdir ../tinybox_latest/binaries

godot --headless --export-release "linux" ../tinybox_latest/binaries/Tinybox.x86_64
godot --headless --export-release "mac" ../tinybox_latest/binaries/Tinybox.app
godot --headless --export-release "win" ../tinybox_latest/binaries/Tinybox.exe

echo '\n\nCompressing builds, please wait.'

# Finder compress tool
ditto -c -k --sequesterRsrc --keepParent ../tinybox_latest/binaries/Tinybox.x86_64 ../tinybox_latest/Tinybox-$VERNAME-linux.zip
ditto -c -k --sequesterRsrc --keepParent ../tinybox_latest/binaries/Tinybox.app ../tinybox_latest/Tinybox-$VERNAME-mac.zip
ditto -c -k --sequesterRsrc --keepParent ../tinybox_latest/binaries/Tinybox.exe ../tinybox_latest/Tinybox-$VERNAME-win.zip