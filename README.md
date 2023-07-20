# Destiny Loadout Switcher

This macro tool allows you to switch loadouts in Destiny 2 with the press of a button by automating the keyboard/mouse actions that 
are needed to select and switch to a given loadout (pc only). It thus works around the absence of shortcuts for loadouts by the game itself.
It makes switching loadouts during the game more consistent, but not necessarily faster as that depends mainly on the system's performance.

There is no direct interaction with the game. It works purely using screen capture and keyboard/mouse input.
It neither bypasses any game mechanics nor gives you an advantage over other players.
However, as with any automation tools, use at your own discration and risk!

## Usage example

Suppose you have prepared four loadouts for a dungeon or raid encounter:

1. Loadout nr 1 for the mechanics/add clear phase
2. Loadout nr 2 for the DPS phase with a super-enhancing exotic, surge and loader mods
3. Loadout nr 3 for rallying/heavy brick pickup by means of reserve and scavenger mods
4. Loadout nr 4 with Aeons, to be used for finishers on yellow bars

Also suppose that you want to use the following function keys:

F5: Activate loadout nr 1
F8: Activate loadout nr 2
F9: Toggle between loadout nr 3 and the previous loadout
F12: Toggle between loadout nr 4 and the previous loadout

To accomplish this with Destiny Loadout Switcher, you first need to create a loadout set file, e.g.
_Dungeon.lds_, and save it in the application's folder. It looks like this:

    116: 1
	119: 2
	120: 3, 0
	123: 4, 0

Each line consists of virtual key code followed by a comma separated list of loadout numbers. The
key code of F5 is 116 and thus the first line specifies that the F5 key should be mapped to activating
loadout nr 1, thus activating the add clear loadout.

If multiple loadout nrs are specified for a key, then the program will cycle through these, allowing you
to toggle between loadouts.
Loadout nr 0 has a special meaning: it swaps to the loadout that was activated just before the current one.
For example, the last line specifies that if you press F12 (virtual key code 123), loadout 4 will be
activated, thus you switch to Aeons. If you then press F12 again, it activates loadout 0, which activates
the loadout that you used before you switched to Aeons.

You can then start the program, which is a windows tray application. It loads the .lds files from the
application folder and makes these selectable in the tray's context menu. Selecting the loadout set then
activates the configuration. You can then use the configured keys from within the game.

## Pitfalls

* Currently the supported resolutions are: 1280x720, 1920x1080, 2560x1440 and 3840x2160. Other resolutions
  can be supported by adding the relative locations of some GUI elements for that resolution to the internal
  configuration of the tool.
* The mouse cursor needs to be inside the application window when you press a hotkey. This is trivially true
  when running the game in full screen.
* The configured keys only take effect if the title of the foreground window starts with _Destiny 2_.
* If the tool does not understand the relevant parts of the screen or it takes too long to open the character,
  the tool will time out, issue an error signal and stop processing the activation. You can then continue
  manually. This should not happen.
* The tool may stop working if the positioning of some GUI elements is changed in future versions of the
  game. Actually, I hope that the developers of the game add hotkeys to layouts so that this tool becomes
  obsolete.

## Application

You can implement the aforementioned functionality with a tool like AutoHotkey. However, AutoHotkey has some
issues with DPI scaling (at least in version 1) and this functionality would resolve heavily around using the
Windows API, hence this tool was developed as a standalone executable.

You can download a release containing a compiled executable and some example files. Unpack these to a folder
of your choosing and you are good to go.
You can run the executable with a separate windows' user with limited permissions, as the application does
not write files nor perform any network I/O.

Alternatively, you can compile the sources yourself. It is a Delphi 11 project, which you can build with
the community edition of the IDE.

## How it works

The tool goes through the following steps:

It first checks whether the toplevel window has the title of the game, to make sure that we are inside
the game. It can then obtain the window's coordinates so that it knows where to look in captures of the
screen.

It then opens the character screen by issuing the F1 key. This takes the bulk of the time. There is not much
that can be done during this time, as the game does not react to any input during this time, and opening
the loadout panel only works when the character screen is rendered. After a short delay, we move the mouse
cursor to the very left, to make sure that the loadout panel does not move.

We know that the character screen is available if a grayish box is rendered below the character tab in the
menu bar. So once we see this box, we issue the left key to open the loadout panel. We know that the loadout
panel is rendered when it's gray vertical line is there. However, the game does not allow us to click on the
boxes yet. Instead, we have to make sure that the loadout popup is rendered, by juggling the cursor over the
loadout box. The loadout popup will then obscure the vertical line of the loadout panel. Then we can click
the box.

Finally, the tool issues the F1 key again to close the character screen.
