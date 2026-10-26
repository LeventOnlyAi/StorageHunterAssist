# StorageHunterAssist — English guide

A Turkish in-game panel for **Storage Hunter Simulator**: select owned items in a nearby truck or on the ground, sell them remotely at a chosen pawn shop, or send them to a selected owned shop's warehouse. Optional automatic warehouse delivery and configurable time skipping are included.

## Requirements

- Windows version of the game; this guide uses a Steam installation.
- Single player / host. Multiplayer clients are not supported.
- Tested game build: **22160137**. New Steam builds require separate verification.
- Tested UE4SS: **v3.0.1-1181-g83330635**, available from the [official archive](https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/UE4SS_v3.0.1-1181-g83330635.zip).
- The mod release ZIP. ModMenu v1.4.0 is bundled; no other gameplay mod is required.

## Installation

1. Save and close the game. Back up `%LOCALAPPDATA%\StorageHunter\Saved\SaveGames`.
2. In Steam, right-click the game → **Manage → Browse local files**. Open `StorageHunter\Binaries\Win64`. Confirm `StorageHunter-Win64-Shipping.exe` is there.
3. Extract the official UE4SS ZIP into that `Win64` folder. `dwmapi.dll` must sit beside the shipping EXE, with the `ue4ss` folder next to it. Preserve existing mods and loader configuration if UE4SS is already installed.
4. Download `StorageHunterAssist_0.2.0.zip` from this repository's [Releases](https://github.com/LeventOnlyAi/StorageHunterAssist/releases). Copy its `StorageHunterAssist` folder into `Win64\ue4ss\Mods`.
5. Confirm the resulting path is `Win64\ue4ss\Mods\StorageHunterAssist\Scripts\main.lua`.
6. Add `StorageHunterAssist : 1` to `ue4ss\Mods\mods.txt`, preserving other entries. Leave the built-in `Keybinds : 1` entry last if present.
7. If `mods.json` exists in the same directory, also add / enable `{ "mod_name": "StorageHunterAssist", "mod_enabled": true }` in its existing JSON array. Preserve other entries and valid commas. Do not replace the whole file with this object.
8. Launch through Steam, load a save and press **F8**.

The green GitHub **Code → Download ZIP** option downloads the source tree. Use the release ZIP for installation; if using the source tree, install only `mod/StorageHunterAssist`.

## Controls and panel labels

| Control | Meaning |
| --- | --- |
| F8 | Open / close the panel. |
| F6 | Advance time by the selected number of minutes. |
| F7 | Cycle 15 / 30 / 60 / 120 / 240 minutes. |
| F5 | Show key help. |
| Kaynak | Source: truck + nearby, truck only, or nearby only. |
| İşlem | Operation: warehouse delivery or direct quick sale. |
| Hedef mağaza / bölge | Destination shop / region. |
| Listeyi yenile | Refresh the item list. |
| Tümünü seç | Select all listed items. |
| Seçilenleri DEPOYA GÖNDER | Send selected items to the chosen owned warehouse. |
| Seçilenleri SAT | Immediately sell selected items at the chosen pawn shop. |
| Otomatik depo | Automatically deliver all eligible items from the selected source. |
| Zaman | Time tab. |

Nearby loose items use a 15 m radius; truck cargo uses a 50 m truck range. Only owned eligible goods are listed. Put down held items first. Unsold auction goods, shop display items, goods already warehoused and children inside containers are not processed separately. One item appearing in both source lists is counted once.

Sale targets are the five pawn shops: Blueberry, East, West, Zwiebel Farm and Lake Town (localized in Turkish as Çayüzümü, Doğu, Batı, Zwiebel Çiftliği and Naple). Collectors and experts are not targets. The mod invokes the game's native quick-sale operation; other installed sale mods can influence prices and payouts.

Automatic warehouse delivery is **off at startup**. When enabled, it processes **all eligible source items**, ignoring individual selection checkboxes, and continues while the panel is closed. Changing source, operation or destination turns it off. A full / rejected warehouse transaction stops automatic delivery. There is no automatic selling.

Time skipping stops before the day-end boundary; use the game's normal sleeping flow to start the next day.

## Configuration and removal

With the game closed, edit `Scripts/sh_assist_config.lua` inside the installed mod. Distances are in centimetres, time steps in whole minutes, and polling in milliseconds. Restart the game after editing. See the [Turkish README](../README.md) for examples.

To disable the mod, set its `mods.txt` value to `0` and, if present, its `mods.json` flag to `false`, then restart. To remove it, close the game, remove only the `StorageHunterAssist` folder and its loader entries. Keep UE4SS if other mods use it. Removing the mod does not undo previous transactions or time changes.

Check `Win64\ue4ss\UE4SS.log` for `[StorageHunterAssist] v0.2.0 loaded`. For issues, include the game build, UE4SS version, action and relevant error lines. You do not need to publish save files or an entire private log.

Original mod code: MIT. Bundled ModMenu: MIT, copyright Matthew arvidson. See [third-party notices](../THIRD_PARTY_NOTICES.md) and [verification scope](TESTING.md).
