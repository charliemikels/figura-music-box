
# Figura Music Box

This project is a Figura avatar. You'll need to download the [Figura](https://modrinth.com/mod/figura) mod for Minecraft to use it. 



This avatar was primaraly built to test some non-standard usecases for my [Figura Music Player](https://github.com/charliemikels/figura-music-player) system. 

This is a player head avatar. To use it, you'll need to get and place your player head in the world. Typically you'll need to use commands, datapacks, or mods to do this. Once you have your player head, place it in the world. Punching the avatar should open the lid and play music. Punch again to close the lid. If this doesn't work, make sure you've set yourself to MAX permissions. This should be the default, but it's probably good to check.

This player head also works in multiplayer, and it works when the avatar's owner is disconected. (That said, there are no checks to keep the state of the music boxes in sync between clients.) It's limited to only work in Maximum permissions. You may need to instruct your viewers to go into Figura Settings → Permissions → Show Disconected Avatars → Music Box (or your username) → MAX. 

In theory, this avatar might work on HIGH, but I haven't bothered to really optimize the WORLD_TICK/_RENDER, so I'm just saying MAX to make it just simple for this test.

The contents of the music_player folder should be the same as in [Figura Music Player](https://github.com/charliemikels/figura-music-player), with these exceptions:

- Several files were removed since this script does not use them. Includeing `ui.lua`, `networking.lua`, 
- There is a new custom Music Instrument: a Music Box

## Use of Figura Music Player

Most of the `main.lua` script is just there to manage the discovery and state of the player heads. The relevant Music Player stuff lives at the bottom of the fake init function. 

- Get an empty library, and get the local songs. 
  - Local songs will process its list of songs useing a world event if the avatar is set to max perms. 
- Grab a song holder for the song we want
  - get the data processor and add a callback function
    - Check for errors
    - Set up song config stuff (and force all instruments to use the Music Box)
    - Create a new controller
    - Define a stop function that we use to loop the song when it ends
    - check if we need to play the song now
    - Update some animations 
- Whenever we play the song, we also add the stop callback
- Whenever we want to stop the song, we remove the callback before calling start (otherwise it would loop)
