# Hosting a Server<img src=../.export_exclude/docs-hosting-icon.png align="left" width="128px" style="padding: 20px">

You can host servers in a number of ways. The first is by running the game in the dedicated headless server mode. If you run a dedicated server, you can also request to add it to the in-game server list.

If you just want to host a temporary server for your friends to join, go to the 'Temporary host' section.

## Starting a dedicated server from the command line

Before hosting a dedicated server you'll need to port-forward Tinybox's port range, `30815-30816` with TCP/UDP. If you don't know how to port forward, there are many tutorials online which you can look up for your router or internet provider.

Next, download the latest release and save it somewhere on your computer. This is where the server will drop some of its files including the saved world and config file, so it's recommended to put it in its own folder. Note the .PCK file must remain in the same directory as the executable on Windows and Linux.

Now, in the same folder as the Tinybox executable, run the server from the command line:

**macOS**: In terminal navigate to where the Tinybox app is and type <br>`./Tinybox.app/Contents/MacOS/Tinybox --headless`<br><br>
**Linux**: In terminal navigate to where the Tinybox binary is and type <br>`./Tinybox.x86_64 --headless`<br><br>
**Windows**: In command prompt navigate to where the Tinybox executeable is and type <br>`Tinybox.exe --headless`

The server will use your saved display name, and will run out of your terminal. If you don't have a saved display name your name in chat will simply be 'Server'.

### Adding your dedicated server to the server list

The official server list is located at `.export_exclude/server_list.json` in the repo files, and this is where the client fetches the list from.

If you wish to add your dedicated server to the official server list, make a PR with your server added to the end of the `server_list.json` file, or make a GitHub issue detailing the server's information (name, admins, address). Please note:

- Servers should be moderated/maintained in some form.
- Any server that displays inappropriate, hurtful or abusive messages will be removed.
- The server should have a good name.
    - Please don't use names like "Official Server", "Main Tinybox server", etc. Make it clear that this server isn't hosted by me.
- Make sure you note the admins of the server in the `hosted_by` section.
- Servers that run a modified version of the server code are not allowed, due to incompatibilities with the official client.
- Remember to add a comma after the last server in the list, before you insert yours.

You can add your server via the IP address, but a custom domain (ex. tinybox.yourwebsite.com) is recommended. Your server’s domain or IP will be displayed in the server list. Note that the IP the server is hosted at is still used to connect even if a domain is provided - so it would be shown if, for example, a user pinged it from a terminal - but the IP won't be shown in-game.

### Moderating

The command list can be shown by typing "?" in console.<br>
Typing "$end" will end the server.<br>
Typing "$quit" will exit the app.<br>
You can ban players with "$ban playername". This is an IP ban.<br>
Changes to the map and player bans **are** saved when the server is shut down. However, admin privileges are revoked upon the admin leaving or the server being shut down, due to lack of authentication.
You can unban with "$unban IP". The list of banned IPs is saved in the server config file.

## Temporary host

To host a server temporarily simply click 'Host server' in the Play menu. This way, you will be hosting the server and playing in-game at the same time. Note you will still need to port forward `30815-30816` - the host options section (+) has an option for "Port-forward w/ uPnP". It's recommended you try this first. It will attempt to temporarily forward the port on your router while the server is open. If it works, your friends should be able to connect to your public IP. Once the game is closed, the port forward will be removed.

However, uPnP is understandably disabled by default for a lot of routers, so if it doesn't work, you will need to manually forward the Tinybox port range with TCP/UDP: `30815-30816`.