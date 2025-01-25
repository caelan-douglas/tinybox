# Hosting a Server<img src=../.export_exclude/docs-hosting-icon.png align="left" width="128px" style="padding: 20px">

If you just want to start a dedicated server, read the section below. You can also try joining one of the default servers in the server list, if they're online. Otherwise, here's how to host from in-game:

Tinybox uses a P2P system where one player is the host and the rest of the clients connect directly to that host. The host must have Tinybox's port range, `30815-30816`, port-forwarded on their router.

The host options section (+) has "Port-forward w/ uPnP". It's recommended you try this first. It will attempt to temporarily forward the port on your router while the server is open. If it works, your friends should be able to connect to your public IP. Once the game is closed, the port forward will be removed.

However, uPnP is understandably disabled by default for a lot of routers, so if it doesn't work, you will need to manually forward the Tinybox port range with TCP/UDP: `30815-30816`.

## Starting a dedicated server from the command line

**macOS**: In terminal navigate to where the Tinybox app is and type <br>`./Tinybox.app/Contents/MacOS/Tinybox --headless`<br><br>
**Linux**: In terminal navigate to where the Tinybox binary is and type <br>`./Tinybox.x86_64 --headless`<br><br>
**Windows**: In command prompt navigate to where the Tinybox executeable is and type <br>`Tinybox.exe --headless`

The server will use your saved display name, and will run out of your terminal.

## Moderating

The command list can be shown by typing "?" in console.<br>
Typing "$end" will end the server.<br>
Typing "$quit" will exit the app.
You can ban players with "$ban playername". This is an IP ban.
