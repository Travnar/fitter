# Changelog

## [2.11.0] - 2026-10-22

### Added
- Send Preview, in the right-click menu of mount and pet cards. It puts a Custom Fit link in the chat box; another Fitter user clicks it to see their own character in your current transmog, riding the mount or beside the pet. The window lists each appearance like the Dressing Room, and Open in Dressing Room loads the outfit there to save as a custom set.
- Searchable Title Selection option, under Titles. It replaces the title dropdown in the outfit window with a search box that lists every known title and filters as you type.

## [2.10.0] - 2026-10-22

### Added
- Share an outfit's Fitter configuration in chat. Share puts a link in the chat box; another Fitter user clicks it, picks one of their outfits, and the configuration is applied there. Anything that character has not collected is skipped.
- Character export and import, under the Loadouts page. Generate Character Export String shows this character's whole Fitter configuration as text to copy; Import Character Export String pastes it onto another character. Generate Character Export Macros stores the same text in FITTER_CONFIG_N account macros, so another character can import it without copy and paste. An import overwrites that character's Fitter configuration.

### Fixed
- One-button fishing did not reel in on World of Warcraft Forever. Forever's Fishing ranks are now recognized, and soft-target interact settings are only changed where the client has them.

## [2.9.0] - 2026-10-21

### Added
- Holidays as outfit conditions: Lunar Festival, Love is in the Air, Noblegarden, Children's Week, Midsummer Fire Festival, Brewfest, Hallow's End, Day of the Dead, Pilgrim's Bounty, Feast of Winter Veil, Darkmoon Faire and the WoW Anniversary. The outfit is used while the holiday is on.
- Activities as outfit conditions, starting with Fishing. Create Activity Macro makes an "Outfit Fishing" macro that switches to a Fishing outfit and then casts Fishing; its tooltip lists the outfits it switches to.
- A Cast Fishing key binding.
- One-button fishing: while fishing, the Cast Fishing binding and the Outfit Fishing macro's action bar key interact with the bobber, so the same key reels it in.

### Changed
- The Zones slot is now Conditions, covering zones, holidays and activities.

## [2.8.1] - 2026-10-20

### Fixed
- With a locked outfit, the mount macro's tooltip and the next mount came from the zone's outfit instead of the locked one.

## [2.8.0] - 2026-10-19

### Added
- Mycomancer's Hearthspore in the hearthstone list.

### Changed
- Racial hearthstones are hidden from other races instead of showing as unusable.

### Fixed
- Some hearthstone previews played the wrong animation or effect.

## [2.7.1] - 2026-10-19

### Fixed
- Home teleport conditions for hearthstones were missing until the Housing Dashboard had been opened. Fitter now asks for the house list once at login.

## [2.7.0] - 2026-10-17

### Added
- Edit Fitter outfits without visiting a transmogrifier. The outfit window opens without gear slots to change Fitter's settings only, from the Open Outfit Window key binding, the "Outfit Window" macro, or the addon compartment.
- A Macros section in the options lists every Fitter macro with a Create button, and each macro can be dragged straight to an action bar.

### Changed
- Fitter's macros are renamed "Outfit Mount", "Outfit Hearth" and "Outfit Update". Existing macros are renamed in place, so action bar placement and your own edits carry over.

## [2.6.0] - 2026-10-16

### Added
- Toy previews: right-click a toy to preview it on the character, and Clear Preview to go back.
- View Without Transmog on World of Warcraft Forever: a toggle under Sheathe Weapon that shows the equipped items' own appearances, as players with transmog display turned off see them.
- More toys and hearthstones in the lists.

### Fixed
- Hearthstone preview animations and effects.
- Several pages were out of line with each other.

## [2.5.2] - 2026-10-15

### Changed
- The selected border on mount, pet and hunter pet cards matches the default UI's.

## [2.5.1] - 2026-10-14

### Changed
- Supports game version 12.1.5.

## [2.5.0] - 2026-10-14

### Added
- Hearthstone previews: the character casts the selected hearthstone in the outfit window, including hearthstones that transform the character or equip an item for the cast. The outfit comes back afterwards.
- More hearthstones in the list.

## [2.4.3] - 2026-10-14

### Fixed
- Toys, emotes and the hearthstone macro used item functions the game no longer provides, which broke them. They use the current ones now.

## [2.4.2] - 2026-10-14

### Changed
- Rolled back 2.4.1, which shipped with development files in the package. Its toy fix returns in 2.4.3.

## [2.4.1] - 2026-10-14

### Fixed
- Toys used item functions the game no longer provides.

### Changed
- The conditional entry field is labeled "Name / ID".

## [2.4.0] - 2026-10-01

### Added
- Conditionals: use an ability, toy or mount instead of the normal mount while a condition is met: holding Shift, Ctrl or Alt, falling, in combat, indoors or swimming. Add character conditionals from the Fitter tab, or account-wide ones in the options. A character's conditional takes priority over an account-wide one for the same condition, and abilities or toys the character doesn't have are skipped. The field suggests matches as you type.
- Use Monk Macro: casts Zen Flight, or summons a mount.
- Copy Target Player's Mount: summon the mount your target is riding when you own it and can use it here.

### Changed
- The Shift, Ctrl and Alt mount dropdowns become conditionals; existing choices are converted.
- Class macros use the client's localized spell names, so they work in every language.

## [2.3.0] - 2026-09-30

### Added
- Support for World of Warcraft Forever. Flying and aquatic mounts are hidden where the client has none, and Ground and Pet move up into their place.

## [2.2.7] - 2026-09-29

### Fixed
- A Lua error when buffs changed in combat.

## [2.2.6] - 2026-09-29

### Fixed
- The Gilded Brutosaur mount condition did not work after the mount was renamed. Renamed choices carry over, and choices that no longer match an option are reset.

## [2.2.5] - 2026-09-21

### Fixed
- In places where you cannot mount, such as indoors or in combat, the mount pages hid most mounts. All selectable mounts show now; usability is only checked when summoning.
- The window could be dragged by its character model.

## [2.2.4] - 2026-09-08

### Added
- Darkmoon Faire in the zone list.

## [2.2.3] - 2026-09-08

### Fixed
- Opening the Housing Dashboard could leave its house list empty.

## [2.2.2] - 2026-09-08

### Fixed
- A hearthstone toy was referenced incorrectly.

## [2.2.1] - 2026-09-03

### Added
- Simplified Chinese (zhCN) translation.

## [2.2.0] - 2026-09-03

### Added
- Housing portals as Shift, Ctrl or Alt hearthstone conditions, for the hearthstone macro and key binding.
- Russian (ruRU) translation.

## [2.1.1] - 2026-08-23

### Added
- Translation support, with Spanish (esMX) as the first translation.

### Changed
- Zone groups are named by continent, such as Khaz Algar and Kul Tiras.

## [2.1.0] - 2026-08-21

### Added
- Add Toy By ID: add any toy missing from the toy list by its item ID. Added toys get their own filter, and right-click removes one.

## [2.0.2] - 2026-08-15

### Fixed
- Just after leaving water, the macro could still pick an aquatic mount. It waits a few seconds before switching back.

## [2.0.1] - 2026-08-13

### Changed
- A mount category left unconfigured uses its account-wide list, then the next category for the area: flying, then ground where you can fly, and ground first where you can't. Disable skips the category entirely.
- All-terrain and skyriding aquatic mounts count as aquatic mounts.

## [2.0.0] - 2026-08-10

### Added
- Loadouts: save an outfit's complete Fitter setup as a character or account-wide loadout, and apply it to other outfits. Loadouts include mounts, pets, hunter pets, zones, toys, hearthstones and emotes.
- Emotes per outfit: built-in or custom emotes that play on conditions such as mounting, dismounting, entering or leaving combat or a rest area, eating, drinking, using a hearthstone, equipping the outfit, or targeting a player or NPC. A Global Cooldown option controls how often they play.
- Hunter pets for Hunters: an outfit can call a specific pet, choose among several, use a random pet, leave pets alone, or dismiss them. Revive Pet tries to revive a dead pet first.
- Favorites for mounts, pets, hunter pets, hearthstones, toys, zones and emotes, sorted first in every list.
- Astral Recall Fallback: Shamans use Astral Recall when the hearthstone is on cooldown.
- Use Zone Specific Mounts: summons the G-99 Breakneck in Undermine.
- Reset Default Hearthstones, for outfits that only had the default Hearthstone picked for them automatically.
- Reset Outfit Configuration and Reset Character Configuration. Loadouts and custom emotes are kept.
- Model previews for mounts, pets, hearthstones, hunter pets and animated emotes. A selected mount shows with the character riding it in the current transmog.
- A filter to show uncollected mounts, pets and hearthstones, plus more filters on every page.
- Right-click options on every page, such as favoriting, previewing, or turning off the zone for other outfits.
- A warning when an outfit with zones does not have the matching situation turned on, since the game would use another outfit there.

### Changed
- Hearthstones, toys and zones use paged button views.
- An outfit can have several zones and several hearthstones. With several hearthstones, one is picked at random.
- With no hearthstone selected, a random hearthstone is used instead of the default Hearthstone item.
- Cancel Non-Outfit Toys is now Cancel Non-Outfit Cosmetic Toys.

## [1.11.2] - 2026-08-02

### Added
- More hearthstones in the list.

### Fixed
- Fitter's hook on the transmog tabs could taint other Blizzard UI, including the damage meter, in combat.

## [1.11.1] - 2026-07-23

### Fixed
- All-terrain mounts were left out of the flying, ground and aquatic lists.

## [1.11.0] - 2026-07-20

### Added
- Shift, Ctrl and Alt hearthstone conditions: pick a teleport toy for each modifier, used by the hearthstone macro and key binding.

## [1.10.0] - 2026-07-18

### Added
- Summon triggers per pet: choose which events summon each pet: outfit change, entering the world, mounting, dismounting, zone change or leaving stealth.
- Right-click a mount card for the game's mount menu.
- The mount slot tooltip lists every selected mount.

### Changed
- With no hearthstone selected, the hearthstone macro uses the Hearthstone item when it is in your bags, and otherwise one of your hearthstone toys at random.
- The hearthstone macro updates when your bags change.

## [1.9.0] - 2026-07-18

### Added
- Shift, Ctrl and Alt mount conditions, replacing Ground Mount Modifier: each modifier can summon your ground mount or a utility mount (Grand Expedition Yak, Mighty Caravan Brutosaur, Gilded Brutosaur, Grizzly Hills Packmaster or Traveler's Tundra Mammoth). An existing Ground Mount Modifier setting is converted.
- Dismiss Pet In Instances While Grouped.

### Fixed
- Pets were not resummoned after a loading screen.

## [1.8.1] - 2026-07-04

### Fixed
- Pets were not dismissed when switching to an outfit without pets.

## [1.8.0] - 2026-07-04

### Added
- Hide Duplicate Names, a pet filter that is on by default. Selected pets always show.

## [1.7.1] - 2026-07-02

### Fixed
- Changing an active outfit's mounts did not always update the mount macro right away.

## [1.7.0] - 2026-07-02

### Added
- Dismiss Pet On Stealth. The pet is summoned again when you leave stealth.

## [1.6.2] - 2026-07-02

### Fixed
- Logging in on another character could carry the previous character's macro text over.
- Toy lines that Fitter had put in the mount or update macro were sometimes kept as if you had added them.

## [1.6.1] - 2026-06-16

### Changed
- Supports game version 12.0.7.

## [1.6.0] - 2026-06-14

### Added
- The Outfit Update macro and Update Outfit key binding: applies the zone outfit's title, pet and toys without summoning a mount. Create it as an account or character macro from the options.
- Apply Toy On Select: selecting or deselecting a toy on the active outfit uses or cancels it right away.

## [1.5.2] - 2026-05-29

### Added
- Titles can be set to No Title, which clears the title, or Ignore Title, which leaves it unchanged. Ignore Title is the default.

## [1.5.1] - 2026-05-29

### Fixed
- The outfit's pet is summoned when mounting too.
- The current pet is no longer resummoned when it is already the one picked.

## [1.5.0] - 2026-05-29

### Changed
- Auto Disable Zone Situations only turns off situations that Fitter turned on, and requires Auto Enable Zone Situations.
- Options rows show their tooltip anywhere on the row.

## [1.4.1] - 2026-05-27

### Changed
- The options page layout is cleaner, with checkboxes lined up on the right.

## [1.4.0] - 2026-05-26

### Added
- Key bindings for Summon Mount and Use Hearthstone. A binding has room for more toy lines than the macro.
- Toys per outfit, used by the mount action. Cancel Non-Outfit Toys cancels the previous outfit's toys.
- Account-wide flying and ground mounts, used by outfits with no mount selection of their own.
- Show Tooltip in Mount Macro and Show Tooltip in Hearthstone Macro.
- Reset Character Data.

### Changed
- Multiple mounts and pets can always be selected; the Multiple Mounts and Multiple Pets options are gone.
- Your edits to Fitter's macros are kept by default. Remove Macro Changes On Update replaces Preserve Macro Changes.
- A new options page with sections for each feature.

## [1.3.1] - 2026-05-06

### Changed
- Clearer names and tooltips for the zone situation options.

## [1.3.0] - 2026-05-06

### Added
- Preserve Macro Changes: keeps text you add to the mount or hearthstone macro.
- Use Shaman Macro: casts Ghost Wolf, or summons a mount.
- Auto Enable Zone Situations and Auto Disable Zone Situations: turn the outfit's Rest Area or World situation on and off as cities and other zones are added and removed.

### Fixed
- A mount picked for a flyable area could be summoned after moving somewhere you can't fly.

## [1.2.0] - 2026-05-02

No changes.

## [1.1.1] - 2026-05-02

### Added
- Multiple Pets: select several pets per outfit, with one summoned at random.
- Pet family and Selected filters on the pet page.

## [1.1.0] - 2026-05-02

### Added
- Ground Mount Modifier: hold Shift, Ctrl or Alt to summon your ground mount, including Running Wild.

### Fixed
- Skyriding aquatic mounts were listed as aquatic instead of flying.

## [1.0.2] - 2026-05-02

### Added
- Flying, ground and aquatic mounts per outfit, with random, ignore and Soar or Running Wild choices, summoned by the FitterMount macro.
- A companion pet per outfit, or a random favorite.
- A title per outfit.
- A hearthstone per outfit, used by the FitterHearthstone macro.
- Zone-based outfit switching, with zones grouped by expansion and biome.
- Use Druid Macro and Multiple Mounts options, and the /fit (/fitter) command.
