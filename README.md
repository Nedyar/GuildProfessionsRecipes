<p align="center"><img src=".github/logo.png" alt="Guild Professions & Recipes logo" width="160"></p>

# Guild Professions & Recipes

An addon for WoW Forever (the `_forever_` client, 1.60.x) that shows the
professions and recipes of every member of your guild.

- **Roster column.** The guild window's Roster tab gets a Professions column
  with one icon per profession. Pointing at an icon shows the profession and
  skill, for example `Mining (200)`. Clicking it opens that member's saved
  recipes; clicking one of your own professions opens it in the game's own
  profession window. Faded icons have nothing saved to open: members without
  the addon, or recipes not shared yet. While the roster shows one of
  Blizzard's extra columns (achievement points...), the icons take the Note
  column's place.
- **Recipe window.** The saved recipes, in a copy of the game's own
  profession window: recipes by category with search (by recipe, item made
  or reagent, as in the game), the item each one
  makes, its reagents (with how many you carry) and who else in the guild
  knows it. It works while the member is offline, and says that the data is
  saved and how old it is. Shift-click a recipe to link it in chat. Where
  the game has its crafting controls there is a **Request an order** button,
  not active yet: crafting orders between members come in a later version.
- **Guild window tab.** The guild window gets a **Recipes & Orders** tab
  under Blizzard's own tabs. It is disabled until a later version, which
  will add a search over the whole guild's recipes and the orders.
- **Filters.** The window's Filter menu has two of the game's own entries:
  - **Have Materials** keeps the recipes whose reagents you carry in your
    bags, the same counts the reagents show.
  - **Slots** filters by where the item is worn, with the game's
    **Created Items** entry for items that are not worn (leather, kits,
    potions...). Recipes that make no item, such as enchantments, always
    stay. Like the game's, gathering professions (Mining, Herbalism,
    Skinning, Fishing) have no Slots entry.

  The red button next to Filter clears them all.
- **Automatic sharing.** Each client reads its own character's professions
  and shares them with the guild through hidden addon messages, which never
  appear in any chat window. When you log in, a guild member who is online
  sends you whatever you are missing, so you also see members you never meet
  online.
- **Every character.** The data is shared by all the characters of your WoW
  account.
- **Every client language.** The addon's texts are in English, German, Spanish
  (EU and Latin America), French, Italian, Korean, Portuguese (Brazil, also
  used by Portugal's client), Russian and Chinese (simplified and
  traditional). Profession, recipe and item names always come from the game
  in your client's language, so clients in different languages share data
  with no problem.

## Installing

1. Copy the `GuildProfessionsRecipes` folder into
   `World of Warcraft\_forever_\Interface\AddOns\`.
2. Log in and open each of your profession windows once, so the addon can
   read the recipes. Once any character of your account has opened a
   profession's window, its full recipe list is known, and your other
   characters with that profession get their recipes at login without opening
   anything. Recipes you learn later are added on their own.

Members who do not have the addon still show their two main professions (the
game provides no reliable skill level for them), but no recipes.

## Commands

| Command | What it does |
|---|---|
| `/grecipes` | Your own recipes |
| `/grecipes <name>` | A guild member's recipes |
| `/grecipes status` | What the addon knows and is doing |
| `/grecipes sync` | Ask the guild for missing data now |
| `/grecipes probe` | A test report for the addon's author (`/grecipes probe burst` also tests the send limit; `/grecipes probe ui`, with a profession window open, reports where each piece of the game's window sits) |
| `/grecipes language <code>\|auto` | The language of the addon's own texts (enUS, deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN or zhTW); with no code, the list |
| `/grecipes debug` | Show the sync log in the chat |
| `/grecipes reset` | Forget the data of your current guild |

## How the data travels

The addon sends only IDs (skill lines and recipe spell IDs) plus skill levels;
every client turns them into names in its own language.

- **Announcements.** When your skills or recipes change, your client tells the
  guild once things have been quiet for 30 seconds.
- **Login sync.** After logging in, your client sends one short message with a
  summary of what it holds. If any online member holds something different,
  one of them (normally just one) offers to sync. The two clients then swap
  the missing records by whisper.
- **Limits.** The server limits how fast addons may send, and blocks addon
  messages during boss encounters, Mythic+ runs and PvP matches. Messages
  wait in a queue and go out when allowed.
- **Who wins.** Only a member can change their own data, and each change is
  stamped with a time. Every client keeps the newest copy of each member, so
  all clients end up with the same data. Members who leave the guild are
  dropped after 30 days.

## Files

| File | Purpose |
|---|---|
| `Locales\` | Translations, one file per language; the English text is the key |
| `Core.lua` | Shared helpers, startup, slash commands |
| `Pack.lua` | The binary format, Base64 and hashing (plain Lua) |
| `Data.lua` | The saved database and the merge rules |
| `Comm.lua` | Addon messages: chunks, reassembly, the send queue |
| `Roster.lua` | Guild membership and who is online |
| `Scanner.lua` | Reading your own professions and recipes |
| `Sync.lua` | Announcements and the login sync |
| `RosterColumn.lua` | The Professions column in the Roster tab |
| `GuildTab.lua` | The Recipes & Orders tab on the guild window |
| `Viewer.lua` | The recipe window |
| `Probe.lua` | `/grecipes probe` |
| `Tests\` | Offline tests (not loaded by the game) |
| `.github\logo.png` | The project logo (not part of the addon) |
| `CHANGELOG.md` | Release notes, shown on CurseForge for each file |
| `.pkgmeta` | How CurseForge packages a release |

## Tests

The tests run the real addon files in a simulated world: a virtual clock,
a guild roster and a fake server that delivers addon messages between many
clients, with the server's send limits. They need a Lua 5.1 interpreter:

```
lua5.1 Tests\run.lua <path to GuildProfessionsRecipes> <path to GuildProfessionsRecipes\Tests> [unit] [sync] [ui]
```

- `unit`: the binary format, Base64, checks and merge rules, loading and
  migrating saved data, the TOC, and that every language translates exactly
  the texts the code uses, with the same formats and well-formed plurals.
- `sync`: many clients logging in and out, newcomers, lost data, lockdowns,
  throttled whispers, a responder leaving mid-sync, a 40-member guild, a fresh
  install, and WoW Forever's ways: names with spaces, members on several
  realms, senders without a realm and whispers by name only.
- `ui`: the roster column, the guild window tab and the recipe window on
  stand-ins for Blizzard's frames, the slash commands and the probe.

## Releasing

CurseForge packages every tagged commit pushed to this repository.

1. Raise `## Version` in `GuildProfessionsRecipes.toc` and add that version's
   entry at the top of `CHANGELOG.md`. The tests check that both match.
2. Commit, tag the commit `v<version>` and push the tag:
   `git push origin v<version>`. A tag containing `beta` or `alpha` makes a
   beta or alpha file instead of a release.
3. CurseForge builds the zip as `.pkgmeta` says: the `GuildProfessionsRecipes`
   folder without the tests, with `CHANGELOG.md` as the file's changelog.

## License

MIT, see [LICENSE](LICENSE).
