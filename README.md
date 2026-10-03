# Guild Professions & Recipes

An addon for WoW Forever (the `_classic_beta_` client, 1.60.x) that shows the
professions and recipes of every member of your guild.

- **Roster column.** The guild window's Roster tab gets a Professions column
  with one icon per profession. Pointing at an icon shows the profession and
  skill, for example `Mining (200)`; clicking it opens that member's recipes.
  Faded icons have nothing to open: members without the addon, or recipes
  not shared yet. While the roster shows one of Blizzard's extra columns
  (achievement points...), the icons take the Note column's place.
- **Recipe window.** It lists the member's recipes by category, with search,
  reagents and the item each recipe makes. It is built from saved data, so it
  works while the member is offline. Shift-click a recipe to link it in chat.
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
   `World of Warcraft\_classic_beta_\Interface\AddOns\`.
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
| `/grecipes probe` | A test report for the addon's author (`/grecipes probe burst` also tests the send limit) |
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
| `Viewer.lua` | The recipe window |
| `Probe.lua` | `/grecipes probe` |
| `Tests\` | Offline tests (not loaded by the game) |

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
- `ui`: the roster column and the recipe window on stand-ins for
  Blizzard's frames, the slash commands and the probe.

## License

MIT, see [LICENSE](LICENSE).
