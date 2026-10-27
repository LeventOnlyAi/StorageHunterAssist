# StorageHunterAssist — English guide

A Turkish in-game panel for **Storage Hunter Simulator**: select owned items in a nearby truck or on the ground, sell them remotely at a chosen pawn shop, or send them to a selected owned shop's warehouse. Quality routing, separate collectible selection, live list refresh, optional automation and configurable time skipping are included.

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
4. Download `StorageHunterAssist_0.3.0.zip` from this repository's [Releases](https://github.com/LeventOnlyAi/StorageHunterAssist/releases). Copy its `StorageHunterAssist` folder into `Win64\ue4ss\Mods`.
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
| İşlem | Operation: quality routing, warehouse delivery or direct quick sale. |
| Depo mağazam | Owned warehouse; in direct sale mode, sale region. |
| Kaliteye göre ayırma: satış bölgesi | Independent sale region for quality routing. |
| Eşyalar | Item selection grouped by rarity, with collectibles below. |
| Kurallar | Checked rarities sell; unchecked rarities go to the selected warehouse. |
| Listeyi yenile | Refresh the item list. |
| Tümünü seç | Select all listed items. |
| Seçilenleri DEPOYA GÖNDER | Send selected items to the chosen owned warehouse. |
| Seçilenleri SAT | Immediately sell selected items at the chosen pawn shop. |
| Otomatik | Apply the selected route to all eligible source goods, ignoring item selections. |
| Zaman | Time tab. |

Nearby loose items use a 15 m radius; truck cargo uses a 50 m truck range. Only owned eligible goods are listed. Put down held items first. Unsold auction goods, shop display items, goods already warehoused and children inside containers are not processed separately. One item appearing in both source lists is counted once.

Sale targets are the five pawn shops: Blueberry, East, West, Zwiebel Farm and Lake Town (localized in Turkish as Çayüzümü, Doğu, Batı, Zwiebel Çiftliği and Naple). Collectors and experts are not targets. The mod invokes the game's native quick-sale operation; other installed sale mods can influence prices and payouts.

Quality routing is the default mode: **Common sells; Rare, Epic, Legendary and Unique go to the chosen owned warehouse**. Configure the sale region separately. In the Items tab, a rarity checkbox selects that group's rows; individual item boxes allow exceptions. Return to Transfer and run the selected items. Rarity is distinct from item condition. Unknown or unreadable rarity/collection metadata is held rather than guessed. Sale requires native item verification: unverified sale candidates are held and labeled, and manual sale is rejected until verified normally in the game. The mod does not verify items automatically. This avoids a native unverified quick-sale path producing a zero-price removal.

Collectibles appear below rarity groups under the collector's localized name. A star marks a currently requested, not-yet-delivered weekly item. It does not guarantee that an unverified item is deliverable. Collectibles are **held by default**, even when Common. The Rules checkbox can route them to the selected warehouse; quality routing never sells them. Explicit direct sale mode can sell manually selected collectibles. Native collector hand-in remains in the normal game UI.

Automation is **off at startup**. In quality mode it **sells checked rarities automatically** and warehouses the rest, using the collectible protection rule. In warehouse mode it delivers all eligible items. Direct sale mode cannot enable automation. Item selection boxes are ignored; all eligible items from the source are considered about every two seconds, including while the panel is closed. Changing source, mode, target or rules disables it. A full/rejected depot or failed transaction stops it. Settings are session-only.

The open panel refreshes automatically even when automation is off. Existing selections are preserved; new rows are unselected. Unchanged lists do not rebuild the UI. A failed name read falls back to item ID; an invalid individual item does not abort the remaining nearby scan. Successful transaction latches are cleared after native actor pooling resets ownership/storage state, including truck-only mode; ambiguous failures remain latched. Ownership, held-item and source checks still apply. Mixed batches warehouse first; insufficient capacity stops the batch before selling. Partial native failure is reported, without a promise to roll back already completed operations.

Time skipping stops before the day-end boundary; use the game's normal sleeping flow to start the next day.

## Configuration and removal

With the game closed, edit `Scripts/sh_assist_config.lua` inside the installed mod. Distances are in centimetres, time steps in whole minutes, and polling in milliseconds. Restart the game after editing. See the [Turkish README](../README.md) for examples.

To disable the mod, set its `mods.txt` value to `0` and, if present, its `mods.json` flag to `false`, then restart. To remove it, close the game, remove only the `StorageHunterAssist` folder and its loader entries. Keep UE4SS if other mods use it. Removing the mod does not undo previous transactions or time changes.

Check `Win64\ue4ss\UE4SS.log` for `[StorageHunterAssist] v0.3.0 loaded`. For issues, include the game build, UE4SS version, action and relevant error lines. You do not need to publish save files or an entire private log.

Original mod code: MIT. Bundled ModMenu: MIT, copyright Matthew arvidson. See [third-party notices](../THIRD_PARTY_NOTICES.md) and [verification scope](TESTING.md).
