mDPS Uptime v1.1.8 - Classic Era Melee DPS

INSTALL
Extract the mDPSUptime folder into World of Warcraft\_classic_era_\Interface\AddOns\.
The result must be AddOns\mDPSUptime\mDPSUptime.toc, not a second nested folder.
Restart WoW or reload the UI. Enable the addon on the character selection screen.
If the client marks it out of date, enable Load out of date AddOns.

WARNINGS
NOT AUTO ATTACKING: In combat with a living attackable target, auto attack is off.
TOO FAR AWAY: Your known Hamstring (fallback Rend/Sunder Armor) reports out of range.
FACING THE WRONG WAY: Appears immediately when WoW reports a facing error on an
attempted attack. This warning bypasses the configured activation delay.
NO TARGET: In combat without a selected target. Toggle with /mdps target.
Friendly and dead targets do not produce attack/range warnings.

The display is independent of DBM. Default: size 36, centered 110 UI units above
screen center, 0.6 second delay, sound off. Multiple warnings may show together.
It works in combat anywhere, including raids, and does not start attacks for you.

COMMANDS
/mdps             Open the settings window.
/mdps config      Open the settings window.
/mdps test        Show all three main warnings for 10 seconds, even out of combat.
/mdps unlock      Preview and drag to position.
/mdps lock        Save/lock position.
/mdps size 42     Set font size (16 to 72).
/mdps delay 0.6   Set other warnings' activation delay (0 to 3 seconds).
/mdps sound       Toggle repeating warning sound (at most every 4 seconds).
/mdps target      Toggle the no target reminder.
/mdps on          Enable reminders.
/mdps off         Disable reminders (manual previews still work).
/mdps reset       Restore default settings.
/mdps help        List commands.

LOCATION SETTINGS
The scrollable settings window offers individual Classic Era raid and dungeon
checkboxes, plus outside instances, battlegrounds/arenas, and unlisted instances.
All locations start enabled. All locations / No locations / Raids only buttons
set the location checkboxes in one click. The master enable checkbox still applies.
Changes save immediately and apply to all real combat warnings and sounds.
Test and unlock previews ignore location filters so you can position them anywhere.
Selections are shared across characters, like the existing addon settings.
Some wings share the same instance map ID and are grouped: Scarlet Monastery,
Dire Maul, Blackrock Spire, Maraudon and Stratholme.
UPGRADING FROM NOLT UPTIME
Exit WoW completely. Remove the old NoltUptime addon folder and install the new
mDPSUptime folder. Do not run both versions together.
To keep your settings, copy (do not move) this file before launching WoW:
WTF\Account\YOUR_ACCOUNT\SavedVariables\NoltUptime.lua
to the same directory with the new filename mDPSUptime.lua.
The saved variable inside intentionally remains NoltUptimeDB for compatibility.
If you skip this step, the renamed addon starts with default settings.
The old /nu command is also supported; /mdps is the new primary command.

LIMITATIONS AND IN-GAME CHECK
This first version has not been tested inside WoW. Facing uses the game's error
event, not a continuous direction query. It clears after a melee swing result or
direct damage on the same target, a target change, leaving combat, or 2.5 seconds.
It can briefly linger after turning correctly until an attack confirms it.
Range uses an actual melee dps ability, not a generic distance estimate.
Unknown range produces no warning. Auto attack on does not prove swings landed;
stuns, disarms, immunity, line of sight and encounter mechanics are not tracked.

Test on a low risk enemy: enter combat, stop auto attack; enable auto attack and
step out of melee range; return and attempt an attack while facing away; turn
back and land a swing. Confirm each warning and that leaving combat clears it.
Use /mdps test to check positioning first.


VERSION 1.1.6
Restores the v1.1.3 native OnEvent filter and adds out of range errors.
Removes v1.1.4 AddMessage filtering and v1.1.5 event routing and diagnostics.
Native facing and range text is suppressed in combat with a valid target,
while enabled in the current location. Existing display settings are preserved.

VERSION 1.1.7
/mdps config has separate toggles to hide native facing and range text.
Both default on; uncheck either to restore that native message immediately.
These toggles do not disable the large addon warnings.
Suppression still follows master enable, location, combat, and target conditions.

VERSION 1.1.8
Settings reorganized into General and Locations pages.
Two-column location selection, tooltips, and Preview / Move text / Done controls.
Combat and native error suppression behavior is unchanged.
