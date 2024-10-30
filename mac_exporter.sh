# Exports only the mac version uncompressed into the ../tinybox_latest folder.

read -p 'Enter version name (ex. b9.10, b10.11pre): ' VERNAME

rm -rf ../tinybox_latest/*

mkdir ../tinybox_latest
mkdir ../tinybox_latest/binaries
mkdir ../tinybox_latest/binaries/Tinybox-mac


godot --headless --export-release "mac" ../tinybox_latest/binaries/Tinybox-mac/Tinybox.app