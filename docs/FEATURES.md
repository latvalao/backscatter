# Backscatter feature list

Research notes and a build order for turning the current prototype into a full RTS.
The UI overhaul comes last, after these features exist, because most of them need new UI.

## Status

Phases 1 to 8 are built, including the UI overhaul (screenshots: docs/ui_overhaul_*.png). Differences from the list below:

- 2.6 Salvage happens where the wreck lies. The engineer drives to it and works for 20 seconds; there is no towing.
- 3.4 Battlegroups are the light version: one of three per faction, picked in the menu.
- 4.1 Contact classification is done in presentation: a contact is identified when one of our units is within half its sight range, or a recon unit sees it.
- 4.2 The replay viewer skips forward only (+1 and +5 minutes). Going back means restarting the replay.
- 6.4 Operations pick one of three templates from the match seed. The persistent company roster is not built yet.
- 6.5 Saving stores the order history. Loading replays it to the save point, which takes a few seconds per 10 minutes of play.
- 7.2 Radio chatter is a squelch sound on orders and new contacts. There are no voices.
- AI: the commander AI builds helipads, flies attack helicopters and calls off-map support. It does not use transports, mines, flares or smart orders yet.

## What the reference games do

**Wargame: Red Dragon and WARNO (Eugen).** Realistic Cold War combined arms on large maps.
You build a deck of units before the match and call them in during it. Only command units
capture zones, and losing all of them loses the match. Supply trucks repair and rearm.
Units have morale, stress and five veterancy levels. A unit under heavy pressure routs and
ignores orders. There is a line-of-sight tool that shows what a unit can see and hit.
WARNO adds Smart Orders: "seize this", "hold this", automatic counter-battery. A manual order
cancels the Smart Order.

**Broken Arrow (Steel Balalaika).** Modern West vs East. Over 300 units and a deck of seven slot
types (recon, infantry, fighting vehicles, support, logistics, helicopters, airstrikes).
Battlegroups decide which units you can field, and you can change weapons on single units.
Paratroopers and helicopters take ground fast, then tanks and artillery hold it.

**Ebbtide (ProjectAlive, unreleased).** Zombie survival RTS run from a carrier task force off
Los Angeles. One real-time operations map that you zoom into for the actual fighting, with no
separate missions and no auto-resolve. The enemy ambushes convoys, cuts roads and besieges
bases, and you get a warning before an attack so you can reroute or call fire support.

**Flarefall (unreleased).** Co-op horde RTS for 1 to 4 players on the Florida coast.
You build by day and defend at night. Players share one base and its supplies but each
commands their own units, and can hand units to a teammate. Infantry, armour, boats,
helicopters, airstrikes and a destroyer's guns. Veteran units and researched upgrades carry
over between operations.

## What Backscatter already has

Movement and pathfinding, armour and penetration combat, suppression and pinning, fog of war
with last-known ghosts, smoke, fire missions, base building, supply trucks and depots, fuel,
radiation and dose, weather, emissions control and direction finding, drones, jamming,
the commander AI, marauders, lockstep multiplayer, replays, and the new models and lighting.

Missing from that list, compared with the reference games: transports that work, helicopters,
veterancy, routing, garrisons, mines, a minimap, alerts, a line-of-sight tool, saving and
loading, every mode except skirmish and sandbox, sound, and settings.

## Build order

Each phase builds on the one before it. "Seen in" names where the idea comes from.
Items marked *ours* are ideas no reference game has that fit Backscatter's setting.

### Phase 1. Command basics

The things players expect from any RTS of this type. Without them, nothing that comes later
feels right.

| # | Feature | What it does | Seen in |
|---|---|---|---|
| 1.1 | Transports | Infantry mount IFVs and trucks, unload where ordered, and the transport can drive off to a new spot. Passengers die if the vehicle is destroyed. | Wargame, Broken Arrow |
| 1.2 | Facing on move | Drag the right mouse button to set the final facing. Tanks arrive front armour first. | Wargame, WARNO |
| 1.3 | Formations | Line, column and wedge for group moves. The group keeps the slowest unit's speed. | Most RTS |
| 1.4 | Engagement range | Units hold fire until targets come within a set distance, so ATGM teams don't reveal themselves at long range. | Wargame |
| 1.5 | Line-of-sight tool | Hold a key over the map to see what a selected unit could see and hit from the cursor point. | Wargame, WARNO |
| 1.6 | Selection helpers | Double-click selects every unit of that type on screen. Tab cycles through types in a selection. Plus an idle-unit key and camera bookmarks. | Most RTS |
| 1.7 | Alerts | "Under attack", "convoy ambushed", "unit out of fuel", "crew dose critical". Space jumps the camera to the last alert. | Ebbtide, most RTS |
| 1.8 | Minimap | Terrain, friendly units, known enemies, alerts and the radiation overlay. Later it becomes part of the staff map. | Most RTS |

### Phase 2. Combat depth

| # | Feature | What it does | Seen in |
|---|---|---|---|
| 2.1 | Veterancy | Trained, Veteran and Elite, earned from kills, spotting and surviving. Better aim, reload speed and morale. Already in the design doc (§5.7). | Wargame, design doc |
| 2.2 | Routing | A unit whose morale breaks runs for cover and ignores orders for a while, instead of only being pinned. | Wargame |
| 2.3 | Crew bail-out and recovery | Crews leave a disabled vehicle as a small infantry team. Bring them back to save manpower, or put them in an empty vehicle. Design doc §5.7. | Design doc |
| 2.4 | Garrisons | Infantry enter village houses and the depot warehouse for cover. Artillery can collapse the building. | Men of War, Wargame |
| 2.5 | Mines | Engineers lay and clear minefields. Mines are hidden from the enemy until something hits one or recon finds them. | Most realistic RTS |
| 2.6 | Salvage | The engineer vehicle tows wrecks back to the base for supply. This gives the persistent wrecks a gameplay use. | *ours* |
| 2.7 | Illumination flares | Mortars and artillery fire flares at night that light an area for spotting. Already planned in the visuals doc. | Visuals doc |

### Phase 3. Air and support

| # | Feature | What it does | Seen in |
|---|---|---|---|
| 3.1 | Helicopters | One transport and one attack helicopter per faction. They fly low, hide behind trees and hills, and are fragile to anti-air. | Wargame, Broken Arrow, Flarefall |
| 3.2 | Off-map support | Airstrikes, a paradrop and a heavy artillery battalion, bought with supply and limited per match. | Wargame, Broken Arrow, Flarefall |
| 3.3 | Support calls use the radio | Calling off-map support makes a radio transmission, so enemy direction finding can locate the caller. Jamming delays the call. | *ours* |
| 3.4 | Battlegroups | Before a match, pick one of three battlegroups per faction (for example armoured, mechanised or recon). It sets which units can be built and which support you can call. This is a light version of a deck. | Broken Arrow, Wargame |

### Phase 4. Intel

| # | Feature | What it does | Seen in |
|---|---|---|---|
| 4.1 | Contact classification | A far-off or thermal-only contact shows as "tracked vehicle" or "infantry", and becomes "MBT-72" only when spotted clearly. Direction-finding fixes show as "emitter". | Wargame (partly), *ours* |
| 4.2 | Replay viewer | Timeline scrubbing, player views, full reveal and a free camera. | Most RTS |
| 4.3 | Match summary | Losses, kills, supply over time, dose taken and an end-of-match map of the battle. | Most RTS |

### Phase 5. Smart orders

| # | Feature | What it does | Seen in |
|---|---|---|---|
| 5.1 | Seize and hold | Give a group a point. It scouts ahead, takes the point and digs in, using the same task-force logic the AI already has. | WARNO |
| 5.2 | Overwatch | The unit stays still and covers a sector. It fires only at targets inside it. | WARNO, Men of War |
| 5.3 | Auto counter-battery | Your guns fire back automatically when the radar or a direction-finding fix gives a position. | WARNO |
| 5.4 | Rotate crews | Units over a dose limit drive back to the decontamination point and come back when clean. | *ours* |

### Phase 6. Modes and content

These are M8 in the design doc.

| # | Feature | What it does | Seen in |
|---|---|---|---|
| 6.1 | Zone War | Versus with victory points from depots, a timer and optional marauders. | Design doc |
| 6.2 | Containment | Co-op defence at the plant against rising assaults while fallout worsens. This is the same appeal as Flarefall's night defence. | Design doc, Flarefall |
| 6.3 | Co-op sharing | Players share a base and its supply, command their own units, and can give units to a teammate. | Flarefall |
| 6.4 | Operations | Procedural co-op missions with a company roster that carries crews, dose and veterancy between missions. | Design doc, Flarefall |
| 6.5 | Saving and loading | Needed for the campaign and long operations. | All single-player RTS |
| 6.6 | Campaign Act I | The first 3 to 5 missions, with a short tutorial built into mission 1. | Design doc |
| 6.7 | Three skirmish maps | Hand-shaped maps: the border corridor, the Red Forest and the plant. | Design doc |

### Phase 7. Sound and settings

| # | Feature | What it does |
|---|---|---|
| 7.1 | Weapon and vehicle sound | Engine noise, tracks, gunfire and impacts with distance falloff. |
| 7.2 | Radio chatter | Short acknowledgement and contact calls with squelch. Silent units say nothing. |
| 7.3 | Settings | Graphics, audio, key rebinding, colour-blind team colours and options to turn effects off. |

### Phase 8. UI overhaul

Unit card with armour diagram and crew dose, the command panel, the staff map, the dosimetry
and signal overlays, and the menus. This goes last so it can cover everything above.

## Left out on purpose

- Ranked ladder and matchmaking. The design doc rules them out.
- Joining a match in progress. Lockstep networking makes this hard, and friend lobbies rarely need it.
- Per-unit weapon customisation like Broken Arrow's. It adds a large menu for a small gain.
- Research trees during a match. Battlegroups and veterancy cover the same ground.
- Naval units. There is no sea in the setting. Lakes stay obstacles.

## Questions before we start

1. Battlegroups (3.4). Light version as written, or a full Wargame-style deck?
2. Helicopters (3.1). In v1, or after the modes?
3. Salvage (2.6) and supply calls over the radio (3.3). Keep both?
4. Phase 6 order. Containment first, since it is the easiest co-op mode to test with friends?

## Sources

- [Wargame: Red Dragon manual](https://cdn.cloudflare.steamstatic.com/steam/apps/251060/manuals/WARGAME_RED-DRAGON_manuel_INT-digital.pdf?t=1597837643)
- [Wargame: Red Dragon, Wikipedia](https://en.wikipedia.org/wiki/Wargame:_Red_Dragon)
- [Beginner's guide to Wargame](https://www.matchstickeyes.com/2014/08/24/the-beginners-guide-to-wargame/)
- [WARNO beginner guide (Steam community)](https://steamcommunity.com/sharedfiles/filedetails/?id=2727549821)
- [WARNO vs Wargame differences (Steam discussion)](https://steamcommunity.com/app/1611600/discussions/0/4327474822613587240/)
- [What makes Broken Arrow unique (Slitherine)](https://www6.slitherine.com/news/what-makes-broken-arrow-unique)
- [Broken Arrow deck builder guide (Sportskeeda)](https://www.sportskeeda.com/esports/broken-arrow-complete-deck-builder-guide)
- [Ebbtide on Steam](https://store.steampowered.com/app/4915700/Ebbtide/)
- [Ebbtide preview (NoobFeed)](https://www.noobfeed.com/news/ebbtide-zombie-strategy-military-operations)
- [Flarefall on Steam](https://store.steampowered.com/app/5518060/Flarefall/)
- [Flarefall announcement (X)](https://x.com/flarefallgame/status/2117532312812331502)
