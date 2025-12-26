# How to get the Compiled BSPs
All finished compiled bsps should be located there.<br>
URL: https://slashco-maps.raphaelit7.com/<br>

# How to mount content
In your garrysmod folder, find the `cfg/mount.cfg` and inside it add the following entry:<br>
`"slashco_content" "C:\[FullPath To the cloned repository]\SlashCo-Content\maps\_content\_content_pack"`<br>

# Map tools
To properly test maps, you can setup the game arguments in hammer properly:<br>
`-dev -console -allowdebug -game $gamedir +gamemode slashco +maxplayers 2 +slashco_enablemaptools 1 +map $file`<br>
`+maxplayers 2` is added as slashco needs at minimum two player slots to properly work<br>
`+gamemode slashco` is added to load the gamemode instead of sandbox when starting the game<br>
`+slashco_enablemaptools 1` is added to enable newly added mapping tools and to notify the gamemode that Hammer is running in the background.<br>
These all should be added **before** `+map` due to the engine executing commands in order.<br>

# File structure:
\_content: -- contains content related stuff<br>
\- \_content\_pack -- contains all map files<br>

Map Name: -- required to match vmf file name.<br>
\- Map.vmf<br>