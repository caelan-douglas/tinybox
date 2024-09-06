# Hosting a Server<img src=../.export_exclude/docs-hosting-icon.png align="left" width="128px" style="padding: 20px">

Tinybox uses a P2P system where one player is the host and the rest of the clients connect directly to that host. The host must have Tinybox's port range, `30815-30816`, port-forwarded on their router.

The main menu has an option to "Port-forward w/ uPnP" in the hosting panel. It's recommended you try this first. It will attempt to temporarily forward the port on your router while the server is open. If it works, your friends should be able to connect to your public IP. Once the game is closed, the port forward will be removed.

However, uPnP is understandably disabled by default for a lot of routers, so if it doesn't work, you will need to manually forward the Tinybox port range with TCP/UDP: `30815-30816`.

## Starting a dedicated server from the command line

**macOS**: In terminal navigate to where the Tinybox binary is and type <br>`open ./Tinybox.app --args -server`<br><br>
**Linux**: In terminal navigate to where the Tinybox binary is and type <br>`./Tinybox.x86_64 -server`<br><br>
**Windows**: In command prompt navigate to where the Tinybox executeable is and type <br>`Tinybox.exe -server`

The server will use your saved display name. Currently there is no headless option (the app will open a seperate window). Dedicated server is supported in beta 10.2 and later.