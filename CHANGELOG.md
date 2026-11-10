# Changelog

## 0.10.0 - On the guild addons' shared library

- **Now needs LibGuildSync** 0.2.0 or later, the shared code of the guild addons: hidden addon messages, the guild roster, the saved data and the sync. The CurseForge app installs it with Guild Professions & Recipes; by hand, copy its folder too.
- **Nobody has to update at once**: members on 0.9 and on 0.10 keep sharing everything, crafting orders included. The saved data does not change either.

## 0.9.1 - Sharing the guild window

- **Works alongside Guild Bank Alts**, which adds a Guild Bank tab to the guild window: the two tabs line up one under the other, and opening one closes the other. Neither addon needs the other.

## 0.9.0 - Orders that move on by themselves

- **Members on 0.8 must update.** Orders changed again. Members on 0.8 see a "newer version" notice, and their orders are not listed until they update.
- **Orders no longer expire.** They stay until their requester cancels or finishes them, and the form no longer asks for days. Orders that had already expired are cancelled when you update.
- **Waiting for materials:** once accepted, an order whose requester provides the materials waits for them. Its crafter marks them **Received**.
- **Deliveries are counted**, by trade or by mail, in as many goes as needed. The lists show how many items are delivered.
  - The materials the requester gives the crafter: with all of them, they are received.
  - The items the crafter gives the requester: with all of them, the order is completed.
  - The items the requester gets from the crafter: with all of them, the order is finished.
- **The tip is counted too**: the money the crafter gets from the requester, by trade or by mail, up to the tip. The lists show whether it is paid or how much is missing.
  - An order with a tip cannot be finished until its crafter has the tip. Once the items are all in, the order finishes by itself as soon as the tip is.
  - The crafter's **Tip paid** button marks a tip paid in a way the addon cannot see, or forgives it.
- Crafting the recipe counts for nothing: the crafter may be making it for anyone. **The buttons still work** for whatever the addon cannot see.
- **Cancel an order even once taken**, and **finish it** as soon as you have it, before its crafter marks it completed. A crafter is told when an order they accepted is cancelled.
- **Pending orders open where you craft:** a click on one of your pending orders opens its recipe in the game's own profession window, selected.
- **Who knows a recipe:** the recipe panel says how many others know it, with their names on hover. **See who knows it** lists them all, those online first, with buttons to **whisper** them or to ask them for an **order**.

## 0.8.2 - From an order to its recipe

- **Click an order** in any of the order lists, or its icon, to open its recipe in the recipe window. It shows among your guild's recipes, selected and in view, with its reagents and who knows it.
- Shift-click on an order's icon still links the recipe in chat.

## 0.8.1 - Hide my orders

- **Hide my orders**: a second filter in the Order list, ticked by default. It hides the open orders placed by any of your characters. Untick it to see them: your other characters can accept them, but not the one that placed them.
- The filters' labels can be clicked too, not only their boxes.

## 0.8.0 - Crafting orders

- **Members on 0.7 must update.** Messages between players changed to carry orders. Version 0.8 still reads what 0.7 sends, but 0.7 cannot read 0.8. Until they update, members on 0.7 see a "newer version" notice and stop getting your changes.
- **Crafting orders** between guildmates. Select a recipe in the recipe window and click **Request an order**:
  - **Open**, so anyone who knows the recipe can accept it, or **Personal**, for one member you pick among those who know it.
  - Say whether you provide the materials and add a tip in gold, silver and copper.
  - Choose the quantity and how many days the order lasts (7 by default), and add a note.
- **Three new subtabs** on the guild window's Recipes & Orders tab:
  - **Pending orders**: personal orders for you, to accept or decline, and the orders you accepted, to complete or release.
  - **Order list**: the open orders, by default only those whose recipe you know, to accept.
  - **Requested orders**: your orders. Modify or cancel them while nobody has taken them, finish them once completed, and delete them once finished, cancelled or expired.
- **How an order ends:** the crafter marks it completed, then you mark it finished. A crafter who cannot make it after all releases it, and it is open again.
- **Notices** in the chat when an order is directed to you, or when one of yours is accepted, declined, completed, released or expires. Changes made while you were offline are told when you log in. A mark on the tab shows while an order waits for you.
- Orders reach guildmates who are offline when they log in, like the rest of the data.
- Point at an order's item for its tooltip; shift-click links it in the chat.

## 0.7.1 - Side tabs that fit

- **Fixed**: in the guild's recipe window, every profession with shared recipes gets its side tab. Before, only the first 8 were shown.
- The side tabs keep the game's size while they fit, and shrink together to fit the window's height when there are more.

## 0.7.0 - The guild's recipes

- **Recipes & Orders tab** on the guild window: every profession as a button.
  - A profession that some guildmate has shared recipes of opens the recipe window on all of them together.
  - The others are disabled, and their tooltip says why.
- **The guild's recipes** in the recipe window: every recipe of a profession that any guildmate knows, each listed once and showing who knows it. Side tabs switch between the guild's professions.
- **Like the game's window**, the filters and the search are cleared when you switch to another profession.
- Crafting orders are still to come; the **Request an order** button stays disabled until then.

## 0.6.0 - A recipe window like the game's

- **Recipe window redesigned** to look like the game's own profession window. It has the same frame and art and the skill bar. The recipe panel shows the item each recipe makes, its description and its reagents with how many you carry. Side tabs switch between the member's professions.
- **Saved data is labelled**: the window says the recipes are saved data, how old they are and where they came from.
- **Your own professions** open in the game's own profession window when you click them in the roster. Guildmates' professions open their saved recipes.
- **Filter menu**:
  - **Have Materials** shows the recipes whose reagents you carry in your bags.
  - **Slots** filters by where the item is worn, with **Created Items** for everything else.
  - A button clears the filters.
- **Search** also finds recipes by the item they make and by their reagents.
- Reagent counts update as your bags change.
- **Coming soon**: crafting orders between guildmates, in a later version. For now, a **Recipes & Orders** tab on the guild window and a **Request an order** button in the recipe window are shown but disabled.
- **Fixed**: recipes are listed under the game's own profession categories. Before, they were grouped by item type unless a profession window was open.

## 0.5.0 - First release

- **Professions column** in the guild Roster: one icon per profession for each member, with the skill level on hover. Click an icon to open that member's recipes.
- **Recipe window**: browse a member's recipes by category, search them, and see the reagents, what each recipe makes and who else in the guild knows it. It works while the member is offline.
- **Automatic sharing** through hidden addon messages, plus a sync at login, so you also see guildmates you never meet online.
- **All your characters**: your alts get their recipes without opening every profession window.
- **Translated into every client language**: English, German, Spanish, French, Italian, Korean, Portuguese, Russian and Chinese.
