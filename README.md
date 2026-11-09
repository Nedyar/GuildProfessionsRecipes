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
  makes, its reagents (with how many you carry) and how many others in the
  guild know it, with their names on hover. **See who knows it** lists them
  all, those online first, with buttons to whisper them or to ask them for
  an order. It works while the member is offline, and says that the data is
  saved and how old it is. Shift-click a recipe to link it in chat. Where
  the game has its crafting controls there is a **Request an order** button
  for the selected recipe (see Crafting orders).
- **Guild window tab.** The guild window gets a **Recipes & Orders** tab
  under Blizzard's own tabs, with four subtabs:
  - **Professions:** every profession as a button. Those whose recipes some
    member has shared open the recipe window on all of them together, each
    recipe saying who knows it. The others are disabled, and their tooltip
    says why.
  - **Pending orders:** orders for you, personal ones to accept or decline,
    and those you accepted, to mark their materials received, to complete
    or to release.
  - **Order list:** the open orders, to accept. By default it shows only
    those whose recipe you know, and hides those of your own characters.
  - **Requested orders:** yours, to modify while nobody has taken them, to
    cancel or finish until they are over, and to delete once finished or
    cancelled.
- **Crafting orders.** Ask a guildmate to craft a recipe for you:
  - **Open**, so anyone who knows the recipe may accept it, or **Personal**,
    for one member you pick from those who know it.
  - Say whether you provide the materials and add a tip in gold, silver and
    copper; choose the quantity; add a note. Orders do not expire: they stay
    until you cancel or finish them.
  - If you provide the materials, the accepted order waits for them until
    the crafter has them. The crafter marks it completed, then you mark it
    finished. A crafter who cannot make it after all releases it, and it is
    open again. You may cancel it any time before it is over, and finish it
    as soon as you have it.
  - **Deliveries are counted.** What changes hands between the requester
    and the crafter, by trade or by mail and in as many goes as needed,
    moves the order on by itself: the materials, once all are given, are
    received; the items, once all are given, complete the order, and
    finish it once its requester has them all. The lists show how many
    items are delivered. Crafting the recipe counts for nothing, since the
    crafter may be making it for anyone. The buttons do whatever the addon
    cannot see, such as items handed over through another character.
  - **The tip.** The money the crafter gets from the requester, by trade or
    by mail, counts towards the tip, and the lists show whether it is paid.
    An order with a tip is finished only once its crafter has the tip: if
    the items are already in, it then finishes by itself. The crafter's
    **Tip paid** button marks a tip paid where the addon could not see it,
    or forgives it.
  - Clicking an order in a list shows its recipe among the guild's in the
    recipe window, with its reagents and who knows it. In Pending orders,
    an order whose recipe you know opens in the game's own profession
    window instead, selected, ready to craft.
  - You are told in the chat when an order is directed to you, when one of
    yours is accepted, declined, released or completed or its materials are
    received, and when an order you accepted is cancelled, also of changes
    made while you were offline. Blizzard's notification mark shows on the
    tab while an order waits for you.
  - Orders travel like the rest of the data, so they reach members who are
    offline when they log in. Members need version 0.9 or later to see
    them.
- **Filters.** The window's Filter menu has two of the game's own entries:
  - **Have Materials** keeps the recipes whose reagents you carry in your
    bags, the same counts the reagents show.
  - **Slots** filters by where the item is worn, with the game's
    **Created Items** entry for items that are not worn (leather, kits,
    potions...). Recipes that make no item, such as enchantments, always
    stay. Like the game's, gathering professions (Mining, Herbalism,
    Skinning, Fishing) have no Slots entry.

  The red button next to Filter clears them all. Like the game's, the
  filters and the search start clear each time another profession is shown.
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
  guild once things have been quiet for 30 seconds; a change to your crafting
  orders goes out within seconds.
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
- **Crafting orders.** An order is kept in its requester's data, and each
  crafter's answer (accepted, declined, materials received, completed, how
  many items they delivered and how much of the tip they received) in that
  crafter's, so the same rule holds.
  Every client works out an order's state from both: when two crafters
  accept an open order at once, the earlier acceptance wins everywhere.
  Finished and cancelled orders are dropped three days later, or at once
  when their requester deletes them. Deliveries are counted by the client
  whose data they change: the crafter's counts the materials received, the
  items given and the tip received, the requester's the items received.
- **Versions.** Version 0.8 changed the messages to carry orders, and 0.9
  changed them again for orders without expiry and the deliveries. 0.9
  still reads what members on 0.7 and 0.8 announce, but they cannot read
  0.9, so they are asked to update. Until they do, their orders are not
  listed.

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
| `GuildTab.lua` | The Recipes & Orders tab and its panel on the guild window |
| `Viewer.lua` | The recipe window |
| `Orders.lua` | Crafting orders: their states, our changes, the clean-up |
| `OrderForm.lua` | The window to request or change an order |
| `OrderList.lua` | The order lists of the guild window tab, and the notices |
| `Deliveries.lua` | Trades and mail with guildmates, counted towards their orders |
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
lua5.1 Tests\run.lua <path to GuildProfessionsRecipes> <path to GuildProfessionsRecipes\Tests> [unit] [sync] [orders] [ui]
```

- `unit`: the binary format, Base64, checks and merge rules, loading and
  migrating saved data, the TOC, and that every language translates exactly
  the texts the code uses, with the same formats and well-formed plurals.
- `sync`: many clients logging in and out, newcomers, lost data, lockdowns,
  throttled whispers, a responder leaving mid-sync, a 40-member guild, a fresh
  install, and WoW Forever's ways: names with spaces, members on several
  realms, senders without a realm and whispers by name only.
- `orders`: the record format with orders, their states, open and personal
  orders between several clients (online, offline, at the same time), the
  clean-up, the request form, the order lists and the notices, deliveries
  and tips by trade and mail (in several goes, cancelled, refused, with
  full bags), and members still on 0.7 or 0.8.
- `ui`: the roster column, the guild window tab and the recipe window on
  stand-ins for Blizzard's frames, the slash commands and the probe.

## Releasing

CurseForge packages every tagged commit pushed to this repository.

1. Raise `## Version` in `GuildProfessionsRecipes.toc` and add that version's
   entry at the top of `CHANGELOG.md`. The tests check that both match.
   While a version with a new protocol is tried in game, `ns.TRIAL` in
   `Core.lua` keeps it on an addon-message prefix of its own, so members on
   the released version are not asked to update yet. Set it to `false` for
   the release; the tests print a note while it is on.
2. Commit, tag the commit `v<version>` and push the tag:
   `git push origin v<version>`. A tag containing `beta` or `alpha` makes a
   beta or alpha file instead of a release.
3. CurseForge builds the zip as `.pkgmeta` says: the `GuildProfessionsRecipes`
   folder without the tests, with `CHANGELOG.md` as the file's changelog.

## License

MIT, see [LICENSE](LICENSE).
